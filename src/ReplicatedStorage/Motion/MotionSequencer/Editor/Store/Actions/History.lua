local history = {}
history.__index = history

local deepCopy = require(script.Parent.Parent.Parent.Parent.Util.DeepCopy)

function history.new(context)
    local self = setmetatable({}, history)

    self.context = context
    self.locked = false

    return self
end

function history:pushHistory()
    if self.locked then return end

    local state = self.context.state

    local snapshot = {
        tracks = deepCopy(state.tracks),
        trackOrder = deepCopy(state.trackOrder),
        project = deepCopy(state.project),
    }

    local newPast = {}
    for i, snap in ipairs(state.history.past) do
        newPast[i] = snap
    end
    table.insert(newPast, snapshot)

    if #newPast > state.history.maxSize then
        table.remove(newPast, 1)
    end

    self.context:setState({
        history = {
            past = newPast,
            future = {},  -- Clear future on new action
            maxSize = state.history.maxSize,
        }
    })
end

function history:undo()
    local state = self.context.state
    if #state.history.past == 0 then return end

    -- Save current state to future
    local currentSnapshot = {
        tracks = deepCopy(state.tracks),
        trackOrder = deepCopy(state.trackOrder),
        project = deepCopy(state.project),
    }

    -- Get previous state
    local previousSnapshot = state.history.past[#state.history.past]

    -- Build new past (remove last)
    local newPast = {}
    for i = 1, #state.history.past - 1 do
        newPast[i] = state.history.past[i]
    end

    -- Build new future (add current to front)
    local newFuture = {}
    for i, snap in ipairs(state.history.future) do
        newFuture[i] = snap
    end
    table.insert(newFuture, 1, currentSnapshot)

    self.context:setState({
        tracks = previousSnapshot.tracks,
        trackOrder = previousSnapshot.trackOrder,
        project = previousSnapshot.project,
        history = {
            past = newPast,
            future = newFuture,
            maxSize = state.history.maxSize,
        }
    })
end

function history:redo()
    local state = self.context.state
    if #state.history.future == 0 then 
        if self.context.debug then
            print("Nothing to redo")
        end
        return 
    end

    -- Save current state to past
    local currentSnapshot = {
        tracks = deepCopy(state.tracks),
        trackOrder = deepCopy(state.trackOrder),
        project = deepCopy(state.project),
    }

    -- Get next state from future
    local nextSnapshot = state.history.future[1]

    -- Build new past (add current)
    local newPast = {}
    for i, snap in ipairs(state.history.past) do
        newPast[i] = snap
    end
    table.insert(newPast, currentSnapshot)

    if #newPast > state.history.maxSize then
        table.remove(newPast, 1)
    end

    -- Build new future (remove first)
    local newFuture = {}
    for i = 2, #state.history.future do
        newFuture[i-1] = state.history.future[i]
    end

    self.context:setState({
        tracks = nextSnapshot.tracks,
        trackOrder = nextSnapshot.trackOrder,
        project = nextSnapshot.project,
        history = {
            past = newPast,
            future = newFuture,
            maxSize = state.history.maxSize,
        }
    })
end

function history:lock()
    self.locked = true
end

function history:unlock()
    self.locked = false
end

function history:clear()
    self.context:setState({
        history = {
            past = {},
            future = {},
            maxSize = 50,
        }
    })
end

return history