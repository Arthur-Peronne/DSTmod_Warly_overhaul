print("[Warly Overhaul] modmain.lua loaded")

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

        -- Dish multiplier
        inst.components.eater.custom_stats_mod_fn = function(i, hp, hunger, sanity, food, feeder)
            local mult = i.components.warly_foodmemory:GetMultiplier(food.prefab)
            return hp * mult, hunger * mult, sanity * mult
        end

        -- Save dish after every meal
        inst:ListenForEvent("oneat", function(i, data)
            if data.food ~= nil and not data.food:HasTag("potion") then
                local occ = i.components.warly_foodmemory:GetOccurrences(data.food.prefab)
                i.components.warly_foodmemory:RememberFood(data.food.prefab)

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