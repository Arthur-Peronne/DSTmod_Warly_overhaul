print("[Warly Overhaul] modmain.lua loaded")

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
        if GLOBAL.TheWorld and GLOBAL.TheWorld.state then
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
