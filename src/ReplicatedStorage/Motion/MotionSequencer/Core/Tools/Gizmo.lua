local Error = require(script.Parent.Parent.Parent.Editor.Controllers.ErrorController)

local GizmoSystem = {}
GizmoSystem.__index = GizmoSystem

local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local adornmentToInstance = {}

local ACTIVE_COLOR = Color3.fromRGB(255, 255, 255)
local SNAP_INCREMENT = 1
local ROT_SNAP = 15
local INTERPOLATION_SPEED = 0.25 
local ROT_SENSITIVITY = 0.5
local ROT_MODEL_OFFSET = 4 

local AXIS_COLORS = {
    X = Color3.fromRGB(255, 50, 50),
    Y = Color3.fromRGB(50, 255, 50),
    Z = Color3.fromRGB(50, 150, 255)
}

local function getPlaneIntersection(planeNormal, planePoint, ray)
    local d = planeNormal:Dot(ray.Direction)
    if math.abs(d) < 1e-6 then return nil end
    local t = (planeNormal:Dot(planePoint - ray.Origin)) / d
    return if t < 0 then nil else ray.Origin + ray.Direction * t
end

local function findJoint(part)
    if not part or not part.Parent then return nil end
    for _, obj in ipairs(part.Parent:GetChildren()) do
        if obj:IsA("Motor6D") and obj.Part1 == part then
            return obj
        end
    end
    for _, obj in ipairs(part:GetChildren()) do
        if obj:IsA("Motor6D") and obj.Part1 == part then
            return obj
        end
    end
    return nil
end

function GizmoSystem.new(plugin, target, isInternalUpdate, onTransformEnd)
    local self = setmetatable({}, GizmoSystem)

    self.plugin = plugin
    self.target = target
    self.targetJoint = nil
    self.mouse = plugin:GetMouse()
    self.mode = "Move"

    self.isDragging = false
    self.hoveredPart = nil
    self.activeCage = nil
    self.currentAxisPart = nil

    self.locks = isInternalUpdate
    self.debug = false
    
    self.onTransformEnd = onTransformEnd
    
    self.visualizersContainer = workspace.Camera:FindFirstChild("Visualizers")
    self.gizmosContainer = self.visualizersContainer

    if not self.gizmosContainer then
        Error.report(Error.new(
            "404",
            "TransformGizmos missing",
            "Motion.Core.Gizmos"
            ))
    end

    self.moveModel = Instance.new("Model", self.gizmosContainer)
    self.moveModel.Name = "MoveGizmos"
    self.moveHandles = {} 

    self.rotModel = script.Parent.Parent.Parent.Editor.Assets.World.RX:Clone()
    self.rotModel.Name = "RotateGizmos"
    self.rotModel.Parent = self.gizmosContainer
    self.rotHandles = {} 

    self:initMoveGizmos()
    self:initRotateGizmos()
    self:setupInput()

    self.updateLoop = RunService.RenderStepped:Connect(function()
        if self.target then 
            self:refresh()
            self.moveModel.Parent = (self.mode == "Move") and self.gizmosContainer or nil
            self.rotModel.Parent = (self.mode == "Rotate") and self.gizmosContainer or nil
        else
            self.moveModel.Parent = nil
            self.rotModel.Parent = nil
        end
    end)

    return self
end

function GizmoSystem:initMoveGizmos()
    local axes = {
        { "X_POS", Vector3.xAxis,  AXIS_COLORS.X },
        { "X_NEG", -Vector3.xAxis, Color3.fromRGB(180, 40, 40) },
        { "Y_POS", Vector3.yAxis,  AXIS_COLORS.Y },
        { "Y_NEG", -Vector3.yAxis, Color3.fromRGB(40, 180, 40) },
        { "Z_POS", Vector3.zAxis,  AXIS_COLORS.Z },
        { "Z_NEG", -Vector3.zAxis, Color3.fromRGB(40, 100, 180) }
    }

    for _, data in ipairs(axes) do
        local p = Instance.new("Part")
        p.Name = data[1] .. "_Move"
        p.Transparency = 1
        p.Anchored = true
        p.CanCollide = false
        p.Parent = self.moveModel

        local shaft = Instance.new("BoxHandleAdornment", p)
        shaft.Name = "Shaft"
        shaft.AlwaysOnTop = true
        shaft.Color3 = data[3]
        shaft.Adornee = p
        shaft.ZIndex = 5

        local head = Instance.new("ConeHandleAdornment", p)
        head.Name = "Head"
        head.AlwaysOnTop = true
        head.Color3 = data[3]
        head.Adornee = p
        head.ZIndex = 10

        p:SetAttribute("BaseColor", data[3])
        self.moveHandles[p] = data[2]
    end
end

