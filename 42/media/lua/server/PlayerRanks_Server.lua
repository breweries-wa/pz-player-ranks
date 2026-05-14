-- Server-side: data storage, leaderboard queries, death handling, admin commands.

local MOD      = "PlayerRanks"
local DATA_KEY = "PlayerRanks_data"

-- ---------------------------------------------------------------------------
-- Data layer
-- Keep a live Lua reference so we only hit ModData.get on cold load.
-- ---------------------------------------------------------------------------

local _data = nil

local function loadData()
    if not _data then
        _data = ModData.get(DATA_KEY)
        if not _data then
            _data = {}
            ModData.add(DATA_KEY, _data)
        end
    end
    return _data
end

local function saveData()
    ModData.add(DATA_KEY, _data)
    ModData.transmit(DATA_KEY)
end

local function ensurePlayer(player)
    local data = loadData()
    local sid  = player:getSteamID()
    if not data[sid] then
        data[sid] = {
            steamid     = sid,
            displayName = player:getUsername(),
            lifetime    = PlayerRanks.Defs.newRecord(),
            char        = PlayerRanks.Defs.newRecord(),
        }
    else
        data[sid].displayName = player:getUsername()
    end
    return data[sid]
end

-- ---------------------------------------------------------------------------
-- Leaderboard helpers
-- ---------------------------------------------------------------------------

local function buildRankedRows(statId, setKey)
    local data = loadData()
    local rows = {}
    for sid, record in pairs(data) do
        if sid ~= "__hof__" then
            local set = record[setKey]
            rows[#rows+1] = {
                sid   = sid,
                name  = record.displayName or "?",
                value = (set and set[statId]) or 0,
            }
        end
    end
    table.sort(rows, function(a, b) return a.value > b.value end)
    return rows
end

