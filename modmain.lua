print("[Warly Overhaul] modmain.lua loaded")

GLOBAL.WARLY_MEMORY_SIZE_OPTION = GetModConfigData("memory_size")
GLOBAL.WARLY_CURRENT_CHEF = nil

local _require = GLOBAL.require

AddPrefabPostInit("warly", function(inst)
    -- === PHASE 1 ===
    inst.starting_inventory = {}
    inst:RemoveTag("expertchef")
    inst:RemoveTag("professionalchef")

    if inst.components.hunger then
        inst.components.hunger:SetMax(200)
        inst.components.hunger:SetRate(TUNING.WILSON_HUNGER_RATE)
    end

    if inst.components.sanity then
        inst.components.sanity:SetMax(150)
    end

    -- === PHASE 2 : FIFO food memory===
    if inst.components.eater then

        -- Delete vanilla foodmemory vanilla
        if inst.components.foodmemory then
            inst:RemoveComponent("foodmemory")
        end

        -- Attach new food memory FIFO
        inst:AddComponent("warly_foodmemory")

        -- Network variable (server only — guarded by eater component)
        inst._warly_mem_str = GLOBAL.net_string(inst.GUID, "warly_mem_queue", "warlymemqueueupdate")

        -- Send the initial queue state (needed for loaded saves where OnLoad populated the queue)
        inst:DoStaticTaskInTime(0, function()
            if inst.components.warly_foodmemory then
                inst._warly_mem_str:set(table.concat(inst.components.warly_foodmemory.queue, ","))
            end
        end)


        -- Dish multiplier
        inst.components.eater.custom_stats_mod_fn = function(i, hp, hunger, sanity, food, feeder)
            local mult = i.components.warly_foodmemory:GetMultiplier(food.prefab)
            return hp * mult, hunger * mult, sanity * mult
        end

        -- Refuse to eat if the food multiplier is 0 (4 occurrences in queue)
        local original_prefers = inst.components.eater.PrefersToEat
        inst.components.eater.PrefersToEat = function(self, food)
            if food ~= nil
                and not food:HasTag("potion")
                and inst.components.warly_foodmemory ~= nil
                and inst.components.warly_foodmemory:GetMultiplier(food.prefab) == 0
            then
                return false
            end
            return original_prefers(self, food)
        end

        -- Say SAME_OLD_5 only when the refusal is due to memory saturation
        inst:ListenForEvent("wonteatfood", function(i, data)
            if data.food ~= nil
                and inst.components.warly_foodmemory ~= nil
                and inst.components.warly_foodmemory:GetMultiplier(data.food.prefab) == 0
                and i.components.talker ~= nil
            then
                i.components.talker:Say(GLOBAL.GetString(i, "ANNOUNCE_EAT", "SAME_OLD_5"))
            end
        end)

        -- Save dish after every meal
        inst:ListenForEvent("oneat", function(i, data)
            if data.food ~= nil and not data.food:HasTag("potion") then
                local occ = i.components.warly_foodmemory:GetOccurrences(data.food.prefab)
                i.components.warly_foodmemory:RememberFood(data.food.prefab)
                inst._warly_mem_str:set(table.concat(i.components.warly_foodmemory.queue, ","))

                if occ > 0 and i.components.talker ~= nil then
                    local speech_keys = { "SAME_OLD_1", "SAME_OLD_2", "SAME_OLD_4", "SAME_OLD_5" }
                    i.components.talker:Say(GLOBAL.GetString(i, "ANNOUNCE_EAT", speech_keys[occ]))
                end
            end
        end)
    end
end)


AddPrefabPostInit("portablespicer_item", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.deployable ~= nil then
        inst.components.deployable.restrictedtag = "nobody"
    end
end)

AddPrefabPostInit("portableblender", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.deployable ~= nil then
        inst.components.deployable.restrictedtag = "nobody"
    end
    if inst.components.prototyper ~= nil then
        inst.components.prototyper.restrictedtag = "nobody"
    end
end)

-- Disable crafting of spice equipment
local AllRecipes = GLOBAL.AllRecipes

