local Roact = require(script.Parent.Parent.Parent.Parent.Roact)
local StartScreen = Roact.Component:extend("StartScreen")

local theme = require(script.Parent.Parent.Parent.Themes.Theme)

local function formatTimestamp(timestamp)
    if not timestamp then return "NEVER_SAVED" end

    -- Format: 02 JAN 2026
    local dateTable = os.date("!*t", timestamp) -- Using UTC for consistency
    local months = {"JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"}

    return string.format("%02d %s %d", dateTable.day, months[dateTable.month], dateTable.year)
end

local function techText(str)
    local upper = string.upper(str)
    local tracked = ""
    for i = 1, #upper do
        tracked = tracked .. string.sub(upper, i, i) .. " "
    end
    return tracked
end

function StartScreen:init()
    self:setState({
        hoveredButton = nil,
        selectedTab = "new",
        projectName = "",
        fps = "60",
        duration = "5",
    })
end

function StartScreen:render()
    local props = self.props
    local state = self.state

    return Roact.createElement("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = theme.MainBG,
        BorderSizePixel = 0,
    }, {
        -- Top Bar
        TopBar = Roact.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundColor3 = theme.PanelBG,
            BorderSizePixel = 0,
        }, {
            Separator = Roact.createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 1),
                Position = UDim2.new(0, 0, 1, -1),
                BackgroundColor3 = theme.Separator,
                BorderSizePixel = 0,
            }),

            Logo = Roact.createElement("TextLabel", {
                Size = UDim2.new(0, 200, 1, 0),
                Position = UDim2.fromOffset(12, 0),
                BackgroundTransparency = 1,
                Text = "Motion Sequencer",
                Font = Enum.Font.GothamMedium,
                TextSize = 14,
                TextColor3 = theme.TextAccent,
                TextXAlignment = Enum.TextXAlignment.Left,
            }),

            Version = Roact.createElement("TextLabel", {
                Size = UDim2.new(0, 100, 1, 0),
                Position = UDim2.new(1, -110, 0, 0),
                BackgroundTransparency = 1,
                Text = "1.0.0",
                Font = Enum.Font.SourceSansItalic,
                TextSize = 14,
                TextColor3 = theme.TextMuted,
                TextXAlignment = Enum.TextXAlignment.Right,
            })
        }),

        -- Main Layout
        Container = Roact.createElement("Frame", {
            Size = UDim2.new(1, 0, 1, -32),
            Position = UDim2.fromOffset(0, 32),
            BackgroundTransparency = 1,
        }, {
            Layout = Roact.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),

            Sidebar = Roact.createElement("Frame", {
                Size = UDim2.new(0, 220, 1, 0),
                BackgroundColor3 = theme.PanelBG,
                BorderSizePixel = 0,
                LayoutOrder = 1,
            }, {
                RightBorder = Roact.createElement("Frame", {
                    Size = UDim2.new(0, 1, 1, 0),
                    Position = UDim2.new(1, -1, 0, 0),
                    BackgroundColor3 = theme.BorderDark,
                    BorderSizePixel = 0,
                }),

                Content = Roact.createElement("Frame", {
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                }, {
                    Padding = Roact.createElement("UIPadding", {
                        PaddingTop = UDim.new(0, 20),
                        PaddingLeft = UDim.new(0, 12),
                        PaddingRight = UDim.new(0, 12),
                    }),

                    Layout = Roact.createElement("UIListLayout", {
                        Padding = UDim.new(0, 2),
                        SortOrder = Enum.SortOrder.LayoutOrder,
                    }),

                    NewTab = self:createTab("New", "new", state.selectedTab == "new", 1),
                    RecentTab = self:createTab("Recent", "recent", state.selectedTab == "recent", 2),
                })
            }),

            MainArea = Roact.createElement("Frame", {
                Size = UDim2.new(1, -220, 1, 0),
                Position = UDim2.fromOffset(220, 0),
                BackgroundColor3 = theme.MainBG,
                BorderSizePixel = 0,
                LayoutOrder = 2,
            }, {
                -- Content based on selected tab
                Content = state.selectedTab == "new" and self:renderNewSequencePanel() 
                    or state.selectedTab == "recent" and self:renderRecentPanel()
                    or self:renderOpenPanel()
            })
        })
    })
