-- Single source of truth for stat IDs, display names, categories, and format types.
-- Loaded on both client and server before any other PlayerRanks file.

PlayerRanks       = PlayerRanks or {}
PlayerRanks.Defs  = {}
local SD          = PlayerRanks.Defs

SD.Categories = {
    "Survival",
    "Exploration",
    "Combat",
    "Industry",
    "Deaths",
    "Vehicles",
    "Social",
}

-- polled=true  → tracked by client timer (Phase 2)
-- polled=false → tracked by event hook
-- format: "int" | "time" | "distance" | "tile"
SD.Stats = {
    -- Survival
    { id="dayssurvived",      display="Days Survived",          category="Survival",    format="int",      polled=true  },
    { id="caloriesconsumed",  display="Calories Consumed",      category="Survival",    format="int",      polled=false },
    { id="timeonline",        display="Time Online",            category="Survival",    format="time",     polled=true  },
    { id="hoursslept",        display="Hours Slept",            category="Survival",    format="int",      polled=false },
    { id="timesstarving",     display="Times Starving",         category="Survival",    format="int",      polled=false },
    { id="medicationstaken",  display="Medications Taken",      category="Survival",    format="int",      polled=false },
    { id="cigarettessmoked",  display="Cigarettes Smoked",      category="Survival",    format="int",      polled=false },
    { id="alcoholconsumed",   display="Alcohol Consumed",       category="Survival",    format="int",      polled=false },
    { id="timesrainedon",     display="Times Rained On",        category="Survival",    format="int",      polled=true  },

    -- Exploration
    { id="tilesvisited",      display="Unique Tiles Visited",   category="Exploration", format="tile",     polled=true  },
    { id="distancetraveled",  display="Distance Traveled",      category="Exploration", format="distance", polled=true  },
    { id="distancedriven",    display="Distance Driven",        category="Exploration", format="distance", polled=true  },
    { id="farthestfromspawn", display="Farthest From Spawn",    category="Exploration", format="distance", polled=true  },
    { id="timeindoors",       display="Time Indoors",           category="Exploration", format="time",     polled=true  },
    { id="timeoutdoors",      display="Time Outdoors",          category="Exploration", format="time",     polled=true  },

    -- Combat
    { id="zombieskilled",     display="Zombies Killed",         category="Combat",      format="int",      polled=false },
    { id="headshots",         display="Headshots",              category="Combat",      format="int",      polled=false },
    { id="timesbitten",       display="Times Bitten",           category="Combat",      format="int",      polled=false },
    { id="timesscratched",    display="Times Scratched",        category="Combat",      format="int",      polled=false },
    { id="timesknocked",      display="Times Knocked Down",     category="Combat",      format="int",      polled=false },
    { id="timespanicked",     display="Times Panicked",         category="Combat",      format="int",      polled=false },

    -- Industry
    { id="itemscrafted",      display="Items Crafted",          category="Industry",    format="int",      polled=false },
    { id="itemsrepaired",     display="Items Repaired",         category="Industry",    format="int",      polled=false },
    { id="booksread",         display="Books Read",             category="Industry",    format="int",      polled=false },
    { id="skillbooksread",    display="Skill Books Read",       category="Industry",    format="int",      polled=false },
    { id="structuresbuilt",   display="Structures Built",       category="Industry",    format="int",      polled=false },
    { id="cropsplanted",      display="Crops Planted",          category="Industry",    format="int",      polled=false },
    { id="cropsharvested",    display="Crops Harvested",        category="Industry",    format="int",      polled=false },

    -- Deaths & Suffering
    { id="totaldeaths",       display="Total Deaths",           category="Deaths",      format="int",      polled=false },
    { id="longeststreak",     display="Longest Streak (days)",  category="Deaths",      format="int",      polled=false },
    { id="timespassedout",    display="Times Passed Out",       category="Deaths",      format="int",      polled=false },

    -- Vehicles
    { id="vehiclesrepaired",  display="Vehicles Repaired",      category="Vehicles",    format="int",      polled=false },
    { id="vehicleshotwired",  display="Vehicles Hotwired",      category="Vehicles",    format="int",      polled=false },
    { id="fuelconsumed",      display="Fuel Consumed",          category="Vehicles",    format="int",      polled=true  },

    -- Social / Chaos
    { id="itemsgiven",        display="Items Given",            category="Social",      format="int",      polled=false },
    { id="doorskicked",       display="Doors Kicked",           category="Social",      format="int",      polled=false },
    { id="windowssmashed",    display="Windows Smashed",        category="Social",      format="int",      polled=false },
    { id="vomitcount",        display="Times Vomited",          category="Social",      format="int",      polled=false },
    { id="chatmessages",      display="Chat Messages Sent",     category="Social",      format="int",      polled=false },
}

-- Fast lookup by id
SD.ByID = {}
for _, stat in ipairs(SD.Stats) do
    SD.ByID[stat.id] = stat
end

-- Returns a zeroed stats table with every stat key present
function SD.newRecord()
    local r = {}
    for _, stat in ipairs(SD.Stats) do
        r[stat.id] = 0
    end
    return r
end

-- Phase 4 will do proper time/distance/comma formatting; returns plain int string for now
function SD.formatValue(statId, value)
    local n = tonumber(value) or 0
    return tostring(math.floor(n))
end
