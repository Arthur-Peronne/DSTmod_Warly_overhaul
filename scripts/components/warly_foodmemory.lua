require("warly_config")

local WFoodMemory = Class(function(self, inst)
    self.inst = inst
    self.queue = {}
end)

function WFoodMemory:GetMemorySize()
    local opt = WARLY_MEMORY_SIZE_OPTION
    if opt ~= nil and opt ~= "default" then
        return opt
    end
    if TheWorld == nil or TheWorld.state == nil then
        return WARLY_CONFIG.MEMORY_SIZES[1]
    end
    local cycles = TheWorld.state.cycles
    local t = WARLY_CONFIG.MEMORY_DAY_THRESHOLDS
    local s = WARLY_CONFIG.MEMORY_SIZES
    if cycles < t[1] then
        return s[1]
    elseif cycles < t[2] then
        return s[2]
    else
        return s[3]
    end
end

function WFoodMemory:RememberFood(prefab)
    local n = self:GetMemorySize()
    table.insert(self.queue, prefab)
    while #self.queue > n do
        table.remove(self.queue, 1)
    end
end

function WFoodMemory:GetOccurrences(prefab)
    local count = 0
    for _, v in ipairs(self.queue) do
        if v == prefab then
            count = count + 1
        end
    end
    return count
end

function WFoodMemory:GetMultiplier(prefab)
    local occ = self:GetOccurrences(prefab)
    if occ == 0 then
        return 1
    end
    return WARLY_CONFIG.MULTIPLIERS[occ] or 0
end

function WFoodMemory:OnSave()
    if #self.queue > 0 then
        return { queue = self.queue }
    end
end

function WFoodMemory:OnLoad(data)
    if data ~= nil and data.queue ~= nil then
        self.queue = data.queue
    end
end

return WFoodMemory
