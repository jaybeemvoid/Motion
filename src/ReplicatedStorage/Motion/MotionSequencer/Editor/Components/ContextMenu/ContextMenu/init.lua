local Roact = require(script.Parent.Parent.Parent.Parent.Roact)
local MenuRow = require(script.MenuRow)

local ContextMenu = Roact.Component:extend("ContextMenu")

local getMenuConfig = require(script.MenuConfig)

local Theme = require(script.Parent.Parent.Parent.Themes.Theme)

function ContextMenu:render()
    local selectionCount = self.props.selectionCount or 0
    local mode = self.props.mode or "Timeline"

    local items = self.props.items or getMenuConfig(selectionCount, mode)

    local children = {
        UIList = Roact.createElement("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 0),
        }),
    }

    for i, item in ipairs(items) do
        children["Item_" .. i] = Roact.createElement(MenuRow, {
            item = item,
            layoutOrder = i,
            level = self.props.level,
            rowIndex = i,
            onAction = self.props.onAction,
            onHoverSubMenu = self.props.onHoverSubMenu,
        })
    end

    return Roact.createElement("Frame", {
        Size = UDim2.new(0, 160, 0, #items * 17 + 4), 
        Position = self.props.mousePos,
        Visible = self.props.isPanelOpen,
        BackgroundColor3 = Theme.ModalBG,
        ZIndex = 10,
        Active = true,
    }, {
        Border = Roact.createElement("UIStroke", {
            Color = Theme.BorderLight,
            Thickness = 1,
        }),
        Accent = Roact.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 2),
            BackgroundColor3 = Theme.AccentMuted,
            BorderSizePixel = 0,
        }),
        Content = Roact.createElement("Frame", {
            Size = UDim2.new(1, 0, 1, -4),
            Position = UDim2.fromOffset(0, 2),
            BackgroundTransparency = 1,
        }, children)
    })
end

return ContextMenu