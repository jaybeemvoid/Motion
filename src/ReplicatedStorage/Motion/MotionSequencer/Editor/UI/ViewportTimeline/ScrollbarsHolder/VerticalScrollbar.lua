local UserInputService = game:GetService("UserInputService")
local Roact = require(script.Parent.Parent.Parent.Parent.Parent.Roact)
local VerticalScrollBar = Roact.Component:extend("VerticalScrollBar")

local ScrollBarComponent = require(script.Parent.Parent.Parent.Parent.Components.Timeline.UIGlobalScroll)

function VerticalScrollBar:render()
    return Roact.createElement(ScrollBarComponent, {
        orientation = "Y",
        position = self.props.position,
        onPositionChange = self.props.onPositionChange,
        offsetY = self.props.offsetY,
        canScroll = self.props.canScroll,
    })
end

return VerticalScrollBar