end

function StartScreen:createTab(text, id, isSelected, order)
    return Roact.createElement("TextButton", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = isSelected and theme.ItemSelected or Color3.new(0, 0, 0),
        BackgroundTransparency = isSelected and 0 or 1,
        Text = text,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = isSelected and theme.TextMain or theme.TextDim,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
        LayoutOrder = order,
        [Roact.Event.Activated] = function()
            self:setState({ selectedTab = id })
        end,
    }, {
        Padding = Roact.createElement("UIPadding", {
            PaddingLeft = UDim.new(0, 10),
        }),
        Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 3) }),
        Indicator = isSelected and Roact.createElement("Frame", {
            Size = UDim2.new(0, 2, 1, 0),
            Position = UDim2.fromOffset(0, 0),
            BackgroundColor3 = theme.Accent,
            BorderSizePixel = 0,
        })
    })
end

function StartScreen:renderNewSequencePanel()
    local props = self.props
    local state = self.state

    return Roact.createElement("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 6,
        CanvasSize = UDim2.new(0, 0, 0, 500),
    }, {
        Center = Roact.createElement("Frame", {
            Size = UDim2.new(1, -60, 0, 450),
            Position = UDim2.new(0.5, 0, 0, 30),
            AnchorPoint = Vector2.new(0.5, 0),
            BackgroundTransparency = 1,
        }, {
            SizeConstraint = Roact.createElement("UISizeConstraint", {
                MaxSize = Vector2.new(600, math.huge),
            }),
            Layout = Roact.createElement("UIListLayout", {
                Padding = UDim.new(0, 20),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),

            -- Header
            Header = Roact.createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 60),
                BackgroundTransparency = 1,
                LayoutOrder = 1,
            }, {
                Title = Roact.createElement("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 30),
                    BackgroundTransparency = 1,
                    Text = "New Sequence",
                    Font = Enum.Font.SourceSansBold,
                    TextSize = 24,
                    TextColor3 = theme.TextMain,
                    TextXAlignment = Enum.TextXAlignment.Left,
                }),

                Subtitle = Roact.createElement("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 20),
                    Position = UDim2.fromOffset(0, 35),
                    BackgroundTransparency = 1,
                    Text = "Create a new motion sequence project",
                    Font = Enum.Font.SourceSans,
                    TextSize = 13,
                    TextColor3 = theme.TextDim,
                    TextXAlignment = Enum.TextXAlignment.Left,
                })
            }),

            -- Form Panel
            FormPanel = Roact.createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 310),
                BackgroundColor3 = theme.PanelBG,
                BorderSizePixel = 0,
                LayoutOrder = 2,
            }, {
                Stroke = Roact.createElement("UIStroke", {
                    Color = theme.Separator,
                    Thickness = 1,
                }),
                Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),

                Padding = Roact.createElement("UIPadding", {
                    PaddingTop = UDim.new(0, 20),
                    PaddingLeft = UDim.new(0, 20),
                    PaddingRight = UDim.new(0, 20),
                    PaddingBottom = UDim.new(0, 20),
                }),


                Fields = Roact.createElement("Frame", {
                    Size = UDim2.new(0.5, 0, 1, 0),
                    BackgroundTransparency = 1,
                }, {
                    UIList = Roact.createElement("UIListLayout", {
                        SortOrder = Enum.SortOrder.LayoutOrder,
                        Padding = UDim.new(0, 5),
                        FillDirection = Enum.FillDirection.Vertical,
                    }),
                    -- Name Field
                    NameField = Roact.createElement("Frame", {
                        Size = UDim2.new(1, 0, 0, 60),
                        BackgroundTransparency = 1,
                        LayoutOrder = 1,
                    }, {
                        Label = Roact.createElement("TextLabel", {
                            Size = UDim2.new(1, 0, 0, 18),
                            BackgroundTransparency = 1,
                            Text = "Sequence Name",
                            Font = Enum.Font.SourceSansSemibold,
                            TextSize = 12,
                            TextColor3 = theme.TextDim,
                            TextXAlignment = Enum.TextXAlignment.Left,
                        }),

                        Input = Roact.createElement("TextBox", {
                            Size = UDim2.new(1, 0, 0, 32),
                            Position = UDim2.fromOffset(0, 23),
                            BackgroundColor3 = theme.MainBG,
                            PlaceholderText = "Untitled Sequence",
                            Text = state.projectName,
                            ClearTextOnFocus = false,
                            Font = Enum.Font.SourceSansSemibold,
                            TextSize = 13,
                            TextColor3 = theme.TextMain,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            [Roact.Change.Text] = function(rbx)
                                self:setState({ projectName = rbx.Text })
                            end,
                        }, {
                            Padding = Roact.createElement("UIPadding", {
                                PaddingLeft = UDim.new(0, 10),
                            }),
                            Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 3) }),
                            Stroke = Roact.createElement("UIStroke", {
                                Color = theme.BorderDark,
                                Thickness = 1,
                            })
                        })
                    }),

                    -- FPS Field
                    FPSField = Roact.createElement("Frame", {
                        Size = UDim2.new(1, 0, 0, 60),
                        BackgroundTransparency = 1,
                        LayoutOrder = 2,
                    }, {
                        Label = Roact.createElement("TextLabel", {
                            Size = UDim2.new(1, 0, 0, 18),
                            BackgroundTransparency = 1,
                            Text = "Frame Rate (FPS)",
                            Font = Enum.Font.SourceSansSemibold,
                            TextSize = 12,
                            TextColor3 = theme.TextDim,
                            TextXAlignment = Enum.TextXAlignment.Left,
                        }),

                        Input = Roact.createElement("TextBox", {
                            Size = UDim2.new(0, 100, 0, 32),
                            Position = UDim2.fromOffset(0, 23),
                            BackgroundColor3 = theme.MainBG,
                            Text = state.fps,
                            ClearTextOnFocus = false,
                            TextColor3 = theme.TextMain,
                            Font = Enum.Font.SourceSansSemibold,
                            TextSize = 13,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            [Roact.Change.Text] = function(rbx)
                                self:setState({ fps = rbx.Text })
                            end,
                        }, {
                            Padding = Roact.createElement("UIPadding", {
                                PaddingLeft = UDim.new(0, 10),
                            }),
                            Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 3) }),
                            Stroke = Roact.createElement("UIStroke", {
                                Color = theme.BorderDark,
                                Thickness = 1,
                            })
                        })
                    }),

                    -- Duration Field
                    DurationField = Roact.createElement("Frame", {
                        Size = UDim2.new(1, 0, 0, 60),
                        BackgroundTransparency = 1,
                        LayoutOrder = 3,
                    }, {
                        Label = Roact.createElement("TextLabel", {
                            Size = UDim2.new(1, 0, 0, 18),
                            BackgroundTransparency = 1,
                            Text = "Duration (seconds)",
                            Font = Enum.Font.SourceSansSemibold,
                            TextSize = 12,
                            TextColor3 = theme.TextDim,
                            TextXAlignment = Enum.TextXAlignment.Left,
                        }),

                        Input = Roact.createElement("TextBox", {
                            Size = UDim2.new(0, 100, 0, 32),
                            Position = UDim2.fromOffset(0, 23),
                            BackgroundColor3 = theme.MainBG,
                            Text = state.duration,
                            Font = Enum.Font.SourceSansSemibold,
                            TextSize = 13,
                            ClearTextOnFocus = false,
                            TextColor3 = theme.TextMain,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            [Roact.Change.Text] = function(rbx)
                                self:setState({ duration = rbx.Text })
                            end,
                        }, {
                            Padding = Roact.createElement("UIPadding", {
                                PaddingLeft = UDim.new(0, 10),
                            }),
                            Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 3) }),
                            Stroke = Roact.createElement("UIStroke", {
                                Color = theme.BorderDark,
                                Thickness = 1,
                            })
                        })
                    }),
                }),

                Actions = Roact.createElement("Frame", {
                    Size = UDim2.new(0.5, 0, 0, 40),
                    Position = UDim2.new(0.52, 0, 0.9, 0),
                    BackgroundTransparency = 1,
                    LayoutOrder = 4,
                }, {
                    Layout = Roact.createElement("UIListLayout", {
                        FillDirection = Enum.FillDirection.Horizontal,
                        HorizontalAlignment = Enum.HorizontalAlignment.Right,
                        SortOrder = Enum.SortOrder.LayoutOrder,
                        Padding = UDim.new(0, 10),
                    }),

                    TemplatesButton = Roact.createElement("TextButton", {
                        Size = UDim2.new(0, 120, 0, 36),
                        BackgroundColor3 = theme.PanelBG,
                        Text = "Templates",
                        Font = Enum.Font.SourceSansSemibold,
                        TextSize = 13,
                        TextColor3 = theme.TextMain,
                        AutoButtonColor = false,
                        LayoutOrder = 1,
                        [Roact.Event.Activated] = function()
                            if props.OnTemplates then
                                props.OnTemplates()
                            end
                        end,
                        [Roact.Event.MouseEnter] = function(rbx)
                            rbx.BackgroundColor3 = theme.ItemSelected
                        end,
                        [Roact.Event.MouseLeave] = function(rbx)
                            rbx.BackgroundColor3 = theme.PanelBG
                        end,
                    }, {
                        Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
                        Stroke = Roact.createElement("UIStroke", {
                            Color = theme.BorderDark,
                            Thickness = 1,
                        })
                    }),

                    CreateButton = Roact.createElement("TextButton", {
                        Size = UDim2.new(0, 120, 0, 36),
                        BackgroundColor3 = theme.Accent,
                        Text = "Create",
                        Font = Enum.Font.SourceSansSemibold,
                        TextSize = 13,
                        TextColor3 = Color3.new(1, 1, 1),
                        AutoButtonColor = false,
                        LayoutOrder = 2,
                        [Roact.Event.Activated] = function()
                            if props.onCreate then
                                local name = state.projectName ~= "" and state.projectName or "Untitled Sequence"
                                local fps = tonumber(state.fps) or 60
                                local duration = tonumber(state.duration) or 5

                                props.onCreate(name, fps, duration)
                            end
                        end,
                        [Roact.Event.MouseEnter] = function(rbx)
                            rbx.BackgroundColor3 = theme.AccentHover
                        end,
                        [Roact.Event.MouseLeave] = function(rbx)
                            rbx.BackgroundColor3 = theme.Accent
                        end,
                    }, {
                        Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 4) })
                    })
                })
            })
        })
    })
