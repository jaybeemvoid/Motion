local Roact = require(script.Parent.Parent.Parent.Parent.Roact)
local Timeline = Roact.Component:extend("Timeline")
local HorizontalScrollbar= require(script.HorizontalScrollbar)
local VerticalScrollbar = require(script.VerticalScrollbar)

function Timeline:render()
    return Roact.createElement("Frame", {
        Style = {
            s = UDim2.new(1, 0, 1, 0),
            opacity = "100",
        }
    }, {
        HorizontalSlider = Roact.createElement(HorizontalScrollbar, {
            position = self.props.scrollPercentX,
            canScroll = self.props.canScroll,
            maxScrollX = self.props.maxScrollX,
            onPositionChange = function(newPosition)
                self.props.onStateChange("viewport", {positionX = newPosition})
            end,
        }),
        VerticalSlider = Roact.createElement(VerticalScrollbar, {
            position = self.props.positionY,
            canScroll = self.props.canScroll,
            onPositionChange = function(newPosition)
                self.props.onStateChange("viewport", {positionY = newPosition})
            end,
            offsetY = self.props.offsetY
        })
    })
end

return Timeline
