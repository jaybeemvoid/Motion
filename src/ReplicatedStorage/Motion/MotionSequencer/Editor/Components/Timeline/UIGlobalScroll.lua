local UserInputService = game:GetService("UserInputService")

local Roact = require(script.Parent.Parent.Parent.Parent.Roact)
local Scrollbar = Roact.Component:extend("Scrollbar")

local Theme = require(script.Parent.Parent.Parent.Themes.Theme)

function Scrollbar:init()
    self.state = {
        dragging = false,
        absoluteSize = 50, 
        absolutePos = 0,
    }

    self.sliderRef = Roact.createRef()
end

function Scrollbar:didMount()
    local slider = self.sliderRef:getValue()
    if slider then
        local function updateSize()
            local axis = self.props.orientation or "X"
            self:setState({
                absoluteSize = (axis == "X") and slider.AbsoluteSize.X or slider.AbsoluteSize.Y,
                absolutePos = (axis == "X") and slider.AbsolutePosition.X or slider.AbsolutePosition.Y,
            })
        end

        self.sizeConn = slider:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateSize)
        self.posConn = slider:GetPropertyChangedSignal("AbsolutePosition"):Connect(updateSize)
        updateSize()
    end
end

function Scrollbar:render()
    local axis = self.props.orientation or "X"
    local positionPercent = self.props.position or 0
    local usableBarWidth = math.max(1, self.state.absoluteSize - 10)
    local knobWidthPx = math.clamp(usableBarWidth * 0.1, 20, 40)
    
    local knobOffsetPx = positionPercent * (usableBarWidth - knobWidthPx)

    local frameSize = (axis == "X") and UDim2.new(1, 0, 0, 25) or UDim2.new(0, 25, 1, -25)
    local knobPos = (axis == "X") 
        and UDim2.new(0, knobOffsetPx, 0.5, 0) 
        or UDim2.new(0.5, 0, 0, knobOffsetPx)

    return Roact.createElement("Frame", {
        Size = frameSize,
        Position = (axis == "X") and UDim2.new(0.5, 0, 1, 0) or UDim2.new(0, 0, 0, 0),
        AnchorPoint = (axis == "X") and Vector2.new(0.5, 1) or Vector2.new(0, 0),
        BackgroundColor3 = Theme.ScrollTrack,
        ZIndex = 2,
    }, {
        Slider = Roact.createElement("Frame", {
            [Roact.Ref] = self.sliderRef,
            Style = {
                align = "center",
                s = (axis == "X") and UDim2.new(1, -30, 0, 10) or UDim2.new(0, 10, 1, -30),
                round = UDim.new(0, 3),
                z = 2
            }
        }, {
            UIPadding = Roact.createElement("UIPadding", {
                PaddingLeft = UDim.new(0, 5),
                PaddingRight = UDim.new(0, 5),
            }),
            Knob = Roact.createElement("Frame", {
                ZIndex = 2,
                BackgroundColor3 = Theme.ScrollThumb,
                Size = (axis == "X") and UDim2.new(0, knobWidthPx, 1, 0) or UDim2.new(1, 10, 0, knobWidthPx),
                Style = {
                    round = UDim.new(0, 2),
                },
                AnchorPoint = (axis == "X") and Vector2.new(0, 0.5) or Vector2.new(0.5, 0.5),
                Position = knobPos,
                
                [Roact.Event.InputBegan] = function(rbx, input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        self:setState({ dragging = true })

                        local axis = self.props.orientation or "X"
                        local slider = self.sliderRef:getValue()
                        if not slider then return end

                        local barAbsPos = (axis == "X") and slider.AbsolutePosition.X or slider.AbsolutePosition.Y

                        local startMousePos = (axis == "X") and input.Position.X or input.Position.Y
                        local mousePosInBar = startMousePos - barAbsPos

                        local usableBarWidth = math.max(1, self.state.absoluteSize - 10)
                        local knobWidthPx = math.clamp(usableBarWidth * 0.1, 20, 40)
                        local currentKnobOffset = (self.props.position or 0) * (usableBarWidth - knobWidthPx)

                        local clickOffsetInKnob = mousePosInBar - currentKnobOffset

                        local moveConn, releaseConn

                        moveConn = rbx.InputChanged:Connect(function(input2)
                            if input2.UserInputType == Enum.UserInputType.MouseMovement then
                                local currentMousePos = (axis == "X") and input2.Position.X or input2.Position.Y

                                local newMouseInBar = currentMousePos - barAbsPos
                                local newKnobOffset = newMouseInBar - clickOffsetInKnob

                                local maxArea = usableBarWidth - knobWidthPx
                                local newPercent = math.clamp(newKnobOffset / maxArea, 0, 1)
                                
                                self.props.onPositionChange(newPercent)
                            end
                        end)

                        releaseConn = rbx.InputEnded:Connect(function(input3)
                            if input3.UserInputType == Enum.UserInputType.MouseButton1 then
                                self:setState({ dragging = false })
                                moveConn:Disconnect()
                                releaseConn:Disconnect()
                            end
                        end)
                    end
                end
            })
        })
    })
end

function Scrollbar:willUnmount()
    if self.sizeConn then self.sizeConn:Disconnect() end
    if self.posConn then self.posConn:Disconnect() end
end

return Scrollbar