end

function StartScreen:renderRecentPanel()
    local props = self.props
    local dataFolder = game.ReplicatedStorage:FindFirstChild("MotionCore") 
        and game.ReplicatedStorage.MotionCore:FindFirstChild("Sequences")

    local listChildren = {
        Layout = Roact.createElement("UIListLayout", {
            Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
    }

    if dataFolder then
        local files = {}
        for _, val in pairs(dataFolder:GetChildren()) do
            if val:IsA("StringValue") then
                table.insert(files, val)
            end
        end

        table.sort(files, function(a, b)
            local timeA = a:GetAttribute("LastSaved") or 0
            local timeB = b:GetAttribute("LastSaved") or 0
            return timeA > timeB 
        end)

        for index, sequenceValue in ipairs(files) do
            local lastSaved = sequenceValue:GetAttribute("LastSaved")
            local displayDate = formatTimestamp(lastSaved)

            local isNew = false
            if lastSaved then
                isNew = (os.time() - lastSaved) < 86400 -- 86400 seconds in a day
            end

            listChildren[sequenceValue.Name] = Roact.createElement("TextButton", {
                Size = UDim2.new(1, 0, 0, 42), -- Slimmer for higher density
                BackgroundColor3 = theme.PanelBG,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
                LayoutOrder = index,
                [Roact.Event.Activated] = function()
                    if props.onOpenProject then props.onOpenProject(sequenceValue) end
                end,
                [Roact.Event.MouseEnter] = function(rbx) rbx.BackgroundColor3 = theme.ItemSelected end,
                [Roact.Event.MouseLeave] = function(rbx) rbx.BackgroundColor3 = theme.PanelBG end,
            }, {
                Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 2) }),
                Stroke = Roact.createElement("UIStroke", { Color = theme.BorderDark, Thickness = 1 }),

                Indicator = isNew and Roact.createElement("Frame", {
                    Size = UDim2.fromOffset(4, 4),
                    Position = UDim2.new(0, 8, 0.5, -2),
                    BackgroundColor3 = Color3.fromRGB(0, 255, 150),
                    BorderSizePixel = 0,
                }, {
                    UICorner = Roact.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
                }),

                -- File Name
                FileName = Roact.createElement("TextLabel", {
                    Size = UDim2.new(0.6, 0, 1, 0),
                    Position = UDim2.fromOffset(25, 0),
                    BackgroundTransparency = 1,
                    Text = sequenceValue.Name .. ".json",
                    Font = Enum.Font.RobotoMono, -- Monospace for tech feel
                    TextSize = 13,
                    TextColor3 = theme.TextMain,
                    TextXAlignment = Enum.TextXAlignment.Left,
                }),

                -- Date (Right Aligned)
                DateLabel = Roact.createElement("TextLabel", {
                    Size = UDim2.new(0.4, -10, 1, 0),
                    Position = UDim2.new(0.6, 0, 0, 0),
                    BackgroundTransparency = 1,
                    Text = techText(displayDate),
                    Font = Enum.Font.SourceSansSemibold,
                    TextSize = 12,
                    TextColor3 = theme.TextMuted,
                    TextXAlignment = Enum.TextXAlignment.Right,
                })
            })
        end
    end

    return Roact.createElement("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
    }, {
        Padding = Roact.createElement("UIPadding", {
            PaddingTop = UDim.new(0, 25),
            PaddingLeft = UDim.new(0, 25),
            PaddingRight = UDim.new(0, 25),
        }),

        Header = Roact.createElement("TextLabel", {
            Size = UDim2.new(1, 0, 0, 20),
            BackgroundTransparency = 1,
            Text = techText("Previous Projects [Local]"),
            Font = Enum.Font.SourceSansSemibold,
            TextSize = 15,
            TextColor3 = theme.Accent,
            TextXAlignment = Enum.TextXAlignment.Left,
        }),

        ListFrame = Roact.createElement("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, -40),
            Position = UDim2.fromOffset(0, 40),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = theme.Accent,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
        }, listChildren)
    })
end

function StartScreen:renderOpenPanel()
    return Roact.createElement("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
    }, {
        Center = Roact.createElement("Frame", {
            Size = UDim2.new(0, 400, 0, 200),
            Position = UDim2.new(0.5, -200, 0.5, -100),
            BackgroundTransparency = 1,
        }, {
            Layout = Roact.createElement("UIListLayout", {
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                Padding = UDim.new(0, 20),
            }),

            Icon = Roact.createElement("TextLabel", {
                Size = UDim2.new(0, 80, 0, 80),
                BackgroundTransparency = 1,
                Text = "📁",
                TextSize = 60,
            }),

            Button = Roact.createElement("TextButton", {
                Size = UDim2.new(0, 200, 0, 42),
                BackgroundColor3 = theme.PanelBG,
                Text = "Browse Files...",
                Font = Enum.Font.SourceSansSemibold,
                TextSize = 14,
                TextColor3 = theme.TextMain,
                AutoButtonColor = false,
            }, {
                Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
                Stroke = Roact.createElement("UIStroke", {
                    Color = theme.BorderDark,
                    Thickness = 1,
                })
            })
        })
    })
end

return StartScreen