--!strict
local ErrorHandler = require(script.Parent.Parent.Controllers.ErrorController)

return function()
    local Motion = game.ReplicatedStorage 
    if not Motion then
        ErrorHandler.report(ErrorHandler.new(404, "Replicated Storage missing", "MotionCore.Initializer"))
        return
    end

    local Files = require(script.Files)

    local function buildFolders(structure: any, parent: Instance)
        for key, value in pairs(structure) do
            local folderName = ""
            local subContent = nil

            if typeof(key) == "string" then
                folderName = key
                subContent = value
            elseif typeof(value) == "string" then
                folderName = value
            end

            if folderName ~= "" then
                local folder = parent:FindFirstChild(folderName)
                if not folder then
                    folder = Instance.new("Folder")
                    folder.Name = folderName
                    folder.Parent = parent
                end
                
                if typeof(subContent) == "table" then
                    buildFolders(subContent, folder)
                end
            end
        end
    end
    
    local newF = game.Workspace.Camera:FindFirstChild("Visualizers") or Instance.new("Folder")
    newF.Name = "Visualizers"
    newF.Parent = workspace.Camera
    
    local nw = game.Workspace.Camera.Visualizers:FindFirstChild("JointNodes") or Instance.new("Folder")
    nw.Name = "JointNodes"
    nw.Parent = newF
    
    local newa = game.Workspace.Camera.Visualizers:FindFirstChild("SingleNodes") or Instance.new("Folder")
    newa.Name = "SingleNodes"
    newa.Parent = newF

    buildFolders(Files, Motion)
end