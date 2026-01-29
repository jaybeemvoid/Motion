local gen = game:GetService("HttpService")
local cs = game:GetService("CollectionService")

local maid = require(script.Parent.Parent.Parent.Parent.Util.Maid)
local DynamicProperties = require(script.Parent.Parent.DynamicProperties)

local adornmentToInstance = {}

local function getTrackDepth(trackId, tracks)
    local depth = 0
    local current = tracks[trackId]
    while current and current.parentId do
        depth = depth + 1
        current = tracks[current.parentId]
    end
    return depth
end

local function createMotor6DTransformProperty(defaultValue)
    return {
        name = "C0",
        type = "CFrame",
        defaultValue = defaultValue,
        isExpanded = true,
        channels = {
            X = { keyframes = {} },
            Y = { keyframes = {} },
            Z = { keyframes = {} },
            RX = { keyframes = {} },
            RY = { keyframes = {} },
            RZ = { keyframes = {} },
        }
    }
end

local track = {}
track.__index = track

function track.new(context)
    local self = setmetatable({}, track)
    self.context = context
    self.maid = maid.new()
    return self
end

function track:create(trackName, trackInstance, Tproperties, parentId)
    local trackId = gen:GenerateGUID(false)

    if trackInstance:IsA("Motor6D") or trackInstance:IsA("BasePart") then
        local visualizers = workspace.Camera:FindFirstChild("Visualizers")

        local folderName = trackInstance:IsA("Motor6D") and "JointNodes" or "SingleNodes"
        local targetFolder = visualizers:FindFirstChild(folderName)

        local nodeName = "MA_"..trackInstance.Name.."_"..trackId:sub(1,8)
        if not targetFolder:FindFirstChild(nodeName) then
            local selectionNode = Instance.new("SphereHandleAdornment")
            selectionNode.Name = nodeName

            if trackInstance:IsA("Motor6D") then
                if trackInstance.Part1 then
                    selectionNode.Adornee = trackInstance.Part1
                else
                    warn("Motor6D has no Part1:", trackInstance:GetFullName())
                    return trackId
                end
            else
                selectionNode.Adornee = trackInstance
            end

            selectionNode.AlwaysOnTop = true
            selectionNode.Radius = trackInstance:IsA("Motor6D") and 0.35 or 0.25
            selectionNode.Color3 = trackInstance:IsA("Motor6D") 
                and Color3.fromRGB(255, 100, 255)
                or Color3.fromRGB(255, 170, 0)
            selectionNode.Transparency = 0.4
            selectionNode.ZIndex = 10
            selectionNode.Parent = targetFolder 
            selectionNode:SetAttribute("IsMotionNode", true)
            selectionNode:SetAttribute("TrackId", trackId)

            adornmentToInstance[selectionNode] = trackInstance
        end
    end

    self.context:setState(function(prevState)
        local newTrack = {
            id = trackId,
            type = "animation",
            name = trackName,
            parentId = parentId,
            instanceType = trackInstance.ClassName,
            properties = Tproperties,
            dataOpen = false,
            propertyListOpen = false,
            instance = trackInstance,
            isExpanded = true,
            order = #prevState.trackOrder,
        }

        local nextTracks = table.clone(prevState.tracks)
        local nextOrder = table.clone(prevState.trackOrder)

        nextTracks[trackId] = newTrack
        table.insert(nextOrder, trackId)
        return { 
            tracks = nextTracks, 
            trackOrder = nextOrder 
        }
    end)

    local newTag = "MId_" .. string.gsub(gen:GenerateGUID(false), "-", "")
    if #trackInstance:GetTags() < 1 then
        cs:AddTag(trackInstance, newTag)
    end

    self.context.Actions.history:pushHistory()

    return trackId
end

function track:addProperty(trackId, propertyName)
    self.context:setState(function(prevState)
        local nextTracks = table.clone(prevState.tracks)
        local track = nextTracks[trackId]

        if not track then 
            warn("Track not found:", trackId)
            return 
        end

        local updatedTrack = DynamicProperties.addPropertyToTrack(
            track, 
            propertyName, 
            track.instance
        )

        if not updatedTrack then
            warn("Failed to add property:", propertyName)
            return
        end

        nextTracks[trackId] = updatedTrack

        return { tracks = nextTracks }
    end)

    if self.context.Actions.keyframe then
        local track = self.context.state.tracks[trackId]
        if track and track.instance then
            self.context.Actions.keyframe:setupSmartAutoKey(
                trackId, 
                track.instance, 
                propertyName
            )
        end
    end

    self.context.Actions.history:pushHistory()
end

function track:smartAdd(instance, parentId)
    if instance:IsA("Model") or instance:IsA("Folder") then
        local hasHumanoid = instance:FindFirstChildOfClass("Humanoid") ~= nil
        local modelTrackId = self:create(instance.Name, instance, {}, parentId)

        if hasHumanoid then
            local motors = {}
            for _, desc in ipairs(instance:GetDescendants()) do
                if desc:IsA("Motor6D") then
                    table.insert(motors, desc)
                end
            end

            for _, motor in ipairs(motors) do
                local transformProp = createMotor6DTransformProperty(motor.C0)
                self:create(
                    motor.Name, 
                    motor, 
                    {transformProp}, 
                    modelTrackId
                )
            end
        else
            for _, child in ipairs(instance:GetChildren()) do
                if child:IsA("BasePart") or child:IsA("Model") or child:IsA("Folder") then
                    self:smartAdd(child, modelTrackId)
                end
            end
        end

        return
    end

    if instance:IsA("Motor6D") then
        local transformProp = createMotor6DTransformProperty()
        self:create(
            instance.Name, 
            instance, 
            {transformProp}, 
            parentId
        )
        return
    end
    
    if instance:IsA("GuiObject") or instance:IsA("ScreenGui") then
        local uiTrackId = self:create(instance.Name, instance, {}, parentId)

        for _, child in ipairs(instance:GetChildren()) do
            if child:IsA("GuiObject") then
                self:smartAdd(child, uiTrackId)
            end
        end
        return
    end
    
    if instance:IsA("BasePart") then
        local trackId = self:create(instance.Name, instance, {}, parentId)

        for _, child in ipairs(instance:GetChildren()) do
            if child:IsA("BasePart") then
                self:smartAdd(child, trackId)
            end
        end
    end
end

function track:toggleExpansion(trackId, field)
    self.context:setState(function(prevState)
        local tracks = prevState.tracks
        local targetTrack = tracks[trackId]

        if not targetTrack then
            return nil
        end

        local nextTracks = table.clone(tracks)
        local nextTrack = table.clone(targetTrack)
        nextTrack[field] = not nextTrack[field]
        nextTracks[trackId] = nextTrack

        return { tracks = nextTracks }
    end)

    self.context.Actions.history:pushHistory()
end

function track:onPropertyUiChange(trackId, channel, val)
    self.context:setState(function(prevState)
        local tracks = table.clone(prevState.tracks)
        local targetTrack = tracks[trackId]

        if not targetTrack then return nil end

        for _, data in ipairs(targetTrack.properties or {}) do
            if data.name == channel then
                data.isExpanded = val
                break
            end
        end

        return { tracks = tracks }
    end)
end

function track:getAdornmentToInstanceMap()
    return adornmentToInstance
end

function track:destroy()
    self.maid:DoCleaning()
end

return track