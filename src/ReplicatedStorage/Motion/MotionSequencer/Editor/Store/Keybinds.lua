return function(plugin : Plugin, event : BindableEvent)
    local Actions = {
        ["Play_Sequence"] = plugin:CreatePluginAction("Motion_PlaySeq", "Play a sequence", "Default: Space", "", true),
        ["Delete_Keyframe"] = plugin:CreatePluginAction("Motion_DeleteKeyFrame", "Delete a Keyframe", "Default: X", "", true),
        ["Create_KeyFrame"] = plugin:CreatePluginAction("Motion_CreateKeyFrame", "Creates a keyframe", "Default: I", "", true),
        ["To_Start"] = plugin:CreatePluginAction("Motion_ToStart", "Return to 0s", "Default: 0", "", true),
        ["Undo"] = plugin:CreatePluginAction("Motion_Undo", "Undo an action via history", "Default: Ctrl+Shift+Z", "", true),
        ["Redo"] = plugin:CreatePluginAction("Motion_Redo", "Redo an action via history", "Default: Ctrl+Shift+Y", "", true)
    }
    
    for _n, v in pairs(Actions) do
        v.Triggered:Connect(function()
            event:Fire(_n)
        end)
    end
    return {
        Actions = Actions
    }
end
