--!strict

-- AFKTY brand theme.
--
-- Sampled from the emblem (assets/source/85628806611332-1254px.png): ~48% pure black
-- ground, a lime ramp averaging hue 100.6 degrees over ~120k green pixels, and near-white
-- highlights. The ramp's blue channel sits at or near zero throughout, so these are
-- yellow-shifted greens -- deliberately NOT the sea-green the default theme ships.
--
--   accent   rgb(144, 231,  68)   emblem highlight
--   mid      rgb( 57,  87,  43)   emblem median
--   deep     rgb( 27,  42,  12)   emblem shadow
--
-- Partial: overrides the surface tones, accent and glows, and inherits corner radii,
-- fonts and toggle/field behaviour from default.
return {
    -- Near-black with a green cast rather than a neutral grey, so the window reads as the
    -- emblem's ground instead of a tinted default.
    WindowColor = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 12, 6)),
        ColorSequenceKeypoint.new(0.9999, Color3.fromRGB(18, 26, 14)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(24, 34, 18)),
    }),
    ShadowColor = Color3.fromRGB(4, 9, 2),

    ElementStroke = Color3.fromRGB(34, 50, 26),
    ElementGradient = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 28, 15)),
        ColorSequenceKeypoint.new(0.9999, Color3.fromRGB(26, 36, 20)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(26, 36, 20)),
    }),
    -- The sheen. Runs bright through the middle so element edges catch a lime highlight
    -- instead of sitting flat -- this is most of what reads as "shiny".
    ElementStrokeGradient = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(56, 90, 34)),
        ColorSequenceKeypoint.new(0.9999, Color3.fromRGB(98, 152, 54)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(56, 90, 34)),
    }),
    ElementStrokeHover = Color3.fromRGB(112, 176, 62),

    TabBackground = ColorSequence.new(Color3.fromRGB(44, 66, 28), Color3.fromRGB(24, 36, 16)),
    TabStroke = ColorSequence.new(Color3.fromRGB(104, 160, 56), Color3.fromRGB(48, 74, 30)),

    SliderBackground = Color3.fromRGB(32, 44, 24),
    SliderBackgroundHover = Color3.fromRGB(48, 66, 34),
    SliderProgress = ColorSequence.new(Color3.fromRGB(154, 240, 78), Color3.fromRGB(94, 168, 36)),

    -- Active toggle, slider glow and popup primary button. Fill sits deeper than the stroke
    -- so the edge reads as a lit rim rather than a flat block.
    AccentColor = Color3.fromRGB(112, 190, 48),
    AccentStroke = Color3.fromRGB(154, 240, 78),
    AccentGlow = 0.25, -- lower than default 0.4, so the toggle glow carries further

    StatBackground = Color3.fromRGB(15, 22, 11),

    DropdownHighlight = Color3.fromRGB(196, 248, 146),

    -- Inset fields pick up a lime glow instead of the default white.
    FieldGlow = Color3.fromRGB(144, 231, 68),
    SurfaceStroke = Color3.fromRGB(128, 200, 76),

    -- Slightly green-cast off-knob so it belongs to the palette when inactive.
    ToggleKnobOff = Color3.fromRGB(206, 224, 196),

    NeutralButton = Color3.fromRGB(28, 40, 22),
    NeutralButtonHover = Color3.fromRGB(42, 60, 32),

    -- Error stays red on purpose. It is the one signal that must not read as brand green,
    -- and red against this lime holds a strong hue separation.
    ErrorColor = Color3.fromRGB(190, 48, 48),
    ErrorStrokeColor = Color3.fromRGB(244, 78, 78),

    -- Subtle drift on the window gradient and shadow offset, so the surface is never
    -- perfectly static.
    LiveAnimation = true,
}
