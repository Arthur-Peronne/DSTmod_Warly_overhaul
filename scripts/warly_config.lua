-- warly_config.lua
-- Central configuration constants for the Warly Overhaul mod

WARLY_CONFIG = {

    -- FIFO memory queue size thresholds (in days / world cycles)
    MEMORY_DAY_THRESHOLDS = { 35, 70 },
    MEMORY_SIZES          = { 2, 3, 4 },

    -- Hunger efficiency multipliers per occurrence (configurable)
    -- Index = number of occurrences in the queue (1 to 4)
    MULTIPLIERS = { 0.75, 0.50, 0.25, 0.00 },

    -- Buff duration multiplier for Warly's exclusive dishes (configurable)
    BUFF_DURATION_BONUS = 1.5,

    -- List of Warly's exclusive dishes (for the +15 hunger bonus)
    EXCLUSIVE_DISHES = {
        -- Feeding dishes
        "moqueca",            -- modified
        "saltedcaramelcrepes",-- new
        "bonesoup",           -- modified: bone bouillon
        "scaryparmentier",    -- new
        "monstertartare",     -- modified
        -- Status dishes (elements)
        "spicyburger",        -- new
        "gazpacho",           -- modified: asparagazpacho
        "frogfishbowl",       -- modified: fish cordon bleu
        "glowberrymousse",    -- modified
        -- Status dishes (stats)
        "nightmarepie",       -- modified: grim galette 
        -- Bonus dishes (utility)
        "sweetsmoothie",      -- new
        "saltedcodsoup",      -- new
        -- Bonus dishes (combat)
        "spikysalad",         -- new
        "roastedvegetables",  -- new
        "voltgoatchaudfroid", -- modified
    },
}
