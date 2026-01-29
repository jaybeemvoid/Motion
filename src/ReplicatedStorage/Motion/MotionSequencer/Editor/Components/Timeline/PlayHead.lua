local Roact = require(script.Parent.Parent.Parent.Parent.Roact)
local PlayHead = Roact.Component:extend("PlayHead")

local playbackControl = require(script.Parent.Parent.Parent.Controllers.PlaybackController)


local Theme = require(script.Parent.Parent.Parent.Themes.Theme)

function PlayHead:init()
    self.state = {
        hovering = false,
        dragging = false,
    }
    self.handleRef = Roact.createRef()
end

function PlayHead:render()
    local xPos = (self.props.currentTime * self.props.pixelsPerSecond) - self.props.position - 10
    local isActive = self.state.hovering or self.state.dragging

    return Roact.createElement("Frame", {
        Size = UDim2.new(0, 2, 1, 0),
        Position = UDim2.fromOffset(xPos + 10, 0),
        BackgroundColor3 = Theme.Playhead,
        BorderSizePixel = 0,
        ZIndex = 99999,
    }, {
        Handle = Roact.createElement("Frame", {
            [Roact.Ref] = self.handleRef,
            Size = UDim2.fromOffset(isActive and 12 or 10, isActive and 12 or 10),
            Position = UDim2.new(0.5, 0, 0, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Theme.Playhead,
            BorderSizePixel = 0,
            ZIndex = 51,
            Rotation = 45,
        }, {
            Corner = Roact.createElement("UICorner", {
                CornerRadius = UDim.new(0, 2),
            }),
            Stroke = Roact.createElement("UIStroke", {
                Color = Color3.fromRGB(180, 40, 40),
                Thickness = 1,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            }),
            Button = Roact.createElement("TextButton", {
                Size = UDim2.new(1.5, 0, 1.5, 0),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                Text = "",
                ZIndex = 52,
                --[[[Roact.Event.MouseEnter] = function()
                    self:setState({ hovering = true })
                end,
                [Roact.Event.MouseLeave] = function()
                    self:setState({ hovering = false })
                end,
                [Roact.Event.InputBegan] = function(rbx, input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        self.props.locks.isInternalUpdate = true
                        self:setState({ dragging = true })

                        local moveConn, releaseConn

                        moveConn = rbx.InputChanged:Connect(function(input2)
                            if input2.UserInputType == Enum.UserInputType.MouseMovement then
                                local mouseX = input2.Position.X
                                local rulerAbsolutePosX = xPos + 10
                                local PADDING_LEFT = 10

                                local timeAtMouse = ((mouseX - rulerAbsolutePosX - PADDING_LEFT) + self.props.position) / self.props.pixelsPerSecond
                                local clampedTime = math.clamp(timeAtMouse, 0, self.props.totalSeconds)
                                self.props.onStateChange("currentTime", clampedTime)
                                playbackControl:setTime(clampedTime)
                            end
                        end)

                        releaseConn = rbx.InputEnded:Connect(function(input3)
                            if input3.UserInputType == Enum.UserInputType.MouseButton1 then
                                self:setState({ dragging = false })
                                moveConn:Disconnect()
                                releaseConn:Disconnect()

                                task.defer(function()
                                    self.props.locks.isInternalUpdate = false
                                end)
                            end
                        end)
                    end
                end,--]]
            }),
        }),

        Glow = Roact.createElement("Frame", {
            Size = UDim2.new(0, isActive and 6 or 4, 1, 0),
            Position = UDim2.new(0.5, 0, 0, 0),
            AnchorPoint = Vector2.new(0.5, 0),
            BackgroundColor3 = Color3.fromRGB(255, 142, 142),
            BackgroundTransparency = isActive and 0.5 or 0.7,
            BorderSizePixel = 0,
            ZIndex = 49,
        }, {
            Gradient = Roact.createElement("UIGradient", {
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, isActive and 0.5 or 0.7),
                    NumberSequenceKeypoint.new(0.5, 0.9),
                    NumberSequenceKeypoint.new(1, 1),
                }),
                Rotation = 90,
            })
        }),

        Stroke = Roact.createElement("UIStroke", {
            Color = Color3.fromRGB(200, 123, 123),
            Thickness = 0.5,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        })
    })
end

return PlayHead