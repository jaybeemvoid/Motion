local UserInputService = game:GetService("UserInputService")

local Roact = require(script.Parent.Parent.Parent.Parent.Parent.Roact)
local HorizontalScrollBar = Roact.Component:extend("HorizontalScrollbar")

local ScrollBarComponent = require(script.Parent.Parent.Parent.Parent.Components.Timeline.UIGlobalScroll)

function HorizontalScrollBar:render()
    return Roact.createElement(ScrollBarComponent, {
        orientation = "X",
        position = self.props.position,
        onPositionChange = self.props.onPositionChange,
        canScroll = self.props.canScroll,
    })
end

return HorizontalScrollBar