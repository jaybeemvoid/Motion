local toolbar = plugin:CreateToolbar("Motion Sequencer")
local button = toolbar:CreateButton("Motion", "Interpolate anything over time.", "")

local Roact = require(script.MotionSequencer.Roact)
local Layout = require(script.MotionSequencer.Editor.App)
local Keybinds = require(script.MotionSequencer.Editor.Store.Keybinds)
local DirectorOverlay = require(script.MotionSequencer.Editor.Components.Director.DirectorOverlay)

local WidgetManager = require(script.WidgetManager)
local manager = WidgetManager.new(plugin)

local Bind = Instance.new("BindableEvent")
Keybinds(plugin, Bind)

local overlayHandle = nil

local callbackRegistry = {
    onPropertySelected = nil
}

local widgetControls = {
    openSettings = function(extraProps)
        manager.widgets.Settings.Enabled = true
        if not manager.handles.Settings then
            local SettingsComponent = require(script.MotionSequencer.Editor.Components.Widgets.ProjectConfiguration)
            manager:mountWidget("Settings", SettingsComponent, extraProps)
        end
    end,

    openPropertyPicker = function(params)
        local trackId = params.trackId
        local onPropertySelectedCallback = params.onPropertySelected
        
        callbackRegistry.onPropertySelected = onPropertySelectedCallback

        if manager.handles.PropertyPicker then
            manager:unmountWidget("PropertyPicker")
        end

        manager.widgets.PropertyPicker.Enabled = true

        local PropertyComponent = require(script.MotionSequencer.Editor.Components.Widgets.PropertyPicker)
        manager:mountWidget("PropertyPicker", PropertyComponent, {
            trackId = trackId,
            onClose = function()
                manager.widgets.PropertyPicker.Enabled = false
                callbackRegistry.onPropertySelected = nil
            end,
            onPropertySelected = function(propertyName)
                if callbackRegistry.onPropertySelected then
                    callbackRegistry.onPropertySelected(propertyName)
                end
                manager.widgets.PropertyPicker.Enabled = false
            end
        })
    end,
    
    openExport = function(extraProps)
        manager.widgets.Export.Enabled = true
        if not manager.handles.Export then
            local ExportComponent = require(script.MotionSequencer.Editor.Components.Widgets.ExportProject)
            manager:mountWidget("Export", ExportComponent, extraProps)
        end
    end,
    
    closeSettings = function()
        manager.widgets.Settings.Enabled = false
    end,
    
    closeExport = function()
        manager.widgets.Export.Enabled = false
    end,
    
    closePropertyPicker = function()
        manager.widgets.PropertyPicker.Enabled = false
        callbackRegistry.onPropertySelected = nil
    end,

    openInspector = function()
        -- Implementation here
    end,

    closeInspector = function()
        manager.widgets.Inspector.Enabled = false
    end,

    toggleSettings = function()
        manager:toggleWidget("Settings")
        if manager.widgets.Settings.Enabled and not manager.handles.Settings then
            local SettingsComponent = require(script.Parent.Editor.UI.Settings)
            manager:mountWidget("Settings", SettingsComponent)
        end
    end,

    togglePropertyPicker = function()
        manager:toggleWidget("PropertyPicker")
        if manager.widgets.PropertyPicker.Enabled and not manager.handles.PropertyPicker then
            local PropertyPickerComponent = require(script.Parent.Editor.UI.PropertyPicker)
            manager:mountWidget("PropertyPicker", PropertyPickerComponent)
        end
    end,

    toggleInspector = function()
        manager:toggleWidget("Inspector")
        if manager.widgets.Inspector.Enabled and not manager.handles.Inspector then
            local InspectorComponent = require(script.Parent.Editor.UI.Inspector)
            manager:mountWidget("Inspector", InspectorComponent)
        end
    end,
}

local function toggleSequencer()
    local timelineWidget = manager.widgets.Timeline
    timelineWidget.Enabled = not timelineWidget.Enabled
end

button.Click:Connect(toggleSequencer)

manager.widgets.Timeline:GetPropertyChangedSignal("Enabled"):Connect(function()
    local enabled = manager.widgets.Timeline.Enabled
    button:SetActive(enabled)

    if enabled then
        if not manager.handles.Timeline then
            manager:mountWidget("Timeline", Layout, {
                Bind = Bind,
                WidgetControls = widgetControls,
                OnProjectLoaded = function(projectData)
                    manager:updateSharedState({
                        activeProject = {
                            name = projectData.name,
                            fps = projectData.fps,
                            duration = projectData.duration,
                        },
                        tracks = projectData.tracks or {},
                    })
                end
            })
            overlayHandle = Roact.mount(
                Roact.createElement("ScreenGui", {
                    Name = "MotionSequencerOverlay",
                    ResetOnSpawn = false,
                    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
                    DisplayOrder = 999999,
                    IgnoreGuiInset = true,
                }, {
                    Overlay = Roact.createElement(DirectorOverlay, {
                        SyncSignal = manager.syncSignal,
                        SharedState = manager.sharedState,
                    })
                }), 
                game:GetService("CoreGui"), 
                "MotionSequencerOverlay"
            )
        end
    else
        if overlayHandle then
            Roact.unmount(overlayHandle)
            overlayHandle = nil
        end

        manager:unmountWidget("Timeline")
        manager:unmountWidget("Settings")
        manager:unmountWidget("Inspector")
        manager:unmountWidget("Export")
        manager:unmountWidget("PropertyPicker")
    end
end)

plugin.Unloading:Connect(function()
    if overlayHandle then
        Roact.unmount(overlayHandle)
        overlayHandle = nil
    end

    if Bind then
        Bind:Destroy()
    end

    manager:destroy()
end)