if AllRecipes ~= nil then
    if AllRecipes["portablespicer_item"] ~= nil then
        AllRecipes["portablespicer_item"].builder_tag = "nobody"
    end
    if AllRecipes["portableblender_item"] ~= nil then
        AllRecipes["portableblender_item"].builder_tag = "nobody"
    end
    if AllRecipes["spicepack"] ~= nil then
        AllRecipes["spicepack"].builder_tag = "nobody"
    end
end

AddClassPostConstruct("widgets/statusdisplays", function(self)
    if self.owner == nil or self.owner.prefab ~= "warly" then return end

    if not GetModConfigData("show_hud") then return end

    local y_offset = GetModConfigData("hud_y_offset") or 116  -- ← ici, pas dans le DoStaticTaskInTime
    local mem_size_opt = GetModConfigData("memory_size")

    local Widget = _require("widgets/widget")
    local Image  = _require("widgets/image")
    local UIAnim = _require("widgets/uianim")

    local mem_net = GLOBAL.net_string(self.owner.GUID, "warly_mem_queue", "warlymemqueueupdate")

    self.warly_memory = self:AddChild(Widget("warly_food_memory"))

    local SLOT_SCALE = 0.55
    local ICON_SCALE = 0.35
    local STEP       = 40

    local function RefreshIcons()

        self.warly_memory:KillAllChildren()

        local encoded = mem_net:value()
        local queue = {}
        if encoded and encoded ~= "" then
            for part in encoded:gmatch("[^,]+") do
                table.insert(queue, part)
            end
        end

        local N = 2
        if mem_size_opt ~= nil and mem_size_opt ~= "default" then
            N = mem_size_opt
        elseif GLOBAL.TheWorld and GLOBAL.TheWorld.state then
            local cycles = GLOBAL.TheWorld.state.cycles
            if cycles >= 70 then N = 4
            elseif cycles >= 35 then N = 3 end
        end

        for i = 1, N do
            local slot = self.warly_memory:AddChild(Widget("slot_" .. i))
            slot:SetPosition(0, -(i - 1) * STEP, 0)

            -- Fond sombre (derrière tout)
            local bg = slot:AddChild(UIAnim())
            bg:GetAnimState():SetBank("status_clear_bg")
            bg:GetAnimState():SetBuild("status_clear_bg")
            bg:GetAnimState():PlayAnimation("backing")
            bg:SetScale(SLOT_SCALE, SLOT_SCALE, 1)


            -- Icône du plat (entre fond et contour)
            local prefab = queue[#queue + 1 - i]
            if prefab then
                local atlas = GLOBAL.GetInventoryItemAtlas(prefab .. ".tex")
                if atlas then
                    local icon = slot:AddChild(Image(atlas, prefab .. ".tex"))
                    icon:SetScale(ICON_SCALE, ICON_SCALE, 1)
                    icon:SetPosition(0, 1, 0)
                end
            end

            -- Contour doré (au premier plan, par-dessus l'icône)
            local frame = slot:AddChild(UIAnim())
            frame:GetAnimState():SetBank("status_meter")
            frame:GetAnimState():SetBuild("status_meter")
            frame:GetAnimState():PlayAnimation("frame")
            frame:SetScale(SLOT_SCALE, SLOT_SCALE, 1)
        end
    end

    self.inst:DoStaticTaskInTime(0, function()
        local heart_pos = self.heart:GetPosition()
        local brain_pos = self.brain:GetPosition()
        -- Position sous le badge sanité mentale, aligné sur la colonne du cœur
        self.warly_memory:SetPosition(heart_pos.x + 10, heart_pos.y - y_offset, 0)
        RefreshIcons()
    end)

    self.inst:ListenForEvent("warlymemqueueupdate", function()
        self.inst:DoStaticTaskInTime(0, function()
            if self.warly_memory ~= nil then RefreshIcons() end
        end)
    end, self.owner)

    self.inst:ListenForEvent("cycleschanged", function()
        self.inst:DoStaticTaskInTime(0, function()
            if self.warly_memory ~= nil then RefreshIcons() end
        end)
    end, GLOBAL.TheWorld)

    local _SetGhostMode = self.SetGhostMode
    self.SetGhostMode = function(this, ghostmode)
        _SetGhostMode(this, ghostmode)
        if self.warly_memory then
            if ghostmode then self.warly_memory:Hide()
            else self.warly_memory:Show() end
        end
    end
end)

-- === PHASE 4 : Plats exclusifs ===

AddComponentPostInit("stewer", function(self)
    local orig = self.StartCooking
    self.StartCooking = function(stewer, doer, ...)
        GLOBAL.WARLY_CURRENT_CHEF = doer
        orig(stewer, doer, ...)
        GLOBAL.WARLY_CURRENT_CHEF = nil
    end
end)

local function warly_only(test_fn)
    return function(cooker, names, tags)
        local chef = GLOBAL.WARLY_CURRENT_CHEF
        if chef == nil or not chef:HasTag("masterchef") then
            return false
        end
        return test_fn(cooker, names, tags)
    end
end

local moqueca = {
    name = "moqueca",
    test = warly_only(function(cooker, names, tags)
        return tags.fish and (names.onion or names.onion_cooked)
            and (names.tomato or names.tomato_cooked) and not tags.inedible
    end),
    priority = 30,
    foodtype = GLOBAL.FOODTYPE.MEAT,
    health  = TUNING.HEALING_HUGE,    -- 60
    hunger  = 90,
    sanity  = TUNING.SANITY_LARGE,    -- 33
    perishtime = TUNING.PERISH_FASTISH,
    cooktime = 2,
    potlevel = "low",
    weight = 1,
    tags = {"masterfood"},
    cookbook_category = "portablecookpot",
}

AddPrefabPostInit("moqueca", function(inst)
    if inst.components.edible then
        inst.components.edible.hungervalue = 90
    end
end)

local cooking = _require("cooking")
cooking.recipes["cookpot"] = cooking.recipes["cookpot"] or {}
cooking.recipes["cookpot"]["moqueca"] = moqueca
cooking.recipes["portablecookpot"]["moqueca"] = moqueca

-- ─── bonesoup (bone bouillon) ───────────────────────────────────────────────
-- Stats identiques au vanilla (32 HP / 150 faim / 5 sanité), on ajoute juste
-- la restriction warly_only et l'accès depuis le cookpot normal.
local bonesoup = {
    name = "bonesoup",
    test = warly_only(function(cooker, names, tags)
        return names.boneshard and names.boneshard == 2
            and (names.onion or names.onion_cooked)
            and (tags.inedible and tags.inedible < 3)
    end),
    priority  = 30,
    foodtype  = GLOBAL.FOODTYPE.MEAT,
    health    = TUNING.HEALING_MEDSMALL * 4,  -- 32
    hunger    = TUNING.CALORIES_LARGE * 4,    -- 150
    sanity    = TUNING.SANITY_TINY,           -- 5
    perishtime = TUNING.PERISH_MED,
    cooktime  = 2,
    weight    = 1,
    tags      = {"masterfood"},
    cookbook_category = "portablecookpot",
}
cooking.recipes["cookpot"]["bonesoup"]        = bonesoup
cooking.recipes["portablecookpot"]["bonesoup"] = bonesoup

-- ─── monstertartare ─────────────────────────────────────────────────────────
-- Seul changement : faim 62.5 → 75. On corrige via AddPrefabPostInit.
local monstertartare = {
    name = "monstertartare",
    test = warly_only(function(cooker, names, tags)
        return tags.monster and tags.monster >= 2 and not tags.inedible
    end),
    priority         = 30,
    foodtype         = GLOBAL.FOODTYPE.MEAT,
    secondaryfoodtype = GLOBAL.FOODTYPE.MONSTER,
    health    = -TUNING.HEALING_MED,        -- -20
    hunger    = 75,                          -- vs vanilla 62.5
    sanity    = -TUNING.SANITY_MEDLARGE,    -- -20
    perishtime = TUNING.PERISH_MED,
    cooktime  = 0.5,
    weight    = 1,
    tags      = {"masterfood", "monstermeat"},
    cookbook_category = "portablecookpot",
}

AddPrefabPostInit("monstertartare", function(inst)
    if inst.components.edible then
        inst.components.edible.hungervalue = 75
    end
end)

cooking.recipes["cookpot"]["monstertartare"]        = monstertartare
cooking.recipes["portablecookpot"]["monstertartare"] = monstertartare

-- ─── frogfishbowl (fish cordon bleu) ────────────────────────────────────────
local frogfishbowl = {
    name = "frogfishbowl",
    test = warly_only(function(cooker, names, tags)
        return ((names.froglegs and names.froglegs >= 2)
            or (names.froglegs_cooked and names.froglegs_cooked >= 2)
            or (names.froglegs and names.froglegs_cooked))
            and tags.fish and tags.fish >= 1
            and not tags.inedible
    end),
    priority   = 35,
    foodtype   = GLOBAL.FOODTYPE.MEAT,
    health     = TUNING.HEALING_MED,      -- 20
    hunger     = TUNING.CALORIES_LARGE,   -- 37.5
    sanity     = -TUNING.SANITY_SMALL,    -- -10
    perishtime = TUNING.PERISH_FASTISH,
    cooktime   = 2,
    weight     = 1,
    tags       = {"masterfood"},
    prefabs    = {"buff_moistureimmunity"},
    oneatenfn  = function(inst, eater)
        eater:AddDebuff("buff_moistureimmunity", "buff_moistureimmunity")
        local buff = eater.components.debuffable
            and eater.components.debuffable:GetDebuff("buff_moistureimmunity")
        if buff ~= nil and buff.components.timer ~= nil then
            buff.components.timer:SetTimeLeft("buffover", TUNING.TOTAL_DAY_TIME)
        end
    end,
    cookbook_category = "portablecookpot",
}

AddPrefabPostInit("frogfishbowl", function(inst)
    if inst.components.edible then
        local orig = inst.components.edible.oneaten
        inst.components.edible.oneaten = function(item, eater)
            if orig then orig(item, eater) end
            local buff = eater.components.debuffable
                and eater.components.debuffable:GetDebuff("buff_moistureimmunity")
            if buff ~= nil and buff.components.timer ~= nil then
                buff.components.timer:SetTimeLeft("buffover", TUNING.TOTAL_DAY_TIME)
            end
        end
    end
end)

cooking.recipes["cookpot"]["frogfishbowl"]        = frogfishbowl
cooking.recipes["portablecookpot"]["frogfishbowl"] = frogfishbowl


-- ─── gazpacho (asparagazpacho) ───────────────────────────────────────────────
-- Stats identiques au vanilla (3 HP / 25 faim / 10 sanité).
-- Les champs temperature/temperatureduration gèrent le bonus de froid directement
-- dans le composant edible, sans oneatenfn.
local gazpacho = {
    name = "gazpacho",
    test = warly_only(function(cooker, names, tags)
        return ((names.asparagus and names.asparagus >= 2)
            or (names.asparagus_cooked and names.asparagus_cooked >= 2)
            or (names.asparagus and names.asparagus_cooked))
            and tags.frozen and tags.frozen >= 2
    end),
    priority            = 30,
    foodtype            = GLOBAL.FOODTYPE.VEGGIE,
    health              = TUNING.HEALING_SMALL,          -- 3
    hunger              = TUNING.CALORIES_MED,           -- 25
    sanity              = TUNING.SANITY_SMALL,           -- 10
    temperature         = TUNING.COLD_FOOD_BONUS_TEMP,   -- -40
    temperatureduration = TUNING.TOTAL_DAY_TIME, -- 1 jour
    perishtime          = TUNING.PERISH_SLOW,
    cooktime            = 0.5,
    weight              = 1,
    tags                = {"masterfood", "fooddrink"},
    cookbook_category   = "portablecookpot",
}
cooking.recipes["cookpot"]["gazpacho"]        = gazpacho
cooking.recipes["portablecookpot"]["gazpacho"] = gazpacho

-- ─── nightmarepie (grim galette) ─────────────────────────────────────────────
-- Nouvelle recette : 2 nightmare fuels + 1 valeur végétale (vs vanilla : 2 NF + potato + onion)
-- HP corrigé via AddPrefabPostInit : HEALING_TINY (1) → 5
-- On conserve l'oneatenfn vanilla qui swape HP ↔ Sanité en %.
local nightmarepie = {
    name = "nightmarepie",
    test = warly_only(function(cooker, names, tags)
        return names.nightmarefuel and names.nightmarefuel == 2
            and tags.veggie and tags.veggie >= 1
    end),
    priority   = 30,
    foodtype   = GLOBAL.FOODTYPE.VEGGIE,
    health     = TUNING.HEALING_TINY,   -- 1 (écrasé par AddPrefabPostInit → 5)
    hunger     = TUNING.CALORIES_MED,   -- 25
    sanity     = TUNING.SANITY_TINY,    -- 5
    perishtime = TUNING.PERISH_MED,
    cooktime   = 2,
    weight     = 1,
    tags       = {"masterfood", "unsafefood"},
    oneatenfn  = function(inst, eater)
        if eater.components.sanity ~= nil
            and eater.components.health ~= nil
            and eater.components.oldager == nil
        then
            local sanity_pct = eater.components.sanity:GetPercent()
            local health_pct = eater.components.health:GetPercent()
            eater.components.sanity:DoDelta(
                health_pct * eater.components.sanity.max - eater.components.sanity.current)
            eater.components.health:DoDelta(
                sanity_pct * eater.components.health.maxhealth - eater.components.health.currenthealth,
                nil, "nightmarepie")
        end
    end,
    cookbook_category = "portablecookpot",
}

AddPrefabPostInit("nightmarepie", function(inst)
    if inst.components.edible then
        inst.components.edible.healthvalue = 5
    end
end)

cooking.recipes["cookpot"]["nightmarepie"]        = nightmarepie
cooking.recipes["portablecookpot"]["nightmarepie"] = nightmarepie

-- ─── voltgoatjelly (volt goat chaud-froid) ──────────────────────────────────
local voltgoatjelly = {
    name = "voltgoatjelly",
    test = warly_only(function(cooker, names, tags)
        return names.lightninggoathorn
            and tags.sweetener and tags.sweetener >= 1
            and tags.frozen   and tags.frozen   >= 1
    end),
    priority   = 30,
    foodtype   = GLOBAL.FOODTYPE.GOODIES,
    health     = TUNING.HEALING_SMALL,   -- 3
    hunger     = TUNING.CALORIES_LARGE,  -- 37.5
    sanity     = TUNING.SANITY_TINY,     -- 5 (vanilla = SANITY_SMALL = 10)
    perishtime = TUNING.PERISH_MED,
    cooktime   = 2,
    weight     = 1,
    tags       = {"masterfood"},
    prefabs    = {"buff_electricattack"},
    oneatenfn  = function(inst, eater)
        -- Buff électrique avec durée 1 jour complet
        eater:AddDebuff("buff_electricattack", "buff_electricattack")
        local buff = eater.components.debuffable
            and eater.components.debuffable:GetDebuff("buff_electricattack")
        if buff ~= nil and buff.components.timer ~= nil then
            buff.components.timer:SetTimeLeft("buffover", TUNING.TOTAL_DAY_TIME)
        end
    end,
    cookbook_category = "portablecookpot",
}

AddPrefabPostInit("voltgoatjelly", function(inst)
    if inst.components.edible then
        inst.components.edible.sanityvalue = 5
        local orig = inst.components.edible.oneaten
        inst.components.edible.oneaten = function(item, eater)
            if orig then orig(item, eater) end
            local buff = eater.components.debuffable
                and eater.components.debuffable:GetDebuff("buff_electricattack")
            if buff ~= nil and buff.components.timer ~= nil then
                buff.components.timer:SetTimeLeft("buffover", TUNING.TOTAL_DAY_TIME)
            end
        end
    end
end)

cooking.recipes["cookpot"]["voltgoatjelly"]        = voltgoatjelly
cooking.recipes["portablecookpot"]["voltgoatjelly"] = voltgoatjelly
