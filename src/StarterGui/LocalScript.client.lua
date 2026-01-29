local Motion = require(game.ReplicatedStorage.Motion.Engine)
local Data = require(game.ReplicatedStorage.MySequence)

local MySequence = Motion.new(Data)

MySequence:Play()

MySequence.Stopped:Connect(function()
    print("Completed!")
end)