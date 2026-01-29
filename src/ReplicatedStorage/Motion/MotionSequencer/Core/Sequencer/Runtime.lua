local runtime = {}
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local EU = require(script.Parent.EngineUtils)
local RBezier = require(script.Parent.Parent.Math.RBezier)

local instanceCache = {}
local rootMotionState = {
    initialCFrame = nil,
    rootPart = nil,
    accumulatedOffset = CFrame.new(),
    lastTime = 0
}

local function findInstanceByMotionId(motionId)
    if instanceCache[motionId] then
        local inst = instanceCache[motionId]
        if inst and inst.Parent then
            return inst
        else
            instanceCache[motionId] = nil
        end
    end

    local tagged = CollectionService:GetTagged(motionId)
    if tagged and #tagged > 0 then
        instanceCache[motionId] = tagged[1]
        return tagged[1]
    end

    local found = workspace:FindFirstChild(motionId, true)
    if found then
        instanceCache[motionId] = found
        return found
    end

    return nil
end

local function findRootPart(instance)
    local model = instance:FindFirstAncestorOfClass("Model")
    if model then
        return model:FindFirstChild("HumanoidRootPart") 
            or model:FindFirstChild("Root") 
            or model:FindFirstChild("LowerTorso")
            or model.PrimaryPart
    end
    return nil
end

local function initializeRootMotion(sequence)
    if not sequence.RootMotion then
        rootMotionState.initialCFrame = nil
        rootMotionState.rootPart = nil
        rootMotionState.accumulatedOffset = CFrame.new()
        rootMotionState.lastTime = 0
        return
    end
    
    for motionId, _ in pairs(sequence.Tracks) do
        if motionId ~= "_DIRECTOR_" then
            local instance = findInstanceByMotionId(motionId)
            if instance then
                local root = findRootPart(instance)
                if root then
                    rootMotionState.rootPart = root
                    rootMotionState.initialCFrame = root.CFrame
                    rootMotionState.accumulatedOffset = CFrame.new()
                    rootMotionState.lastTime = 0
                    break
                end
            end
        end
    end
end

function runtime.update(sequence, currentTime)
    local tracks = sequence.Tracks
    if not tracks then 
        warn("Runtime: No tracks found in sequence")
        return 
    end

    if sequence.RootMotion and not rootMotionState.initialCFrame then
        initializeRootMotion(sequence)
    end

    if sequence.RootMotion and currentTime < rootMotionState.lastTime then
        rootMotionState.accumulatedOffset = CFrame.new()
    end

    local rootMotionDelta = CFrame.new()
    local hasRootMotion = false

    for motionId, properties in pairs(tracks) do
        if motionId == "_DIRECTOR_" then continue end

        local instance = findInstanceByMotionId(motionId)
        if not instance then 
            if not instanceCache["_warned_" .. motionId] then
                warn("Runtime: Instance not found for motionId:", motionId)
                instanceCache["_warned_" .. motionId] = true
            end
            continue 
        end

        for propName, propData in pairs(properties) do
            if not propData.Channels or not propData.Type then continue end

            local values = {}

            for chanName, keyframes in pairs(propData.Channels) do
                if keyframes and #keyframes > 0 then
                    values[chanName] = EU.getChannelValue(keyframes, currentTime, RBezier)
                end
            end

            if sequence.RootMotion and instance == rootMotionState.rootPart and propName == "CFrame" then
                rootMotionDelta = runtime.calculateRootMotionDelta(instance, values, propData.Type, currentTime)
                hasRootMotion = true

                EU.applyProperty(instance, propName, values, propData.Type)

            elseif instance:IsA("Motor6D") then
                EU.applyProperty(instance, propName, values, propData.Type)

            else
                EU.applyProperty(instance, propName, values, propData.Type)
            end
        end
    end

    if hasRootMotion and sequence.RootMotion and rootMotionState.rootPart then
        runtime.applyRootMotion(rootMotionDelta)
    end

    rootMotionState.lastTime = currentTime

    local director = tracks["_DIRECTOR_"]
    if director then
        runtime.updateDirector(director, currentTime)
    end
end

function runtime.calculateRootMotionDelta(rootPart, values, propType, currentTime)
    if not rootMotionState.initialCFrame then
        return CFrame.new()
    end

    local animatedCF = EU.buildCFrame(values)

    local currentCF = rootPart.CFrame
    local delta = currentCF:Inverse() * animatedCF

    local deltaPos = delta.Position
    local rootMotionOffset = Vector3.new(deltaPos.X, 0, deltaPos.Z)

    local _, deltaY, _ = delta:ToEulerAnglesYXZ()
    local rootMotionRotation = CFrame.Angles(0, deltaY, 0)

    return CFrame.new(rootMotionOffset) * rootMotionRotation
