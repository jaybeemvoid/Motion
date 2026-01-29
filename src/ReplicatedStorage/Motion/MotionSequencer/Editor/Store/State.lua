--[[return {
    mode = "Timeline",
    framesPerSecond = nil,
    pixelsPerSecond = 0,
    totalSeconds = nil,
    positionX = 0,
    positionY = 0,
    currentTime = 0,
    expandedTracks = {},
    openMenus = {},
    mousePos = UDim2.fromOffset(0, 0),
    canScroll = true,
    debug = false,
    isInputHandledByUI = false,
    tracks = {},
    trackOrder = {},
    playDirection = 1,
    selection = {},
    activeProject = {
        name = nil,
        fps = nil,
        duration = nil,
        createdAt = nil,
    },
    zoomY = 1,
    vps = 20,
    isPanelOpen = false,
    panX = 0,
    panY = 0,
    history = {},
    currentIndex = 0,
    maxHistory = 50,
    clipboard = {},
}--]]

return {
    mode = "Start",
    currentTime = 0,
    isPlaying = false,
    
    director = {
        name = "Director",
        clips = {}
    },
    clipSelection = {},
}