function GizmoSystem:initRotateGizmos()
    local axisMap = { X = Vector3.xAxis, Y = Vector3.yAxis, Z = Vector3.zAxis }
    local pointsFolder = self.rotModel:FindFirstChild("Points") or self.rotModel

    for _, child in ipairs(pointsFolder:GetDescendants()) do
        if child:IsA("BasePart") then
            local axisChar = string.sub(child.Name, 1, 1) 
            local axisVector = axisMap[axisChar]
            local axisColor = AXIS_COLORS[axisChar]

            if axisVector and axisColor then
                self.rotHandles[child] = axisVector
                child:SetAttribute("BaseColor", axisColor)

                local glow = Instance.new("SphereHandleAdornment", child)
                glow.Name = "Selection"
                glow.Adornee = child
                glow.Radius = child.Size.X * 0.75
                glow.AlwaysOnTop = true
                glow.Color3 = axisColor 
                glow.Transparency = 0.5
                glow.ZIndex = 15
            end
        end
    end
end

function GizmoSystem:refresh()
    if not self.target then return end

    local pivot
    if self.target:IsA("Motor6D") then
        pivot = self.target.Part1 and self.target.Part1.Position or Vector3.zero
    else
        pivot = self.target.Position
    end

    local cam = workspace.CurrentCamera
    local dist = (cam.CFrame.Position - pivot).Magnitude
    local scale = math.clamp(dist / 30, 0.4, 5)

    self.mouse.TargetFilter = self.target:IsA("Motor6D") and self.target.Part1 or self.target

    if self.mode == "Move" then
        for part, direction in pairs(self.moveHandles) do
            local isHot = (self.hoveredPart == part or (self.isDragging and self.currentAxisPart == part))
            local baseColor = part:GetAttribute("BaseColor")

            local length = (isHot and 4.5 or 4) * scale
            part.CFrame = CFrame.new(pivot + (direction * length), pivot + (direction * (length + 1)))
            part.Size = Vector3.one * scale

            local head, shaft = part.Head, part.Shaft
            head.Height = (isHot and 2.5 or 2) * scale
            head.Radius = (isHot and 0.6 or 0.45) * scale

            local sLen = length - 0.5
            shaft.Size = Vector3.new(0.12 * scale, 0.12 * scale, sLen)
            shaft.CFrame = CFrame.new(0, 0, sLen / 2)

            local targetColor = isHot and ACTIVE_COLOR or baseColor
            head.Color3 = head.Color3:Lerp(targetColor, INTERPOLATION_SPEED)
            shaft.Color3 = shaft.Color3:Lerp(targetColor, INTERPOLATION_SPEED)
            head.Transparency = isHot and 0 or 0.2
            shaft.Transparency = head.Transparency
        end
    elseif self.mode == "Rotate" then
        local targetCF = self.target:IsA("Motor6D") and self.target.Part1.CFrame or self.target.CFrame
        self.rotModel:PivotTo(targetCF)
        self.rotModel:ScaleTo(scale * ROT_MODEL_OFFSET)

        for part, _ in pairs(self.rotHandles) do
            local isHot = (self.hoveredPart == part or (self.isDragging and self.currentAxisPart == part))
            local glow = part:FindFirstChild("Selection")
            local baseColor = part:GetAttribute("BaseColor") or ACTIVE_COLOR

            if glow then
                local targetColor = isHot and ACTIVE_COLOR or baseColor
                local targetTrans = isHot and 0 or 0.5

                glow.Color3 = glow.Color3:Lerp(targetColor, INTERPOLATION_SPEED)
                glow.Transparency = glow.Transparency + (targetTrans - glow.Transparency) * INTERPOLATION_SPEED
            end
        end
    end
end

function GizmoSystem:SetTarget(newTarget)
    if self.target == newTarget then return end

    self.target = newTarget

    if newTarget and newTarget:IsA("Motor6D") then
        self.targetJoint = newTarget
    else
        self.targetJoint = findJoint(newTarget)
    end

    if self.activeCage then self.activeCage:Destroy() end
    if self.debug then
        print("Gizmo Target Switched to: " .. (newTarget and newTarget.Name or "None"))
        if self.targetJoint then
            print("  Targeting Motor6D: " .. self.targetJoint.Name)
        end
    end
end

