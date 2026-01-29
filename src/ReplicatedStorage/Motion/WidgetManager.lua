local Roact = require(script.Parent.MotionSequencer.Roact)

local WidgetManager = {}
WidgetManager.__index = WidgetManager

local WidgetConfigs = {
    Timeline = {
        Id = "Motion_Timeline",
        Title = "Motion Editor",
        Info = DockWidgetPluginGuiInfo.new(
            Enum.InitialDockState.Bottom,
            false, false,
            800, 300,
            400, 150
        ),
    },
    Settings = {
        Id = "Motion_ProjectConfiguration",
        Title = "Motion - Project Configuration",
        Info = DockWidgetPluginGuiInfo.new(
            Enum.InitialDockState.Float,
            false, false,
            300, 400,
            250, 300
        ),
    },
    PropertyPicker = {
        Id = "Motion_ProjectPicker",
        Title = "Motion - Property Picker",
        Info = DockWidgetPluginGuiInfo.new(
            Enum.InitialDockState.Float,
            false, false,
            300, 400,
            250, 300
        ),
    },
    Export = {
        Id = "Motion_ExportProject",
        Title = "Motion - Export Project",
        Info = DockWidgetPluginGuiInfo.new(
            Enum.InitialDockState.Float,
            false, false,
            300, 400,
            250, 300
        ),
    },
    Inspector = {
        Id = "Motion_Inspector",
        Title = "Motion - Selection Properties",
        Info = DockWidgetPluginGuiInfo.new(
            Enum.InitialDockState.Float,
            false, false,
            300, 400,
            250, 300
        ),
    }
}

function WidgetManager.new(plugin)
    local self = setmetatable({}, WidgetManager)

    self.plugin = plugin
    self.widgets = {}
    self.handles = {}
    self.syncSignal = Instance.new("BindableEvent")

    self.sharedState = {
        activeProject = {
            name = "Untitled",
            fps = 60,
            duration = 5,
        },
        currentTime = 0,
        isPlaying = false,

        tracks = {},

        selection = {
            clips = {},
            keyframes = {},
            tracks = {},
        },

        cameraPreviewActive = false,
        viewSettings = {
            showGrid = false,
            showLetterbox = false,
        },
    }

    for name, config in pairs(WidgetConfigs) do
        local widget = plugin:CreateDockWidgetPluginGui(config.Id, config.Info)
        widget.Title = config.Title
        widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        widget.Name = name
        self.widgets[name] = widget
    end

    return self
end

function WidgetManager:updateSharedState(updates)
    for key, value in pairs(updates) do
        if key == "viewSettings" and type(value) == "table" then
            self.sharedState.viewSettings = self.sharedState.viewSettings or {}
            for setting, val in pairs(value) do
                self.sharedState.viewSettings[setting] = val
            end
        elseif key == "activeProject" and type(value) == "table" then
            self.sharedState.activeProject = self.sharedState.activeProject or {}
            for k, v in pairs(value) do
                self.sharedState.activeProject[k] = v
            end
        elseif key == "selection" and type(value) == "table" then
            self.sharedState.selection = self.sharedState.selection or {}
            for k, v in pairs(value) do
                self.sharedState.selection[k] = v
            end
        else
            self.sharedState[key] = value
        end
    end

    self.syncSignal:Fire(updates)
end

function WidgetManager:mountWidget(widgetName, component, props)
    local widget = self.widgets[widgetName]
    if not widget then
        warn("Widget not found:", widgetName)
        return
    end

    if self.handles[widgetName] then
        warn("Widget already mounted:", widgetName)
        return
    end

    local mergedProps = props or {}
    mergedProps.SyncSignal = self.syncSignal
    mergedProps.Plugin = self.plugin
    mergedProps.SharedState = self.sharedState

    mergedProps.UpdateSharedState = function(updates)
        self:updateSharedState(updates)
    end

    self.handles[widgetName] = Roact.mount(
        Roact.createElement(component, mergedProps),
        widget
    )
end

function WidgetManager:unmountWidget(widgetName)
    local handle = self.handles[widgetName]
    if handle then
        Roact.unmount(handle)
        self.handles[widgetName] = nil
    end
end

function WidgetManager:toggleWidget(widgetName)
    local widget = self.widgets[widgetName]
    if widget then
        widget.Enabled = not widget.Enabled
    end
end

function WidgetManager:unmountAll()
    for name, _ in pairs(self.handles) do
        self:unmountWidget(name)
    end
end

function WidgetManager:destroy()
    self:unmountAll()

    if self.syncSignal then
        self.syncSignal:Destroy()
        self.syncSignal = nil
    end

    for _, widget in pairs(self.widgets) do
        if widget then
            widget:Destroy()
        end
    end

    self.widgets = {}
    self.handles = {}
end

return WidgetManager