--!strict

-- AFKTY theme. This is the only palette in the library.
--
-- It lives in default.luau because window.luau resolves every theme by cloning this table
-- and layering overrides on top, so `default` is the fallback any missing key lands on.
-- Keeping the brand palette here means an unset key falls back to AFKTY green rather than
-- a leftover neutral grey. `afkty` is an alias onto this file.
--
-- Sampled from the emblem (assets/source/85628806611332-1254px.png): ~48% pure black
-- ground, a lime ramp averaging hue 100.6 degrees across ~120k green pixels, near-white
-- highlights. The ramp's blue channel is at or near zero throughout, so these are
-- yellow-shifted limes, not sea-green.
--
--   glow    rgb(166, 250,  92)   lit edges, slider head, accent stroke
--   accent  rgb(144, 231,  68)   emblem highlight
--   fill    rgb(112, 190,  48)   accent body, sits under the lit rim
--   mid     rgb( 57,  87,  43)   emblem median
--   deep    rgb( 27,  42,  12)   emblem shadow
--
-- The glow reads through three things working together: accent fills sitting a step darker
-- than their strokes so every edge looks lit rather than flat, stroke gradients running
-- bright through their midpoint, and a low AccentGlow transparency so the halo carries.
local variables = require(script.Parent.Parent.utility.variables)

return {
    -- Tighter than stock, carried over from the hand-built v1 hub (8px window / 6px element).
    -- It is a large part of why that GUI read sharper.
    CornerRoundness = UDim.new(0, 8),
    ElementCornerRadius = UDim.new(0, 6),
    PillCornerRadius = UDim.new(1, 0),

    WindowColor = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(6, 10, 5)),
        ColorSequenceKeypoint.new(0.9999, Color3.fromRGB(14, 22, 11)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 30, 15)),
    }),
    ShadowColor = Color3.fromRGB(2, 6, 1),

    ElementStroke = Color3.fromRGB(32, 48, 24),
    ElementGradient = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 26, 14)),
        ColorSequenceKeypoint.new(0.9999, Color3.fromRGB(24, 34, 18)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(24, 34, 18)),
    }),
    -- Runs bright through the midpoint so element edges catch a lime highlight.
    ElementStrokeGradient = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(48, 84, 28)),
        ColorSequenceKeypoint.new(0.9999, Color3.fromRGB(112, 178, 60)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(48, 84, 28)),
    }),
    ElementStrokeHover = Color3.fromRGB(144, 231, 68),
    ElementTransparency = 0,
    ElementStrokeTransparency = 0,
    ElementStrokeHoverTransparency = 0,
    ElementTextHoverColor = Color3.fromRGB(255, 255, 255),

    TabColor = Color3.fromRGB(255, 255, 255),
    TabBackground = ColorSequence.new(Color3.fromRGB(58, 96, 32), Color3.fromRGB(22, 34, 16)),
    TabStroke = ColorSequence.new(Color3.fromRGB(128, 200, 72), Color3.fromRGB(48, 78, 30)),

    SliderBackground = Color3.fromRGB(30, 42, 22),
    SliderBackgroundHover = Color3.fromRGB(46, 64, 32),
    SliderProgress = ColorSequence.new(Color3.fromRGB(166, 250, 92), Color3.fromRGB(94, 168, 36)),
    SliderStroke = Color3.fromRGB(255, 255, 255),
    SliderHandle = Color3.fromRGB(255, 255, 255),

    -- Fill sits a step under the stroke so the rim reads lit instead of a flat block.
    AccentColor = Color3.fromRGB(112, 190, 48),
    AccentStroke = Color3.fromRGB(166, 250, 92),
    AccentGlow = 0.15, -- well under the 0.4 stock value, so the halo carries

    ActionColor = Color3.fromRGB(255, 255, 255),
    ContentColor = Color3.fromRGB(255, 255, 255),
    TitlingColor = Color3.fromRGB(226, 248, 206),
    DropdownHighlight = Color3.fromRGB(196, 248, 146),
    PlaceholderColor = Color3.fromRGB(132, 156, 118),

    StatBackground = Color3.fromRGB(13, 20, 10),

    DarkToggleOverlay = true,
    ToggleTrack = Color3.fromRGB(0, 0, 0),
    ToggleTrackTransparency = 0.85,
    ToggleKnobOff = Color3.fromRGB(196, 216, 186),
    ToggleKnobOffTransparency = 0.7,

    FieldBackground = Color3.fromRGB(255, 255, 255),
    FieldTransparency = 0.92,
    FieldGlow = Color3.fromRGB(144, 231, 68),
    SurfaceStroke = Color3.fromRGB(144, 231, 68),

    NeutralButton = Color3.fromRGB(26, 38, 20),
    NeutralButtonHover = Color3.fromRGB(40, 58, 30),
    NeutralButtonStroke = Color3.fromRGB(255, 255, 255),

    -- Red stays red. It is the one signal that must not read as brand green, and it holds a
    -- wide hue separation against this lime.
    ErrorColor = Color3.fromRGB(190, 48, 48),
    ErrorStrokeColor = Color3.fromRGB(244, 78, 78),

    -- Faces come from constants.fontAsset, which points at a built-in Roblox family, so no
    -- uploaded font asset is needed.
    TitleFont = variables.brandFont(Enum.FontWeight.SemiBold),
    Font = variables.brandFont(Enum.FontWeight.Medium),

    -- Subtle drift on the window gradient and shadow offset, so the surface is never static.
    LiveAnimation = false,
}
