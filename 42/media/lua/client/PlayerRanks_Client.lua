-- Client-side: event hooks, delta batching, /ranks chat command, server message display.
-- Phase 1: event-based stats only. Polled stats (distance, tiles, etc.) added in Phase 2.

local MOD              = "PlayerRanks"
local FLUSH_INTERVAL   = 30000  -- ms between automatic delta flushes

local _deltas          = {}     -- accumulated unsent stat increments
local _lastFlush       = 0

-- ── Delta helpers ─────────────────────────────────────────────────────────────

local function inc(statId, amount)
    _deltas[statId] = (_deltas[statId] or 0) + (amount or 1)
end

local function flushDeltas()
    local hasAny = false
    for _ in pairs(_deltas) do hasAny = true; break end
    if not hasAny then return end

    local player = getSpecificPlayer(0)
    if not player then return end

    sendClientCommand(player, MOD, "StatDelta", { deltas = _deltas })
    _deltas = {}
end

-- ── Zombie kills ──────────────────────────────────────────────────────────────
-- TODO(hook-audit): confirm zombie:getAttacker() is the correct B42 method name.
-- Alternative names seen in community code: getLastAttacker(), getKiller().

Events.OnZombieDead.Add(function(zombie)
    local player = getSpecificPlayer(0)
    if not player then return end

    local ok, attacker = pcall(function() return zombie:getAttacker() end)
    if not ok or not attacker then return end

    if attacker == player then
        inc("zombieskilled")
    end
end)

-- ── Bites & scratches ─────────────────────────────────────────────────────────
-- TODO(hook-audit): OnPlayerHit signature and bodypart type constants need
-- verification in B42. Placeholder below — enable once confirmed.
--
-- Events.OnPlayerHit.Add(function(player, attacker, bodyPart)
--     if player ~= getSpecificPlayer(0) then return end
--     local ok, bpName = pcall(function() return bodyPart:name() end)
--     if ok and bpName then
--         if string.find(bpName, "Bite")    then inc("timesbitten")    end
--         if string.find(bpName, "Scratch") then inc("timesscratched") end
--     end
-- end)

-- ── Knockdowns ────────────────────────────────────────────────────────────────
-- TODO(hook-audit): Verify OnPlayerFall exists in B42.
--
-- Events.OnPlayerFall.Add(function(player)
--     if player ~= getSpecificPlayer(0) then return end
--     inc("timesknocked")
-- end)

-- ── Panic ─────────────────────────────────────────────────────────────────────
-- TODO(hook-audit): Moodle application hook name needs verification.
-- Candidate: Events.OnMoodleChange or checking moodle level delta in OnTick.

-- ── Crafting ─────────────────────────────────────────────────────────────────
-- TODO(hook-audit): Verify OnPlayerCraft / OnCraftingComplete exists in B42.
--
-- Events.OnPlayerCraft.Add(function(player, result)
--     if player ~= getSpecificPlayer(0) then return end
--     inc("itemscrafted")
-- end)

-- ── Repairs ──────────────────────────────────────────────────────────────────
-- TODO(hook-audit): Item repair hook name needs verification.

-- ── Building ─────────────────────────────────────────────────────────────────
-- TODO(hook-audit): Verify OnPlayerBuild exists in B42.
--
-- Events.OnPlayerBuild.Add(function(player, object)
--     if player ~= getSpecificPlayer(0) then return end
--     inc("structuresbuilt")
-- end)

-- ── Books / skill books ───────────────────────────────────────────────────────
-- TODO(hook-audit): OnItemUse or equivalent, filter by IsReadable / skill book type.

-- ── Farming ──────────────────────────────────────────────────────────────────
-- TODO(hook-audit): Farming action hooks need verification.

-- ── Eating / calories / medications / cigarettes / alcohol ───────────────────
-- TODO(hook-audit): OnPlayerEatFood or equivalent; filter by item category.

-- ── Doors kicked / windows smashed ───────────────────────────────────────────
-- TODO(hook-audit): Force-open and break-window hooks need verification.

-- ── Vomit ─────────────────────────────────────────────────────────────────────
-- TODO(hook-audit): Vomit/sick action hook needs verification.

-- ── Items given ──────────────────────────────────────────────────────────────
-- TODO(hook-audit): Detect player→player inventory transfer in B42.

-- ── Vehicle hotwire / repair ──────────────────────────────────────────────────
-- TODO(hook-audit): Mechanic and hotwire action hooks need verification.

-- ── Passed out ───────────────────────────────────────────────────────────────
-- TODO(hook-audit): Unconscious moodle or OnPlayerFallUnconscious needs verification.

-- ── Chat messages + /ranks command ───────────────────────────────────────────
-- Counts outgoing chat messages and intercepts /ranks slash commands.
-- The /ranks text will appear in the chat box until Phase 4 suppression is added.
--
-- TODO(hook-audit): Confirm OnChatMessage signature in B42.
-- Known variants: (chat, message, tabID) with ChatMessage object, or (author, text).

Events.OnChatMessage.Add(function(chat, message)
    if not message then return end

    local player = getSpecificPlayer(0)
    if not player then return end

    -- Only process messages the local player sent
    local ok1, author = pcall(function() return message:getAuthor() end)
    if not ok1 or not author then return end

    local ok2, username = pcall(function() return player:getUsername() end)
    if not ok2 or not username then return end

    if author ~= username then return end

    local ok3, text = pcall(function() return message:getText() end)
    if not ok3 or not text then return end

    -- Intercept /ranks command before counting as a chat message
    local trimmed = text:match("^%s*(.-)%s*$")
    local lower   = string.lower(trimmed)
    if lower:sub(1, 6) == "/ranks" then
        sendClientCommand(player, MOD, "ChatCommand", { text = lower })
        return
    end

    inc("chatmessages")
end)

-- ── Flush timer ───────────────────────────────────────────────────────────────

Events.OnTick.Add(function()
    local now = getTimeInMillis()
    if now - _lastFlush >= FLUSH_INTERVAL then
        flushDeltas()
        _lastFlush = now
    end
end)

Events.OnGameStart.Add(function()
    _lastFlush = getTimeInMillis()
end)

-- Flush on clean disconnect
Events.OnGameEnd.Add(function()
    flushDeltas()
end)

-- ── Receive server messages ───────────────────────────────────────────────────

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= MOD then return end

    if command == "ServerMessage" then
        local text = args.text or ""
        -- Write to chat panel; falls back to console if ISChat is unavailable
        local ok = pcall(function()
            local chat = ISChat.instance
            if chat and chat.chatText then
                -- RGBA: pale yellow for mod messages
                chat.chatText:addLineInWindow(text, 0.9, 0.85, 0.4, 1.0)
            end
        end)
        if not ok then
            print("[PlayerRanks] " .. text)
        end
    end

    -- LeaderboardResult, MyStatsResult, HoFResult handled by Phase 3 UI
end)
