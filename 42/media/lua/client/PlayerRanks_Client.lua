-- Client-side: event hooks, delta batching, /rank chat command, server message display.
-- Phase 1: event-based stats only. Polled stats (distance, tiles, etc.) added in Phase 2.

local MOD            = "PlayerRanks"
local FLUSH_INTERVAL = 30000  -- ms between automatic delta flushes

local _deltas    = {}  -- accumulated unsent stat increments
local _lastFlush = 0

-- ---------------------------------------------------------------------------
-- Delta helpers
-- ---------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------
-- Chat output helper
-- Confirmed B42 API: ISChat.addLineInChat(message, tabIndex)
-- tabIndex 0 = General tab
-- ---------------------------------------------------------------------------

local function addChatLine(text)
    local ok = pcall(function()
        ISChat.addLineInChat(text, 0)
    end)
    if not ok then
        print("[PlayerRanks] " .. text)
    end
end

-- ---------------------------------------------------------------------------
-- /rank chat command hook
-- B42 pattern (confirmed from BurdSurvivalJournals mod):
--   Override ISChat.onCommandEntered, read text from textEntry, suppress
--   the message and handle it ourselves. Defer install until ISChat is ready.
-- ---------------------------------------------------------------------------

local function hookISChat()
    if not ISChat then return false end

    local original = ISChat.onCommandEntered

    ISChat.onCommandEntered = function(self)
        local text = ISChat.instance
            and ISChat.instance.textEntry
            and ISChat.instance.textEntry:getText()

        if text and string.lower(text):match("^/rank%s*$") then
            -- Suppress the message
            if ISChat.instance and ISChat.instance.textEntry then
                ISChat.instance.textEntry:setText("")
            end
            if ISChat.instance then ISChat.instance:unfocus() end

            -- Request top stats from server
            local player = getSpecificPlayer(0)
            if player then
                sendClientCommand(player, MOD, "ChatCommand", { text = "/rank" })
            end
            return
        end

        if original then return original(self) end
    end

    return true
end

-- Install immediately if ISChat is already loaded, otherwise retry on ticks
-- after game start (mirrors BurdSurvivalJournals pattern).
if ISChat then
    hookISChat()
else
    Events.OnGameStart.Add(function()
        local ticks = 0
        local function tryHook()
            ticks = ticks + 1
            if hookISChat() or ticks > 100 then
                Events.OnTick.Remove(tryHook)
            end
        end
        Events.OnTick.Add(tryHook)
    end)
end

-- ---------------------------------------------------------------------------
-- Zombie kills
-- B42 pattern (confirmed from CombatText mod):
--   OnWeaponHitCharacter tags zombies hit by the local player.
--   OnZombieDead checks the tag and counts the kill.
-- Using tostring(zombie) as a unique key per Java object instance.
-- ---------------------------------------------------------------------------

local _hitByPlayer = {}  -- keys: tostring(zombie), value: true

Events.OnWeaponHitCharacter.Add(function(attacker, target, weapon, damage)
    local player = getSpecificPlayer(0)
    if not player or attacker ~= player then return end
    local ok, objName = pcall(function() return target:getObjectName() end)
    if ok and objName == "Zombie" then
        _hitByPlayer[tostring(target)] = true
    end
end)

Events.OnZombieDead.Add(function(zombie)
    local key = tostring(zombie)
    if _hitByPlayer[key] then
        _hitByPlayer[key] = nil
        inc("zombieskilled")
    end
end)

-- ---------------------------------------------------------------------------
-- Bites & scratches
-- TODO(hook-audit): OnPlayerHit signature and bodypart type constants need
-- verification in B42. Enable once confirmed.
--
-- Events.OnPlayerHit.Add(function(player, attacker, bodyPart)
--     if player ~= getSpecificPlayer(0) then return end
--     local ok, bpName = pcall(function() return bodyPart:name() end)
--     if ok and bpName then
--         if string.find(bpName, "Bite")    then inc("timesbitten")    end
--         if string.find(bpName, "Scratch") then inc("timesscratched") end
--     end
-- end)
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Knockdowns
-- TODO(hook-audit): Verify OnPlayerFall exists in B42.
--
-- Events.OnPlayerFall.Add(function(player)
--     if player ~= getSpecificPlayer(0) then return end
--     inc("timesknocked")
-- end)
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Crafting
-- TODO(hook-audit): Verify OnPlayerCraft / OnCraftingComplete exists in B42.
--
-- Events.OnPlayerCraft.Add(function(player, result)
--     if player ~= getSpecificPlayer(0) then return end
--     inc("itemscrafted")
-- end)
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Building
-- TODO(hook-audit): Verify OnPlayerBuild exists in B42.
--
-- Events.OnPlayerBuild.Add(function(player, object)
--     if player ~= getSpecificPlayer(0) then return end
--     inc("structuresbuilt")
-- end)
-- ---------------------------------------------------------------------------

-- TODO(hook-audit): Panic moodle hook needs verification.
-- TODO(hook-audit): Item repair hook needs verification.
-- TODO(hook-audit): OnItemUse or equivalent for books/meds/food - needs verification.
-- TODO(hook-audit): Farming action hooks need verification.
-- TODO(hook-audit): Force-open and break-window hooks need verification.
-- TODO(hook-audit): Vomit/sick action hook needs verification.
-- TODO(hook-audit): Player->player inventory transfer detection needs verification.
-- TODO(hook-audit): Mechanic and hotwire action hooks need verification.
-- TODO(hook-audit): Unconscious moodle or OnPlayerFallUnconscious needs verification.

-- ---------------------------------------------------------------------------
-- Flush timer
-- ---------------------------------------------------------------------------

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
Events.OnDisconnect.Add(function()
    flushDeltas()
end)

-- ---------------------------------------------------------------------------
-- Receive server messages
-- ---------------------------------------------------------------------------

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= MOD then return end

    if command == "ServerMessage" then
        addChatLine(args.text or "")
    end

    -- LeaderboardResult, MyStatsResult, HoFResult handled by Phase 3 UI
end)
