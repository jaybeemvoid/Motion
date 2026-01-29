local HttpService = game:GetService("HttpService")

return function(jsonString : string)
    local success, result = pcall(function()
        return HttpService:JSONDecode(jsonString)
    end)

    if success then
        return result
    else
        warn("Failed to decode project: " .. result)
        return nil
    end
end