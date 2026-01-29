local statesHandler = {}

local TweenService = game:GetService("TweenService")
local mapping = require(script.Parent.Parent.mapping)
local classes = require(script.Parent.Parent.classes)
local advancedClasses = require(script.Parent.Parent.advancedClasses)

function statesHandler.handle(element, value, hoverDisabled)
    local oldvalues = {}
    local advInstances = {}

    element.MouseEnter:Connect(function()
        if hoverDisabled then return end
        if not value then return end

        local animationSettings = value["animate"]
        local targetDataTable = animationSettings or value

        for hoverKey, hoverValue in pairs(targetDataTable) do
            -- Skip configuration keys if using the "animate" table structure
            if hoverKey == "duration" or hoverKey == "easingStyle" or hoverKey == "easingDirection" then 
                continue 
            end

            local property = mapping[hoverKey]
            if not property then continue end

            ---------------------------------------------------------
            -- 1. AdvancedClass Support (External Instances)
            ---------------------------------------------------------
            local advClassTable = advancedClasses[hoverKey]
            local advFunc = advClassTable and advClassTable[hoverValue]

            if type(advFunc) == "function" then
                local advInstance = advFunc(element)
                if advInstance and typeof(advInstance) == "Instance" then
                    advInstances[hoverKey] = advInstance

                    -- Capture original value
                    if oldvalues[hoverKey] == nil then
                        oldvalues[hoverKey] = advInstance[property]
                    end

                    if animationSettings then
                        local info = TweenInfo.new(
                            animationSettings.duration or 0.5,
                            animationSettings.easingStyle or Enum.EasingStyle.Linear,
                            animationSettings.easingDirection or Enum.EasingDirection.InOut
                        )
                        TweenService:Create(advInstance, info, {[property] = hoverValue}):Play()
                    else
                        advInstance[property] = hoverValue
                    end
                end
                continue
            end

            ---------------------------------------------------------
            -- 2. Normal Class Support (Internal Children or Self)
            ---------------------------------------------------------

            -- Capture original values and handle special instances
            local targetInstance = element
            local targetProperty = property

            if property == "CornerRadius" then
                targetInstance = element:FindFirstChildOfClass("UICorner") or Instance.new("UICorner", element)
            elseif property == "UIStroke" or hoverKey == "strokeColor" then 
                -- Assuming mapping connects 'strokeColor' to 'Color'
                targetInstance = element:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke", element)
                targetProperty = "Color"
            end

            if oldvalues[hoverKey] == nil then
                oldvalues[hoverKey] = targetInstance[targetProperty]
            end
            
            local finalValue
            if typeof(hoverValue) == "string" then
                finalValue = classes[hoverKey][hoverValue]
            else
                finalValue = hoverValue
            end

            if animationSettings then
                local info = TweenInfo.new(
                    animationSettings.duration or 0.5,
                    animationSettings.easingStyle or Enum.EasingStyle.Linear,
                    animationSettings.easingDirection or Enum.EasingDirection.InOut
                )
                TweenService:Create(targetInstance, info, {[targetProperty] = finalValue}):Play()
            else
                targetInstance[targetProperty] = finalValue
            end
        end
    end)

    element.MouseLeave:Connect(function()
        if hoverDisabled or not value then return end

        local animationSettings = value["animate"]
        local targetDataTable = animationSettings or value

        for hoverKey, _ in pairs(targetDataTable) do
            if hoverKey == "duration" or hoverKey == "easingStyle" or hoverKey == "easingDirection" then 
                continue 
            end

            local property = mapping[hoverKey]
            local originalValue = oldvalues[hoverKey]
            if not property or originalValue == nil then continue end

            local targetInstance = advInstances[hoverKey] or element
            local targetProperty = property

            -- Resolve internal instances for Leave
            if not advInstances[hoverKey] then
                if property == "CornerRadius" then
                    targetInstance = element:FindFirstChildOfClass("UICorner")
                elseif property == "UIStroke" or hoverKey == "strokeColor" then
                    targetInstance = element:FindFirstChildOfClass("UIStroke")
                    targetProperty = "Color"
                end
            end

            if not targetInstance then continue end

            if animationSettings then
                local info = TweenInfo.new(
                    animationSettings.duration or 0.5,
                    animationSettings.easingStyle or Enum.EasingStyle.Linear,
                    animationSettings.easingDirection or Enum.EasingDirection.InOut
                )
                TweenService:Create(targetInstance, info, {[targetProperty] = originalValue}):Play()
            else
                targetInstance[targetProperty] = originalValue
            end
        end
    end)
end

return statesHandler