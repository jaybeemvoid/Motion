local Roact = require(script.Parent.Parent.Parent.Parent.Roact)
local Track = Roact.Component:extend("Track")

function Track:render()
    local trackData = self.props.trackData
    local propertiesList = trackData.properties
    
    local dataUI = {}
    local data = {}
    
    local propertyListOpen = trackData.propertyListOpen
    local dataOpen = trackData.dataOpen

    local arrowText = dataOpen and "v" or ">"
    
    local propertiesUI = {}
    
    for i, vals in ipairs(propertiesList) do
        propertiesUI[vals.name] = Roact.createElement("Frame", {
            Style = {
                s = UDim2.new(1, -6, 0, 20),
                opacity = 1,
                z = 3,
            },
            LayoutOrder = i,
        }, {
            PropertyText = Roact.createElement("TextLabel", {
                Style = {
                    text = vals.name,
                    s = UDim2.new(1, -50, 0, 20),
                    ps = UDim2.new(0, 30, 0, 0),
                    textColor = Color3.new(255, 255, 255),
                    z = 3,
                    opacity = 1,
                },

                TextXAlignment = Enum.TextXAlignment.Left,
            }),
            Marker = Roact.createElement("TextButton", {
                Style = {
                    s = UDim2.new(1, -120, 1, 0),
                    text = "+",
                    ps = UDim2.new(0, 120, 0, 0),
                    opacity = 1,
                    textColor = "white",
                    z = 3
                },
                [Roact.Event.Activated] = function()
                    --[[
                    Add Keyframes
                        Fetch data -> add keyframe
                    ]]
                    local newVal = trackData.instance[vals.name]
                    
                    self.props.createKeyFrame(trackData.id, vals.name,  self.props.currentTime, newVal)
                end,
            })
        })
    end
    
    if propertyListOpen then
        dataUI.Container = Roact.createElement("Frame", {
            AutomaticSize = Enum.AutomaticSize.Y,
            Style = {
                s = UDim2.new(1, 0, 0, 0),
                ps = UDim2.new(0, 0, 0, 20),
                opacity = 1,
                z = 3,
            }
        }, {
            UIListLayout = Roact.createElement("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            UIPadding = Roact.createElement("UIPadding", {
                PaddingLeft = UDim.new(0, 6)
            }),
            
            Properties = Roact.createFragment(propertiesUI)
        })
    end
    
    if dataOpen and #propertiesList > 0 then
        data.Data = Roact.createElement("Frame", {
            Style = {
                s = UDim2.new(1, 0, 0, 0),
                ps = UDim2.new(0, 0, 0, 20),
                opacity = 0,
                bg = "primary",
            },
            AutomaticSize = Enum.AutomaticSize.Y
        }, {
            UIPadding = Roact.createElement("UIPadding", {
                PaddingLeft = UDim.new(0, 3)
            }),
            ExpandBtn = Roact.createElement("TextButton", {
                Style = {
                    s = UDim2.new(0, 30, 0, 20),
                    sBorder = 0,
                    text = (self.state.propertyListOpen) and "v" or "<",
                    textColor = "accent",
                    textSize = 12,
                    opacity = 1,
                    z = 3,
                    hover = {
                        animate = {
                            textColor = "text-secondary",
                            duration = 0.08,
                        }
                    }
                },
                [Roact.Event.Activated] = function(btn)
                    self.props.onToggle("propertyListOpen")
                end,
            }),
            Label = Roact.createElement("TextLabel", {
                Style = {
                    s = UDim2.new(1, -30, 0, 20),
                    ps = UDim2.new(0, 30, 0, 0),
                    text = "TrackData",
                    opacity = 1,
                    textColor = Color3.fromRGB(255, 255, 255),
                    z = 3,
                },
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
            Children = Roact.createFragment(dataUI),
        })
    end
    
    return Roact.createElement("Frame", {
        Style = {
            s = UDim2.new(1, 0, 0, 0),
            bg = Color3.fromRGB(61, 61, 62),
            opacity = 0.3,
            sBorder = 0,
            z = 3,
        },
        AutomaticSize = Enum.AutomaticSize.Y
    }, {
        UIPadding = Roact.createElement("UIPadding", {
            PaddingLeft = UDim.new(0, self.props.indent),
        }),
        Label = Roact.createElement("TextLabel", {
            Style = {
                s = UDim2.new(1, -30, 0, 20),
                ps = UDim2.new(0, 30, 0, 0),
                text = trackData.name,
                opacity = 1,
                textColor = Color3.fromRGB(255, 255, 255),
                z = 3,
            },
            TextXAlignment = Enum.TextXAlignment.Left,
        }),
        ExpandBtn = Roact.createElement("TextButton", {
            Style = {
                s = UDim2.new(0, 30, 0, 20),
                sBorder = 0,
                text = ">",
                textColor = "accent",
                textSize = 12,
                opacity = 1,
                z = 3,
                hover = {
                    animate = {
                        textColor = "text-secondary",
                        duration = 0.08,
                    }
                }
            },
            [Roact.Event.Activated] = function()
                self.props.onToggle("dataOpen")
            end,
        }),
        Data = Roact.createFragment(data),
    })
end

return Track
