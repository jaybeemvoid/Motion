local Roact = require(script.Parent.Parent.Parent.Parent.Roact)
local Panel = Roact.Component:extend("Panel")

function Panel:render()
    return Roact.createElement("Frame", {
        Size = self.props.size,
        Position = self.props.mousePos,
        Visible = self.props.isPanelOpen and true or false,
        BackgroundColor3 = Color3.fromRGB(28, 28, 30),
        BorderSizePixel = 0,
        ZIndex = 100,
    }, {
        Shadow = Roact.createElement("ImageLabel", {
            Size = UDim2.new(1, 24, 1, 24),
            Position = UDim2.fromOffset(-12, -12),
            BackgroundTransparency = 1,
            Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
            ImageColor3 = Color3.fromRGB(0, 0, 0),
            ImageTransparency = 0.6,
            ZIndex = 99,
            ScaleType = Enum.ScaleType.Slice,
            SliceCenter = Rect.new(12, 12, 12, 12),
        }),

        Border = Roact.createElement("UIStroke", {
            Thickness = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Color = Color3.fromRGB(65, 65, 70),
        }),

        Accent = Roact.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 2),
            BackgroundColor3 = Color3.fromRGB(0, 122, 204), 
            BorderSizePixel = 0,
            ZIndex = 101,
        }, {
            Gradient = Roact.createElement("UIGradient", {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 122, 204)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 150, 255)),
                })
            })
        }),

        Header = Roact.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 28),
            Position = UDim2.fromOffset(0, 2),
            BackgroundColor3 = Color3.fromRGB(35, 35, 38),
            BorderSizePixel = 0,
            ZIndex = 101,
        }, {
            Label = Roact.createElement("TextLabel", {
                Text = self.props.header,
                Size = UDim2.new(1, -12, 1, 0),
                Position = UDim2.fromOffset(12, 0),
                TextSize = 12,
                TextColor3 = Color3.fromRGB(220, 220, 220),
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
                BackgroundTransparency = 1,
                ZIndex = 102,
            }),

            Separator = Roact.createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 1),
                Position = UDim2.new(0, 0, 1, -1),
                BackgroundColor3 = Color3.fromRGB(50, 50, 55),
                BorderSizePixel = 0,
                ZIndex = 101,
            })
        }),

        Content = Roact.createElement("Frame", {
            Size = UDim2.new(1, -8, 1, -38),
            Position = UDim2.fromOffset(4, 34),
            BackgroundTransparency = 1,
            ZIndex = 100,
        }, self.props[Roact.Children]),

        Corner = Roact.createElement("UICorner", {
            CornerRadius = UDim.new(0, 8),
        })
    })
end

return Panel