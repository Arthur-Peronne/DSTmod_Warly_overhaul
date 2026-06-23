print("[Warly Overhaul] modmain.lua loaded")

AddPrefabPostInit("warly", function(inst)
    inst.starting_inventory = {}
    inst:RemoveTag("expertchef")
    inst:RemoveTag("professionalchef")

    if inst.components.hunger then
        inst.components.hunger:SetMax(200)
        inst.components.hunger:SetRate(TUNING.WILSON_HUNGER_RATE)
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