local function topN(statId, setKey, n)
    local rows = buildRankedRows(statId, setKey)
    local out  = {}
    for i = 1, math.min(n, #rows) do
        out[i] = { name = rows[i].name, value = rows[i].value }
    end
    return out
end

local function playerRank(steamid, statId, setKey)
    local rows = buildRankedRows(statId, setKey)
    for i, row in ipairs(rows) do
        if row.sid == steamid then return i, row.value end
    end
    return nil, 0
end

-- ---------------------------------------------------------------------------
-- Client command handler
-- ---------------------------------------------------------------------------

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= MOD then return end

    -- StatDelta: client flushing accumulated event deltas
    if command == "StatDelta" then
        local deltas = args.deltas
        if type(deltas) ~= "table" then return end

        local record = ensurePlayer(player)
        for statId, delta in pairs(deltas) do
            if PlayerRanks.Defs.ByID[statId]
                and type(delta) == "number"
                and delta > 0
            then
                record.lifetime[statId] = (record.lifetime[statId] or 0) + delta
                record.char[statId]     = (record.char[statId]     or 0) + delta
                -- DEBUG: remove before release
                print(string.format("[PlayerRanks] %s +%d %s (lifetime: %d)",
                    player:getUsername(), delta, statId, record.lifetime[statId]))
            end
        end
        saveData()

    -- RequestLeaderboard: UI tab opening, stat picker change
    elseif command == "RequestLeaderboard" then
        local statId = args.statId or "zombieskilled"
        local setKey = (args.setKey == "char") and "char" or "lifetime"

        if not PlayerRanks.Defs.ByID[statId] then
            statId = "zombieskilled"
        end

        local sid           = player:getSteamID()
        local top           = topN(statId, setKey, 10)
        local myRank, myVal = playerRank(sid, statId, setKey)

        -- Context rows: one above, player, one below (Phase 3 UI uses these)
        local allRows = buildRankedRows(statId, setKey)
        local ctxAbove, ctxBelow
        for i, row in ipairs(allRows) do
            if row.sid == sid then
                if i > 1 then
                    ctxAbove = { rank = i-1, name = allRows[i-1].name, value = allRows[i-1].value }
                end
                if allRows[i+1] then
                    ctxBelow = { rank = i+1, name = allRows[i+1].name, value = allRows[i+1].value }
                end
                break
            end
        end

        sendServerCommand(player, MOD, "LeaderboardResult", {
            statId   = statId,
            setKey   = setKey,
            top      = top,
            myRank   = myRank,
            myVal    = myVal,
            ctxAbove = ctxAbove,
            ctxBelow = ctxBelow,
        })

    -- RequestMyStats: My Stats tab
    elseif command == "RequestMyStats" then
        local data   = loadData()
        local sid    = player:getSteamID()
        local record = data[sid]
        sendServerCommand(player, MOD, "MyStatsResult", {
            lifetime = record and record.lifetime or {},
            char     = record and record.char     or {},
        })

    -- RequestHoF: Hall of Fame tab
    elseif command == "RequestHoF" then
        local data = loadData()
        local hof  = data["__hof__"] or {}
        sendServerCommand(player, MOD, "HoFResult", { hof = hof })

    -- ChatCommand: /ranks [subcommand]
    elseif command == "ChatCommand" then
        local text  = string.lower(args.text or "")
        local parts = {}
        for word in text:gmatch("%S+") do parts[#parts+1] = word end

        if parts[1] ~= "/ranks" then return end

        local sub = parts[2] or "show"

        if sub == "show" or sub == "top" then
            local statId = parts[3] or "zombieskilled"
            if not PlayerRanks.Defs.ByID[statId] then statId = "zombieskilled" end
            local stat = PlayerRanks.Defs.ByID[statId]
            local top5 = topN(statId, "lifetime", 5)

            local lines = { "[PlayerRanks] Top 5 - " .. stat.display .. " (Lifetime):" }
            if #top5 == 0 then
                lines[#lines+1] = "  No data yet."
            else
                for i, row in ipairs(top5) do
                    lines[#lines+1] = string.format(
                        "  #%d  %s - %s",
                        i, row.name, PlayerRanks.Defs.formatValue(statId, row.value)
                    )
                end
            end
            for _, line in ipairs(lines) do
                sendServerCommand(player, MOD, "ServerMessage", { text = line })
            end

        elseif sub == "wipe" then
            local lvl = player:getAccessLevel()
            if lvl ~= "Admin" and lvl ~= "Moderator" then
                sendServerCommand(player, MOD, "ServerMessage",
                    { text = "[PlayerRanks] Admin access required." })
                return
            end
            -- Snapshot before wiping
            local hof = {}
            for _, stat in ipairs(PlayerRanks.Defs.Stats) do
                local top3 = topN(stat.id, "lifetime", 3)
                if #top3 > 0 then hof[stat.id] = top3 end
            end
            _data = { ["__hof__"] = hof }
            saveData()
            sendServerCommand(player, MOD, "ServerMessage",
                { text = "[PlayerRanks] All data wiped. Hall of Fame snapshot saved." })

        elseif sub == "snapshot" then
            local lvl = player:getAccessLevel()
            if lvl ~= "Admin" and lvl ~= "Moderator" then
                sendServerCommand(player, MOD, "ServerMessage",
                    { text = "[PlayerRanks] Admin access required." })
                return
            end
            local data = loadData()
            local hof  = {}
            for _, stat in ipairs(PlayerRanks.Defs.Stats) do
                local top3 = topN(stat.id, "lifetime", 3)
                if #top3 > 0 then hof[stat.id] = top3 end
            end
            data["__hof__"] = hof
            saveData()
            sendServerCommand(player, MOD, "ServerMessage",
                { text = "[PlayerRanks] Hall of Fame snapshot saved." })

        elseif sub == "reset" then
            local lvl = player:getAccessLevel()
            if lvl ~= "Admin" and lvl ~= "Moderator" then
                sendServerCommand(player, MOD, "ServerMessage",
                    { text = "[PlayerRanks] Admin access required." })
                return
            end
            local targetName = parts[3]
            if not targetName then
                sendServerCommand(player, MOD, "ServerMessage",
                    { text = "[PlayerRanks] Usage: /ranks reset <playername>" })
                return
            end
            local data  = loadData()
            local found = false
            for sid, record in pairs(data) do
                if sid ~= "__hof__"
                    and string.lower(record.displayName or "") == string.lower(targetName)
                then
                    data[sid].lifetime = PlayerRanks.Defs.newRecord()
                    data[sid].char     = PlayerRanks.Defs.newRecord()
                    found = true
                    break
                end
            end
            saveData()
            local msg = found
                and ("[PlayerRanks] Reset all stats for " .. targetName .. ".")
                or  ("[PlayerRanks] Player not found: " .. targetName)
            sendServerCommand(player, MOD, "ServerMessage", { text = msg })

        elseif sub == "resetchar" then
            local lvl = player:getAccessLevel()
            if lvl ~= "Admin" and lvl ~= "Moderator" then
                sendServerCommand(player, MOD, "ServerMessage",
                    { text = "[PlayerRanks] Admin access required." })
                return
            end
            local targetName = parts[3]
            if not targetName then
                sendServerCommand(player, MOD, "ServerMessage",
                    { text = "[PlayerRanks] Usage: /ranks resetchar <playername>" })
                return
            end
            local data  = loadData()
            local found = false
            for sid, record in pairs(data) do
                if sid ~= "__hof__"
                    and string.lower(record.displayName or "") == string.lower(targetName)
                then
                    data[sid].char = PlayerRanks.Defs.newRecord()
                    found = true
                    break
                end
            end
            saveData()
            local msg = found
                and ("[PlayerRanks] Reset character stats for " .. targetName .. ".")
                or  ("[PlayerRanks] Player not found: " .. targetName)
            sendServerCommand(player, MOD, "ServerMessage", { text = msg })
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Death handler
-- ---------------------------------------------------------------------------

Events.OnPlayerDeath.Add(function(player)
    local record = ensurePlayer(player)

    -- Lock in longest survival streak before zeroing character stats
    local days = record.char["dayssurvived"] or 0
    if days > (record.lifetime["longeststreak"] or 0) then
        record.lifetime["longeststreak"] = days
    end

    record.lifetime["totaldeaths"] = (record.lifetime["totaldeaths"] or 0) + 1
    record.char = PlayerRanks.Defs.newRecord()

    saveData()
end)
