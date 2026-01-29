local HttpService = game:GetService("HttpService")

return function(projectTable)
    local success, result = pcall(function()
        return HttpService:JSONEncode(projectTable)
    end)

    if success then
        return result
    else
        warn("Failed to encode project: " .. result)
        return nil
    end
end