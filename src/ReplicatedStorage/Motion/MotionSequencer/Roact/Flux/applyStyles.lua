--!strict
local initializer =require(script.Parent.initializer)
initializer.init()
local handlers = initializer.handlers()

local SPECIAL_STATES = {
	hover = true,
	click = true,
	activated = true,
	focus = true
}

local function applyStyles(element: GuiObject, data: types.StyleCard | string): GuiObject
	if not data then
		error("No data provided")
	end
	
	-- Handle string presets
	if type(data) == "string" then
		if not (initializer.classes.presets and initializer.classes.presets[data]) then
			error("Preset not found: " .. data)
		end
		return applyStyles(element, initializer.classes.presets[data])
	end

	for property, value in pairs(data) do
		if not SPECIAL_STATES[property] then
			-- Skip special states for now
			local resolvedValue = initializer.resolveValue(property, value, element)
		end
	end

	for property, value in pairs(data) do
		if SPECIAL_STATES[property] then
			if type(value) ~= "table" then
				warn(property .. " requires table value. Got: " .. type(value))
				continue
			end

			-- Handle animation presets
			if value.animate and type(value.animate) == "string" then
				value = initializer.classes.animate and initializer.classes.animate[value.animate] or value
			end

			local handlerName = property .. "Handler"
			if handlers[handlerName] then
				handlers[handlerName].handle(element, value, false)
			else
				warn("Handler not found for: " .. handlerName)
			end
			continue
		end

		local resolvedValue = initializer.resolveValue(property, value, element)

		if resolvedValue == "FUNCTION_HANDLED" then
			continue
		end

		local robloxProperty = initializer.map[property] -- e.g. CornerRadius
		if robloxProperty ~= nil then
			-- Special handling for corner radius
			if robloxProperty == "CornerRadius" then
				local corner = element:FindFirstChildOfClass("UICorner")
				if not corner then
					corner = Instance.new("UICorner")
					corner.Parent = element
				end
                corner.CornerRadius = resolvedValue
            elseif robloxProperty == "UIStroke" then
                local stroke: UIStroke = element:FindFirstChildOfClass("UIStroke")
                if not stroke then
                    stroke = Instance.new("UIStroke")
                    stroke.Parent = element
                end
                stroke.Color = resolvedValue
                stroke.Thickness = 1
                
			elseif robloxProperty == "VerticalAlignment" then
				local UIListLayout = element:FindFirstChildOfClass("UIListLayout")

				if not UIListLayout then
					return error("please add a list layout first")
				end

				UIListLayout.VerticalAlignment = resolvedValue

			elseif robloxProperty == "HorizontalAlignment" then
				local UIListLayout = element:FindFirstChildOfClass("UIListLayout")

				if not UIListLayout then
					return error("please add a list layout first")
				end

				UIListLayout.HorizontalAlignment = resolvedValue
			else
				element[robloxProperty] = resolvedValue
			end
		else
			warn(("Could not apply property '%s': %s"):format(
				property,
				robloxProperty and "Invalid Roblox property" or "No mapping found"
				))
		end
	end
	return element
end

return applyStyles
