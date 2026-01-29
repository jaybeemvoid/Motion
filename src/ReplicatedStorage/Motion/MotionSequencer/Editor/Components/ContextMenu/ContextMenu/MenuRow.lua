local Roact = require(script.Parent.Parent.Parent.Parent.Parent.Roact)
local MenuRow = Roact.Component:extend("MenuRow")

local Theme = require(script.Parent.Parent.Parent.Parent.Themes.Theme)

function MenuRow:init()
    self.state = {
        isHovered = false
    }
end

function MenuRow:render()
    local item = self.props.item
    local layoutOrder = self.props.layoutOrder
    local isDisabled = item.Disabled == true
    
    if item.Type == "Divider" then
        return Roact.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = Theme.Separator,
            BorderSizePixel = 0,
            LayoutOrder = layoutOrder,
        })
    end

    local isSubMenu = item.Type == "SubMenu"

    return Roact.createElement("TextButton", {
        Size = UDim2.new(1, 0, 0, 17),
        LayoutOrder = layoutOrder,

        BackgroundColor3 = (not isDisabled and self.state.isHovered) and Theme.AccentHover or Theme.TextDim,
        BackgroundTransparency = (not isDisabled and self.state.isHovered) and 0 or 1,
        Text = "  " .. (item.Name or ""),
        TextColor3 = item.Color or Theme.TextMain,
        Font = Enum.Font.SourceSans,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,

        [Roact.Event.MouseEnter] = function()
            if isDisabled then return end
            self:setState({ isHovered = true })

            local item = self.props.item
            local level = self.props.level or 1

            local subMenuOffset = Vector2.new(158, (self.props.rowIndex - 1) * 17)

            if self.props.onHoverSubMenu then
                self.props.onHoverSubMenu(level, item, subMenuOffset)
            end
        end,

        [Roact.Event.MouseLeave] = function()
            self:setState({ isHovered = false })
        end,

        [Roact.Event.Activated] = function()
            if isDisabled then return end
            if item.Type ~= "SubMenu" and self.props.onAction then
                self.props.onAction(item.Type, item.Value)
            end
        end
    }, {
        Arrow = isSubMenu and Roact.createElement("TextLabel", {
            Size = UDim2.new(0, 20, 1, 0),
            Position = UDim2.new(1, -20, 0, 0),
            Text = ">",
            BackgroundTransparency = 1,
            TextColor3 = Theme.TextDim,
            TextSize = 12,
        })
    })
end

return MenuRow