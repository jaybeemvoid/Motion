local Roact = require(script.Parent.Parent.Parent.Parent.Parent.Roact)
local VerticalLines = Roact.Component:extend("VerticalLines")

local Theme = require(script.Parent.Parent.Parent.Parent.Themes.Theme)

function VerticalLines:render()
    local divs = {} 

    for i = 0, self.props.totalSeconds do
        -- Use Position instead of ps if your Style bridge is acting up
        local posX = UDim2.new(0, i * self.props.pixelsPerSecond, 0, 0)

        divs["Vdiv_" .. i] = Roact.createElement("Frame", {
            -- Ensure we use the 'Offset' for the 1-pixel width
            Size = UDim2.new(0, 1, 1, 0),
            Position = posX,
            BackgroundColor3 = Theme.GridMajor, -- text-secondary equivalent
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0),
            ZIndex = 2,
        })
    end

    -- Wrap in a container so UIListLayout doesn't move individual lines
    return Roact.createElement("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        -- This ensures the lines don't get shifted by a UIListLayout in the parent
        Position = UDim2.new(0, 0, 0, 0), 
    }, divs)
end

return VerticalLines