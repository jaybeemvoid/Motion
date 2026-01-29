local Roact = require(script.Parent.Parent.Parent.Parent.Roact)
local DynamicProperties = require(script.Parent.Parent.Parent.Store.DynamicProperties)

local PropertyPickerOverlay = Roact.Component:extend("PropertyPickerOverlay")

local Theme = require(script.Parent.Parent.Parent.Themes.Theme)

function PropertyPickerOverlay:init()
    self:setState({
        searchQuery = "",
        hoveredProperty = nil,
        tracks = self.props.SharedState.tracks or {},
    })

    if self.props.SyncSignal then
        self.syncConnection = self.props.SyncSignal.Event:Connect(function(updates)
            if updates.tracks then
                self:setState({ tracks = updates.tracks })
            end
        end)
    end
end

function PropertyPickerOverlay:render()

    local trackId = self.props.trackId
    local track = self.state.tracks and self.state.tracks[trackId] -- ✅ Use state.tracks

    if not track or not track.instance then
        return nil
    end

    local position = self.props.position or {X = 100, Y = 100}
    local availableProps = DynamicProperties.getAvailableProperties(track.instance)

    local filtered = {}
    for _, prop in ipairs(availableProps) do
        local matchesSearch = self.state.searchQuery == "" or 
            string.find(string.lower(prop.name), string.lower(self.state.searchQuery))

        local alreadyExists = DynamicProperties.hasProperty(track, prop.name)

        if matchesSearch and not alreadyExists then
            table.insert(filtered, prop)
        end
    end

    table.sort(filtered, function(a, b) return a.name < b.name end)

    local listElements = {
        UIListLayout = Roact.createElement("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 0)
        })
    }

    for i, prop in ipairs(filtered) do
        local isHovered = self.state.hoveredProperty == prop.name

        listElements["Prop_" .. i] = Roact.createElement("TextButton", {
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundColor3 = isHovered 
                and Theme.AccentHover
                or Theme.PanelBG,
            BorderSizePixel = 0,
            Text = "",
            LayoutOrder = i,
            AutoButtonColor = false,

            [Roact.Event.MouseEnter] = function()
                self:setState({ hoveredProperty = prop.name })
            end,
            [Roact.Event.MouseLeave] = function()
                self:setState({ hoveredProperty = nil })
            end,
            [Roact.Event.Activated] = function()
                if self.props.onPropertySelected then
                    self.props.onPropertySelected(prop.name)
                end
            end
        }, {
            NameLabel = Roact.createElement("TextLabel", {
                Size = UDim2.new(0.6, -12, 1, 0),
                Position = UDim2.new(0, 10, 0, 0),
                Text = prop.name,
                TextColor3 = Theme.TextMain,
                TextSize = 13,
                FontFace = Theme.FontNormal,
                TextXAlignment = Enum.TextXAlignment.Left,
                BackgroundTransparency = 1
            }),

            TypeLabel = Roact.createElement("TextLabel", {
                Size = UDim2.new(0.4, -10, 1, 0),
                Position = UDim2.new(0.6, 0, 0, 0),
                Text = prop.type,
                TextColor3 = Theme.TextAccent,
                TextSize = 11,
                FontFace = Theme.FontMono,
                TextXAlignment = Enum.TextXAlignment.Right,
                BackgroundTransparency = 1
            }),

            Divider = Roact.createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 1),
                Position = UDim2.new(0, 0, 1, -1),
                BackgroundColor3 = Theme.BorderLight,
                BorderSizePixel = 0,
            })
        })
    end

    return Roact.createElement("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.EditorBG,
        BorderSizePixel = 0,
        ZIndex = 1001,
    }, {
        UICorner = Roact.createElement("UICorner", {
            CornerRadius = UDim.new(0, 2)
        }),
        
        Padding = Roact.createElement("UIPadding", {
            PaddingTop = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 10),
            PaddingBottom = UDim.new(0, 10),
        }),

        Header = Roact.createElement("TextLabel", {
            Size = UDim2.new(1, 0, 0, 40),
            BackgroundTransparency = 1,
            Text = "Property Picker",
            TextColor3 = Theme.TextMain,
            FontFace = Theme.FontSemi,
            TextSize = 18,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 1,
        }),

        SearchBar = Roact.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 36),
            Position = UDim2.new(0, 0, 0, 40),
            BackgroundColor3 = Theme.InputBG,
            BorderSizePixel = 0,
            ZIndex = 1002
        }, {
            UICorner = Roact.createElement("UICorner", {
                CornerRadius = UDim.new(0, 3)
            }),
            
            Input = Roact.createElement("TextBox", {
                Size = UDim2.new(1, -12, 1, 0),
                Position = UDim2.new(0, 8, 0, 0),
                BackgroundTransparency = 1,
                PlaceholderText = "Search...",
                PlaceholderColor3 = Theme.TextMuted,
                Text = self.state.searchQuery,
                TextColor3 = Theme.TextDim,
                TextSize = 13,
                FontFace = Theme.FontNormal,
                TextXAlignment = Enum.TextXAlignment.Left,
                ClearTextOnFocus = false,
                ZIndex = 1003,
                [Roact.Change.Text] = function(rbx)
                    self:setState({ searchQuery = rbx.Text })
                end
            })
        }),

        ListContainer = Roact.createElement("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, -78),
            Position = UDim2.new(0, 0, 0, 76),
            BackgroundColor3 =Theme.PanelBG,
            BorderSizePixel = 0,
            ScrollBarThickness = 5,
            ScrollBarImageColor3 = Theme.ScrollThumb,
            CanvasSize = UDim2.new(0, 0, 0, #filtered * 28),
            ZIndex = 1002,
            ScrollingDirection = Enum.ScrollingDirection.Y,
        }, {
            UICorner = Roact.createElement("UICorner", {
                CornerRadius = UDim.new(0, 3)
            }),

            Content = Roact.createFragment(listElements)
        }),

        EmptyState = #filtered == 0 and Roact.createElement("Frame", {
            Size = UDim2.new(1, 0, 1, -78),
            Position = UDim2.new(0, 0, 0, 76),
            BackgroundColor3 = Theme.PanelBG,
            BorderSizePixel = 1,
            BorderColor3 = Color3.fromRGB(50, 50, 54),
            ZIndex = 1002
        }, {
            UICorner = Roact.createElement("UICorner", {
                CornerRadius = UDim.new(0, 3)
            }),

            Message = Roact.createElement("TextLabel", {
                Size = UDim2.new(1, -16, 1, 0),
                Position = UDim2.new(0, 8, 0, 0),
                Text = self.state.searchQuery == "" 
                    and "No properties available" 
                    or "No matching properties",
                TextColor3 = Theme.TextDim,
                TextSize = 12,
                FontFace = Theme.FontNormal,
                TextWrapped = true,
                BackgroundTransparency = 1,
                ZIndex = 1003
            })
        }) or nil
    })
end

function PropertyPickerOverlay:willUnmount()
    if self.syncConnection then
        self.syncConnection:Disconnect()
        self.syncConnection = nil
    end
end

return PropertyPickerOverlay