function GizmoSystem:setupInput()
    local function refreshAdornmentMap()
        adornmentToInstance = {}
        local visualizers = workspace.Camera:FindFirstChild("Visualizers")
        if visualizers then
            for _, folder in visualizers:GetChildren() do
                if folder.Name == "JointNodes" or folder.Name == "SingleNodes" then
                    for _, adornment in folder:GetChildren() do
                        if adornment:IsA("SphereHandleAdornment") and adornment.Adornee then
                            if folder.Name == "JointNodes" then
                                local targetPart = adornment.Adornee
                                local torso = targetPart.Parent:FindFirstChild("Torso")
                                if torso then
                                    for _, motor in torso:GetChildren() do
                                        if motor:IsA("Motor6D") and motor.Part1 == targetPart then
                                            adornmentToInstance[adornment] = motor
                                            break
                                        end
                                    end
                                end
                            else
                                adornmentToInstance[adornment] = adornment.Adornee
                            end
                        end
                    end
                end
            end
        end
    end

    local function getAdornmentUnderMouse()
        local ray = workspace.CurrentCamera:ViewportPointToRay(self.mouse.X, self.mouse.Y)
        refreshAdornmentMap()

        for adornment, targetInstance in adornmentToInstance do
            if adornment.Adornee then
                local pos = adornment.Adornee.Position
                local distance = ray:Distance(pos)
                if distance < (adornment.Radius * 1.5) then
                    return adornment, targetInstance
                end
            end
        end

        return nil, nil
    end

    UIS.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.R then
            self.mode = (self.mode == "Move") and "Rotate" or "Move"
        end
    end)

    RunService.Heartbeat:Connect(function()
        if self.locks.isInternalUpdate or self.isDragging then 
            if self.lastHoveredNode then
                local isMotor = self.lastHoveredNode.Parent and self.lastHoveredNode.Parent.Name == "JointNodes"
                self.lastHoveredNode.Color3 = isMotor and Color3.fromRGB(255, 100, 255) or Color3.fromRGB(255, 170, 0)
                self.lastHoveredNode = nil
                self.hoveredPart = nil
            end
            return 
        end

        if self.lastHoveredNode and self.lastHoveredNode:IsA("SphereHandleAdornment") then
            local isMotor = self.lastHoveredNode.Parent and self.lastHoveredNode.Parent.Name == "JointNodes"
            self.lastHoveredNode.Color3 = isMotor and Color3.fromRGB(255, 100, 255) or Color3.fromRGB(255, 170, 0)
            self.lastHoveredNode = nil
        end

        local hitPart = self.mouse.Target
        local adornment, targetInstance = getAdornmentUnderMouse()

        if adornment then
            self.hoveredPart = adornment
            adornment.Color3 = Color3.fromRGB(255, 255, 255)
            self.lastHoveredNode = adornment
        else
            local isGizmo = (self.mode == "Move" and self.moveHandles[hitPart]) or 
                (self.mode == "Rotate" and self.rotHandles[hitPart])
            self.hoveredPart = isGizmo and hitPart or nil
        end
    end)

    self.mouse.Button1Down:Connect(function()
        local adornment, targetInstance = getAdornmentUnderMouse()

        if adornment and targetInstance then
            if self.debug then 
                print("[GIZMO] Clicked node - Target:", targetInstance.Name, targetInstance.ClassName)
            end
            self:SetTarget(targetInstance)
            return
        end

        if self.hoveredPart then 
            self.currentAxisPart = self.hoveredPart

            if self.mode == "Move" and self.moveHandles[self.hoveredPart] then
                self:beginMove(self.moveHandles[self.hoveredPart])
            elseif self.mode == "Rotate" and self.rotHandles[self.hoveredPart] then
                self:beginRotate(self.rotHandles[self.hoveredPart])
            end
            return
        end

        local hitPart = self.mouse.Target
        if hitPart == nil or (self.target and not self.target:IsA("Motor6D") and hitPart ~= self.target) then
            if self.debug then print("Clicked away - Deselecting") end
            self:SetTarget(nil)
        end
    end)
end

function GizmoSystem:createSelectionCage()
    local cage = Instance.new("SelectionBox")
    cage.Name = "TransformCage"
    cage.Adornee = self.target:IsA("Motor6D") and self.target.Part1 or self.target
    cage.LineThickness = 0.02
    cage.Color3 = ACTIVE_COLOR
    cage.SurfaceColor3 = ACTIVE_COLOR
    cage.SurfaceTransparency = 0.95
    cage.Parent = self.gizmosContainer
    self.activeCage = cage
end

