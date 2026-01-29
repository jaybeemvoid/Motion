local Engine = {}
local TweenService = game:GetService("TweenService")
local EngineUtils = require(script.Parent.EngineUtils)

function Engine.update(tracks, currentTime, cameraPreviewActive, locks)
    if locks then locks.isInternalUpdate = true end

    for _, trackData in pairs(tracks) do
        if trackData.type ~= "director" then
            local instance = trackData.instance
            if not instance or not instance.Parent then continue end

            if trackData.properties then
                for _, propData in ipairs(trackData.properties) do
                    local propName = propData.name
                    local propType = propData.type
                    local channels = propData.channels
                    if not channels then continue end

                    local values = {}
                    for chanName, chanData in pairs(channels) do
                        values[chanName] = EngineUtils.getChannelValue(
                            chanData.keyframes, 
                            currentTime
                        )
                    end
                    EngineUtils.applyProperty(instance, propName, values, propType)
                end
            end
        end
    end

    local director = tracks.director
    if director and cameraPreviewActive then
        local activeClips = {}
        for _, clip in ipairs(director.clips or {}) do
            if currentTime >= clip.startTime and currentTime < clip.endTime then
                table.insert(activeClips, clip)
                if #activeClips >= 2 then break end
            end
        end

        local camera = workspace.CurrentCamera
        local finalCF = nil
        local finalFOV = 70

        if #activeClips == 1 then
            local clip = activeClips[1]
            if clip.cameraInstance then
                finalCF = clip.cameraInstance.CFrame
                finalFOV = clip.fov or 70
            end
        elseif #activeClips == 2 then
            table.sort(activeClips, function(a, b) return a.startTime < b.startTime end)
            local clipA, clipB = activeClips[1], activeClips[2]

            if clipA.cameraInstance and clipB.cameraInstance then
                local overlapStart = clipB.startTime
                local overlapEnd = clipA.endTime
                local overlapDuration = math.max(overlapEnd - overlapStart, 0.001)

                local alpha = math.clamp((currentTime - overlapStart) / overlapDuration, 0, 1)
                alpha = TweenService:GetValue(alpha, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)

                finalCF = clipA.cameraInstance.CFrame:Lerp(clipB.cameraInstance.CFrame, alpha)
                local fovA = clipA.fov or 70
                local fovB = clipB.fov or 70
                finalFOV = fovA + (fovB - fovA) * alpha
            end
        end

        if finalCF then
            camera.CameraType = Enum.CameraType.Scriptable
            finalCF = EngineUtils.applyHandheld(finalCF, 0.1, 1.5, currentTime)
            camera.CFrame = finalCF
            camera.FieldOfView = finalFOV
        else
            if camera.CameraType ~= Enum.CameraType.Custom then
                camera.CameraType = Enum.CameraType.Custom
            end
        end
    end

    if locks then locks.isInternalUpdate = false end
end

return Engine