local Roact = require(script.Parent.Parent.Parent.Parent.Roact)
local DropdownItem = Roact.Component:extend("DropdownItem")

local Theme = require(script.Parent.Parent.Parent.Themes.Theme)

function DropdownItem:init()
    self.state = {
        isHovered = false
    }
end

function DropdownItem:render()
    local option = self.props.Option
    local isDisabled = option.Disabled or false

    return Roact.createElement("TextButton", {
        Size = UDim2.new(1, 0, 0, 24),
        Text = "",
        BackgroundColor3 = self.state.isHovered and Theme.AccentMuted or Theme.ModalBG,
        BorderSizePixel = 0,
        LayoutOrder = self.props.LayoutOrder,
        AutoButtonColor = false,
        ZIndex = 1003,
        [Roact.Event.MouseEnter] = function()
            if not isDisabled then 
                self:setState({ isHovered = true })
            end
        end,
        [Roact.Event.MouseLeave] = function()
            self:setState({ isHovered = false })
        end,
        [Roact.Event.Activated] = function()
            if not isDisabled then
                if option.Callback then
                    option.Callback()
                end
                if self.props.OnActivated then
                    self.props.OnActivated()
                end
            end
        end
    }, {
        Padding = Roact.createElement("UIPadding", {
            PaddingLeft = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 10),
        }),

        Label = Roact.createElement("TextLabel", {
            Size = UDim2.new(1, -80, 1, 0),
            Text = option.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = isDisabled and Theme.TextDim or Theme.TextMain,
            BackgroundTransparency = 1,
            FontFace = Theme.FontNormal,
            TextSize = 14,
            ZIndex = 1003,
        }),

        Shortcut = option.Shortcut and Roact.createElement("TextLabel", {
            Size = UDim2.fromOffset(70, 28),
            Position = UDim2.new(1, 0, 0, 0),
            AnchorPoint = Vector2.new(1, 0),
            Text = option.Shortcut,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextColor3 = Theme.TextDim,
            BackgroundTransparency = 1,
            FontFace = Theme.FontNormal,
            TextSize = 13,
            ZIndex = 1003,
        }),
    })
end

return DropdownItem