end

function runtime.applyRootMotion(delta)
    if not rootMotionState.rootPart or not rootMotionState.initialCFrame then
        return
    end

    rootMotionState.accumulatedOffset = rootMotionState.accumulatedOffset * delta

    rootMotionState.rootPart.CFrame = rootMotionState.initialCFrame * rootMotionState.accumulatedOffset
end

function runtime.updateDirector(director, currentTime)
    if director.Clips and #director.Clips > 0 then
        runtime.updateCameraClips(director.Clips, currentTime)
    end
end

function runtime.updateCameraClips(clips, currentTime)
    local camera = workspace.CurrentCamera
    local active = {}

    for _, clip in ipairs(clips) do
        if currentTime >= clip.t0 and currentTime < clip.t1 then
            table.insert(active, clip)
            if #active >= 2 then break end
        end
    end

    local finalCF, finalFOV, finalRoll = nil, 70, 0

    if #active == 1 then
        local clip = active[1]
        local camPart = findInstanceByMotionId(clip.camId)

        if camPart then
            finalCF = camPart.CFrame

            local relativeTime = currentTime - clip.t0

            if clip.properties and clip.properties.FOV then
                local fovValue = EU.getChannelValue(
                    clip.properties.FOV.keyframes, 
                    relativeTime, 
                    RBezier
                )
                finalFOV = fovValue or clip.fov or 70
            else
                finalFOV = clip.fov or 70
            end

            if clip.properties and clip.properties.Roll then
                local rollValue = EU.getChannelValue(
                    clip.properties.Roll.keyframes, 
                    relativeTime, 
                    RBezier
                )
                finalRoll = rollValue or clip.roll or 0
            else
                finalRoll = clip.roll or 0
            end
        end

    elseif #active == 2 then
        table.sort(active, function(a, b) return a.t0 < b.t0 end)
        local clipA, clipB = active[1], active[2]
        local camA = findInstanceByMotionId(clipA.camId)
        local camB = findInstanceByMotionId(clipB.camId)

        if camA and camB then
            local overlapStart = clipB.t0
            local overlapEnd = clipA.t1
            local overlapDuration = math.max(overlapEnd - overlapStart, 0.001)
            local rawAlpha = (currentTime - overlapStart) / overlapDuration
            local alpha = math.clamp(rawAlpha, 0, 1)

            alpha = TweenService:GetValue(alpha, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)

            finalCF = camA.CFrame:Lerp(camB.CFrame, alpha)

            local relativeTimeA = currentTime - clipA.t0
            local relativeTimeB = currentTime - clipB.t0

            local fovA = clipA.fov or 70
            if clipA.properties and clipA.properties.FOV then
                fovA = EU.getChannelValue(clipA.properties.FOV.keyframes, relativeTimeA, RBezier) or fovA
            end

            local fovB = clipB.fov or 70
            if clipB.properties and clipB.properties.FOV then
                fovB = EU.getChannelValue(clipB.properties.FOV.keyframes, relativeTimeB, RBezier) or fovB
            end

            finalFOV = fovA + (fovB - fovA) * alpha

            local rollA = clipA.roll or 0
            if clipA.properties and clipA.properties.Roll then
                rollA = EU.getChannelValue(clipA.properties.Roll.keyframes, relativeTimeA, RBezier) or rollA
            end

            local rollB = clipB.roll or 0
            if clipB.properties and clipB.properties.Roll then
                rollB = EU.getChannelValue(clipB.properties.Roll.keyframes, relativeTimeB, RBezier) or rollB
            end

            finalRoll = rollA + (rollB - rollA) * alpha
        end
    end

    if finalCF then
        camera.CameraType = Enum.CameraType.Scriptable

        if finalRoll ~= 0 then
            finalCF = finalCF * CFrame.Angles(0, 0, math.rad(finalRoll))
        end

        if EU.applyHandheld then
            finalCF = EU.applyHandheld(finalCF, 0.1, 1.5, currentTime)
        end

        camera.CFrame = finalCF
        camera.FieldOfView = finalFOV
    else
        if camera.CameraType ~= Enum.CameraType.Custom then
            camera.CameraType = Enum.CameraType.Custom
        end
    end
end

function runtime.clearCache()
    instanceCache = {}
    rootMotionState.initialCFrame = nil
    rootMotionState.rootPart = nil
    rootMotionState.accumulatedOffset = CFrame.new()
    rootMotionState.lastTime = 0
end

function runtime.resetRootMotion()
    rootMotionState.initialCFrame = nil
    rootMotionState.rootPart = nil
    rootMotionState.accumulatedOffset = CFrame.new()
    rootMotionState.lastTime = 0
end

return runtime