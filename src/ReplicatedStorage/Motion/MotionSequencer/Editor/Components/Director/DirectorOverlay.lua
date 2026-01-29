local Roact = require(script.Parent.Parent.Parent.Parent.Roact)

local DirectorOverlay = Roact.Component:extend("DirectorOverlay")

function DirectorOverlay:init()
    local initialState = {
        cameraActive = false,
        showGrid = false,
        showLetterbox = false,
    }
    
    if self.props.SharedState then
        initialState.cameraActive = self.props.SharedState.cameraPreviewActive or false
        if self.props.SharedState.viewSettings then
            initialState.showGrid = self.props.SharedState.viewSettings.showGrid or false
            initialState.showLetterbox = self.props.SharedState.viewSettings.showLetterbox or false
        end
    end

    self.state = initialState

    if self.props.SyncSignal then
        self.syncConn = self.props.SyncSignal.Event:Connect(function(newState)
            local updates = {}

            if newState.cameraPreviewActive ~= nil then
                updates.cameraActive = newState.cameraPreviewActive
            end

            if newState.viewSettings then
                if newState.viewSettings.showGrid ~= nil then
                    updates.showGrid = newState.viewSettings.showGrid
                end
                if newState.viewSettings.showLetterbox ~= nil then
                    updates.showLetterbox = newState.viewSettings.showLetterbox
                end
            end
        end)
    else
        warn("DirectorOverlay: SyncSignal prop is nil!")
    end
end

function DirectorOverlay:willUnmount()
    if self.syncConn then 
        self.syncConn:Disconnect()
        self.syncConn = nil
    end
end

function DirectorOverlay:render()
    local children = {}

    if self.state.showGrid then
        children.GridLines = Roact.createElement("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            ZIndex = 101,
        }, {
            Vertical1 = Roact.createElement("Frame", {
                Size = UDim2.new(0, 2, 1, 0),
                Position = UDim2.fromScale(0.333, 0),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BackgroundTransparency = 0.5,
                BorderSizePixel = 0,
            }),
            Vertical2 = Roact.createElement("Frame", {
                Size = UDim2.new(0, 2, 1, 0),
                Position = UDim2.fromScale(0.666, 0),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BackgroundTransparency = 0.5,
                BorderSizePixel = 0,
            }),
            Horizontal1 = Roact.createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 2),
                Position = UDim2.fromScale(0, 0.333),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BackgroundTransparency = 0.5,
                BorderSizePixel = 0,
            }),
            Horizontal2 = Roact.createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 2),
                Position = UDim2.fromScale(0, 0.666),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BackgroundTransparency = 0.5,
                BorderSizePixel = 0,
            }),
        })
    end

    if self.state.showLetterbox then
        children.Letterbox = Roact.createElement("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            ZIndex = 101,
        }, {
            TopBar = Roact.createElement("Frame", {
                Size = UDim2.new(1, 0, 0.1, 0),
                BackgroundColor3 = Color3.new(0, 0, 0),
                BorderSizePixel = 0,
            }),
            BottomBar = Roact.createElement("Frame", {
                Size = UDim2.new(1, 0, 0.1, 0),
                Position = UDim2.fromScale(0, 0.9),
                BackgroundColor3 = Color3.new(0, 0, 0),
                BorderSizePixel = 0,
            }),
        })
    end

    return Roact.createElement("Frame", {
        ZIndex = 100,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = true,
    }, children)
end

return DirectorOverlay