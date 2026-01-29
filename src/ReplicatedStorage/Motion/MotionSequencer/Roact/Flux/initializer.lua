local initalizer = {}

local classes = require(script.Parent.classes)
local advancedClasses = require(script.Parent.advancedClasses)
local mapping = require(script.Parent.mapping)
local types = require(script.Parent.types)
local util = require(script.Parent.util)

function initalizer.init()
	local configClasses = require(script.Parent.config).classes

	for key, value in pairs(configClasses) do
		if not classes[key] then
			classes[key] = value
		else
			for subKey, subValue in pairs(value) do
				if not classes[key][subKey] then
					classes[key][subKey] = subValue
				end
			end
		end
	end
end

local function resolveValue(property, value, element)
	if classes[property] and classes[property][value] ~= nil then
		return classes[property][value]
	end

	if advancedClasses[property] and advancedClasses[property][value] then
		local advancedValue = advancedClasses[property][value]
		if type(advancedValue) == "function" then
			advancedValue(element)
			return "FUNCTION_HANDLED"
		end
		return advancedValue
	end
	return value
end

local function runAllHandlers()
	local handlers = util.parse(script.Parent.handlers)
	if require(script.Parent.config).deMode then
		print(handlers)
	end
	return handlers
end

return {
	init = initalizer.init,
	resolveValue = resolveValue,
	classes = classes,
	advancedClasses = advancedClasses,
	map = mapping,
	handlers = runAllHandlers,
}

