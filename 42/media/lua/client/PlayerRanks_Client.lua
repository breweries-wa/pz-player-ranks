-- Client-side: event hooks, delta batching, /ranks chat command, server message display.
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
-- Chat messages + /ranks command
-- TODO(hook-audit): Events.OnChatMessage does not exist in B42 (confirmed null).
-- The B42 chat system uses a different API. Needs investigation before Phase 4.
-- chatmessages stat and /ranks slash command interception are deferred until then.
-- ---------------------------------------------------------------------------

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
        local text = args.text or ""
        -- Write to chat panel; falls back to console if ISChat is unavailable
        local ok = pcall(function()
            local chat = ISChat.instance
            if chat and chat.chatText then
                -- pale yellow for mod messages
                chat.chatText:addLineInWindow(text, 0.9, 0.85, 0.4, 1.0)
            end
        end)
        if not ok then
            print("[PlayerRanks] " .. text)
        end
    end

    -- LeaderboardResult, MyStatsResult, HoFResult handled by Phase 3 UI
end)