function GizmoSystem:beginMove(axis)
    if self.target:IsA("Motor6D") then
        warn("Motor6Ds should be animated in Rotate mode only")
        return
    end

    self.isDragging = true
    self.plugin:Activate(true)
    self:createSelectionCage()

    local cam = workspace.CurrentCamera
    local startPos = self.target.Position
    local planeNormal = cam.CFrame.LookVector:Cross(axis):Cross(axis).Unit
    if planeNormal.Magnitude < 0.1 then planeNormal = cam.CFrame.LookVector:Cross(Vector3.yAxis):Cross(axis).Unit end

    local startRay = cam:ViewportPointToRay(self.mouse.X, self.mouse.Y)
    local startHit = getPlaneIntersection(planeNormal, startPos, startRay)
    if not startHit then self.isDragging = false return end

    local initialOffset = (startHit - startPos):Dot(axis)

    local moveConn
    moveConn = RunService.RenderStepped:Connect(function()
        local curRay = cam:ViewportPointToRay(self.mouse.X, self.mouse.Y)
        local curHit = getPlaneIntersection(planeNormal, startPos, curRay)

        if curHit then
            local curOffset = (curHit - startPos):Dot(axis)
            local delta = curOffset - initialOffset
            local newPos = startPos + (axis * delta)

            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
                newPos = Vector3.new(
                    math.round(newPos.X / SNAP_INCREMENT) * SNAP_INCREMENT,
                    math.round(newPos.Y / SNAP_INCREMENT) * SNAP_INCREMENT,
                    math.round(newPos.Z / SNAP_INCREMENT) * SNAP_INCREMENT
                )
            end
            local currentRotation = self.target:GetPivot().Rotation
            self.target:PivotTo(CFrame.new(newPos) * currentRotation)
        end
    end)

    local stop
    stop = UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            moveConn:Disconnect()
            stop:Disconnect()
            if self.activeCage then self.activeCage:Destroy() end
            self.isDragging = false
            self.currentAxisPart = nil
        end
    end)
end

function GizmoSystem:beginRotate(localAxis)
    self.isDragging = true
    self.plugin:Activate(true)
    self:createSelectionCage()

    local joint = self.targetJoint or (not self.target:IsA("Motor6D") and findJoint(self.target))
    local startC0 = joint and joint.C0 or nil
    local pivotPos = joint and joint.Part1.Position or self.target.Position
    local cam = workspace.CurrentCamera

    local planeNormal = localAxis

    local function getMouseAngle()
        local ray = cam:ViewportPointToRay(self.mouse.X, self.mouse.Y)
        local hitPoint = getPlaneIntersection(planeNormal, pivotPos, ray)
        if not hitPoint then return nil end

        local diff = (hitPoint - pivotPos).Unit
        local right = cam.CFrame.RightVector
        local up = planeNormal:Cross(right).Unit
        local x = diff:Dot(right)
        local y = diff:Dot(up)

        return math.atan2(y, x)
    end

    local startAngle = getMouseAngle() or 0
    local lastAngle = startAngle

    local rotConn
    rotConn = RunService.RenderStepped:Connect(function()
        local currentAngle = getMouseAngle()
        if not currentAngle then return end

        local deltaAngle = currentAngle - lastAngle
        if deltaAngle > math.pi then deltaAngle -= math.pi * 2
        elseif deltaAngle < -math.pi then deltaAngle += math.pi * 2 end

        local totalAngleFromStart = currentAngle - startAngle

        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
            totalAngleFromStart = math.rad(math.round(math.deg(totalAngleFromStart) / ROT_SNAP) * ROT_SNAP)
        end

        if joint then
            local localRotAxis = joint.Part0.CFrame:VectorToObjectSpace(localAxis)
            joint.C0 = startC0 * CFrame.fromAxisAngle(localRotAxis, totalAngleFromStart)
        else
            local rotation = CFrame.fromAxisAngle(localAxis, totalAngleFromStart)
            self.target:PivotTo(self.target:GetPivot() * rotation)
        end
    end)

    local changedChannels = {}
    
    if localAxis == Vector3.xAxis or localAxis == -Vector3.xAxis then
        changedChannels.RX = true
    elseif localAxis == Vector3.yAxis or localAxis == -Vector3.yAxis then
        changedChannels.RY = true
    elseif localAxis == Vector3.zAxis or localAxis == -Vector3.zAxis then
        changedChannels.RZ = true
    end
    
    local stop
    stop = UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if self.activeCage then self.activeCage:Destroy() end
            self.isDragging = false
            if self.onTransformEnd then
                local propertyName = "C0"
                local targetInstance = joint or self.target

                self.onTransformEnd(targetInstance, propertyName, changedChannels)
            end
            
            rotConn:Disconnect()
            stop:Disconnect()
        end
    end)
end

function GizmoSystem:destroy()
    if self.updateLoop then 
        self.updateLoop:Disconnect() 
    end
    
    for _, v in pairs(self.gizmosContainer:GetChildren()) do
        v:Destroy()
    end
    for _, v in pairs(self.visualizersContainer:GetDescendants()) do
        if v:IsA("SphereHandleAdornment") then
            v:Destroy()
        end
    end
    
    for _, mobj in game.Workspace.Camera:GetChildren() do
        if mobj.Name == "Visualizers" then
            mobj:Destroy()
        end
    end
    
    adornmentToInstance = {}
end

return GizmoSystem