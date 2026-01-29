return {
    -- 1. GLOBAL CANVAS & ELEVATION
    -- Uses a consistent "Cool Dark" palette (Hue 220-230)
    MainBG = Color3.fromRGB(24, 24, 28),      -- Outer frame / App background
    EditorBG = Color3.fromRGB(30, 31, 36),    -- Main workspace (Timeline/Graph)
    PanelBG = Color3.fromRGB(36, 37, 43),     -- Inspector / Sidebar panels
    TopbarBG = Color3.fromRGB(45, 46, 52),    -- Headers and Toolbars
    ModalBG = Color3.fromRGB(56, 58, 67),     -- Pop-ups and Context Menus

    -- 2. ACCENTS & STATES
    Accent = Color3.fromRGB(62, 130, 247),    -- Primary Action Blue
    AccentHover = Color3.fromRGB(90, 150, 255),
    AccentMuted = Color3.fromRGB(45, 65, 95),  -- Subtle selected state
    Playhead = Color3.fromRGB(255, 68, 68),    -- Scrubber (Vibrant Red)
    Success = Color3.fromRGB(76, 175, 80),    -- Active/Live indicators
    Warning = Color3.fromRGB(255, 171, 64),   -- Yellow for dirty tracks

    -- 3. BORDERS & DEPTH
    -- Instead of just gray, these have a tiny bit of blue to feel "premium"
    BorderDark = Color3.fromRGB(16, 16, 20),  -- Shadow/Recess
    BorderLight = Color3.fromRGB(65, 66, 76), -- Highlight/Bezel
    Separator = Color3.fromRGB(48, 49, 58),   -- Track dividers

    -- 4. TEXT HIERARCHY (Roboto/Font Faces)
    TextMain = Color3.fromRGB(235, 236, 240), -- High contrast headers
    TextDim = Color3.fromRGB(170, 172, 185),  -- Property labels
    TextMuted = Color3.fromRGB(115, 117, 130), -- Placeholders/Unit labels (fps, s)
    TextAccent = Color3.fromRGB(100, 160, 255),
    
    -- Selection Box
    SelectionBox = Color3.fromRGB(150, 230, 255),
    SelectionBoxStroke = Color3.fromRGB(120, 160, 210),

    -- Topbar Colors
    BackgroundLight = Color3.fromRGB(60, 60, 60),
    BackgroundDark = Color3.fromRGB(40, 40, 40),
    
    -- 5. TIMELINE & GRAPH SYSTEM
    RulerBG = Color3.fromRGB(38, 39, 46),     
    RulerTick = Color3.fromRGB(120, 122, 135), 
    GridMajor = Color3.fromRGB(55, 57, 68),   -- Main vertical seconds lines
    GridMinor = Color3.fromRGB(42, 43, 52),   -- Frame-by-frame lines

    -- GRAPH EDITOR SPECIALS
    GraphCurve = Color3.fromRGB(0, 255, 150), -- Bezier line color
    GraphHandle = Color3.fromRGB(255, 255, 255), -- Tangent handle dots
    GraphTangent = Color3.fromRGB(100, 100, 100), -- Tangent lines
    
    GraphEditor_X = Color3.fromRGB(255, 65, 65),
    GraphEditor_Y = Color3.fromRGB(65, 255, 65),
    GraphEditor_Z = Color3.fromRGB(65, 65, 255),
    GraphEditor_RX = Color3.fromRGB(255, 140, 0),
    GraphEditor_RY = Color3.fromRGB(255, 190, 0),
    GraphEditor_RZ = Color3.fromRGB(255, 230, 0),
    GraphEditor_R = Color3.fromRGB(255, 65, 65),
    GraphEditor_G = Color3.fromRGB(65, 255, 65),
    GraphEditor_B = Color3.fromRGB(65, 65, 255),
    
    GraphEditor_ZeroLine = Color3.fromRGB(255, 255, 255),
    
    GraphEditor_Value = Color3.fromRGB(200, 200, 200),
    
    GraphEditor_Mirrored = Color3.fromRGB(0, 255, 255),
    GraphEditor_Aligned = Color3.fromRGB(255, 170, 0),
    GraphEditor_Free = Color3.fromRGB(0, 0, 0),
    
    -- 6. INTERACTIVE ELEMENTS
    ItemHover = Color3.fromRGB(52, 54, 64),   
    ItemSelected = Color3.fromRGB(58, 78, 108), -- Desaturated blue for track selection
    KeyframeBase = Color3.fromRGB(210, 212, 220),
    KeyframeSelected = Color3.fromRGB(255, 255, 255),
    KeyframeEmpty = Color3.fromRGB(80, 82, 95), -- For "hollow" keyframes

    -- 7. CONTROLS (Scrollbars/Inputs)
    ScrollTrack = Color3.fromRGB(20, 21, 26),
    ScrollThumb = Color3.fromRGB(75, 77, 90),
    ScrollThumbHover = Color3.fromRGB(95, 97, 115),
    InputBG = Color3.fromRGB(28, 29, 34),
    
    ToggleOn = Color3.fromRGB(73, 136, 73),
    ToggleOff = Color3.fromRGB(180, 70, 68),
    
    -- 8. FONTS
    FontSemi = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold),
    FontMedium = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium),
    FontNormal = Font.new("rbxassetid://12187365364", Enum.FontWeight.Regular),
    FontMono = Font.fromEnum(Enum.Font.RobotoMono), -- VITAL for the Ruler numbers
}