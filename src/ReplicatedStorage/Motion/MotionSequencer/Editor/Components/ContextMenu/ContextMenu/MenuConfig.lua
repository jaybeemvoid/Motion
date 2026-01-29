return function(selectionCount, viewMode) -- Added viewMode parameter
    local isDisabled = selectionCount == 0
    local defaultColor = Color3.fromRGB(220, 220, 220)
    local disabledColor = Color3.fromRGB(100, 100, 100)
    local activeColor = isDisabled and disabledColor or defaultColor

    local menu = {
        {
            Name = "Create Keyframe",
            Type = "Action",
            Value = "CreateKeyframe",
            Color = activeColor,
            Disabled = isDisabled
        },
        {
            Name = "Paste",
            Type = "Action",
            Value = "PasteKeyframe",
            Color = activeColor,
            Disabled = isDisabled
        },
    }

    -- Only add editing actions if something is selected
    if not isDisabled then
        table.insert(menu, {
            Name = "Copy",
            Type = "Action",
            Value = "CopyKeyFrame",
            Color = defaultColor,
        })
        table.insert(menu, {
            Name = "Duplicate Keyframe",
            Type = "Action",
            Value = "DuplicateKeyframe",
            Color = defaultColor,
        })
        table.insert(menu, {
            Name = "Delete Keyframe",
            Type = "Action",
            Value = "Delete",
            Color = Color3.fromRGB(255, 100, 100),
        })

        -- Separator logic or spacing can go here

        table.insert(menu, {
            Name = "Interpolation",
            Type = "SubMenu",
            Children = { 
                { Name = "Linear", Type = "Interpolation", Value = "Linear" },
                { Name = "Bezier", Type = "Interpolation", Value = "Bezier" },
                
            },
            Color = defaultColor,
        })

        if viewMode == "Graph" then
            table.insert(menu, {
                Name = "Tangent Mode",
                Type = "SubMenu",
                Children = {
                    { Name = "Mirrored", Type = "TangentMode", Value = "Mirrored" },
                    { Name = "Aligned", Type = "TangentMode", Value = "Aligned" },
                    { Name = "Free", Type = "TangentMode", Value = "Free" },
                },
                Color = Color3.fromRGB(150, 200, 255),
            })
        end

        table.insert(menu, {
            Name = "Direction",
            Type = "SubMenu",
            Children = {
                { Name = "In", Type = "InterpolationDirection", Value = "In" },
                { Name = "Out", Type = "InterpolationDirection", Value = "Out" },
                { Name = "In-Out", Type = "InterpolationDirection", Value = "In-Out" },
                { Name = "Out-In", Type = "InterpolationDirection", Value = "Out-In" },
            },
            Color = defaultColor,
        })
    end

    return menu
end