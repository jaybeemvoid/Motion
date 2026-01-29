local Roact = require(script.Parent.Parent.Parent.Parent.Roact)
local InterpolationPanel = Roact.Component:extend("InterpolationPanel")

local PanelComponent = require(script.Parent.Parent.Parent.Components.Inspector.Panel)

local EasingStyles = {
    "Linear", "Sine", "Back", "Quad", "Quart", "Quint", 
    "Bounce", "Elastic", "Exponential", "Circular", "Cubic"
}

function InterpolationPanel:render()
    local children = {
        UIPadding = Roact.createElement("UIPadding", {
            PaddingLeft = UDim.new(0, 4),
            PaddingTop = UDim.new(0, 2),
        }),
        Grid = Roact.createElement("UIGridLayout", {
            CellSize = UDim2.fromOffset(52, 22), -- Slightly wider for longer names like "Elastic"
            CellPadding = UDim2.fromOffset(4, 4),
        }),
    }
    
    for i, name in ipairs(EasingStyles) do
        children[name] = Roact.createElement("TextButton", {
            LayoutOrder = i,
            BackgroundColor3 = Color3.fromRGB(45, 45, 45),
            Text = name,
            Font = Enum.Font.SourceSans,
            TextSize = 12,
            TextColor3 = Color3.fromRGB(200, 200, 200),
            
            [Roact.Event.Activated] = function()
                if self.props.setSelectionEasingStyle then
                    self.props.setSelectionEasingStyle(name)
                end
            end,
        }, {
            Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 1) }),
            Border = Roact.createElement("UIStroke", {
                Color = Color3.fromRGB(60, 60, 60),
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            })
        })
    end
    
    return Roact.createElement(PanelComponent, {
        size = UDim2.fromOffset(174, 180),
        header = "INTERPOLATION",
        isPanelOpen = self.props.isPanelOpen,
        mousePos = self.props.mousePos,
    }, children)
end

return InterpolationPanel
