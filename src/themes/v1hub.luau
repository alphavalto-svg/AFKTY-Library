--!strict

-- AFKTY v1 Hub theme.
--
-- Ported from the original hand-built v1 hub GUI so the library matches the look that
-- already shipped. Every value below is lifted from that script rather than invented:
--
--   accent bright  rgb(  0, 200, 255)  UIStroke, active toggle, scrollbar
--   accent mid     rgb(  0, 150, 220)  active tab button
--   ground         rgb(  5,  10,  20)  Container
--   window         rgb(  8,  12,  22)  MainFrame
--   panel          rgb( 15,  25,  40)  TabContainer
--   element        rgb( 18,  28,  45)  ToggleFrame
--   inactive       rgb( 60,  80, 100)  toggle status, off
--   title text     rgb(200, 240, 255)  TitleLabel
--
-- Partial: overrides surfaces, accent, corner radii and fonts; inherits the rest from
-- default.
return {
    -- v1 used UDim.new(0, 8) on the window and 6 on elements, against default's 20/12.
    -- The tighter radii are a large part of why v1 reads sharper than stock.
    CornerRoundness = UDim.new(0, 8),
    ElementCornerRadius = UDim.new(0, 6),

    WindowColor = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(5, 10, 20)),
        ColorSequenceKeypoint.new(0.9999, Color3.fromRGB(8, 12, 22)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 25, 40)),
    }),
    ShadowColor = Color3.fromRGB(2, 5, 12),

    ElementStroke = Color3.fromRGB(25, 40, 65),
    ElementGradient = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 24, 38)),
        ColorSequenceKeypoint.new(0.9999, Color3.fromRGB(18, 28, 45)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 28, 45)),
    }),
    -- v1 brightened each element's UIStroke from 0.7 to 0.2 transparency on hover. There is
    -- no per-element hover stroke here, so the same effect is carried by a gradient that
    -- runs bright through its midpoint -- edges catch a cyan highlight instead of sitting flat.
    ElementStrokeGradient = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 88, 128)),
        ColorSequenceKeypoint.new(0.9999, Color3.fromRGB(0, 162, 212)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 88, 128)),
    }),
    ElementStrokeHover = Color3.fromRGB(0, 200, 255),

    -- Active-to-inactive tab, matching v1's selected pill.
    TabBackground = ColorSequence.new(Color3.fromRGB(0, 150, 220), Color3.fromRGB(25, 40, 65)),
    TabStroke = ColorSequence.new(Color3.fromRGB(0, 200, 255), Color3.fromRGB(25, 40, 65)),

    SliderBackground = Color3.fromRGB(25, 40, 65),
    SliderBackgroundHover = Color3.fromRGB(36, 56, 88),
    SliderProgress = ColorSequence.new(Color3.fromRGB(0, 200, 255), Color3.fromRGB(0, 140, 205)),

    AccentColor = Color3.fromRGB(0, 150, 220),
    AccentStroke = Color3.fromRGB(0, 200, 255),
    AccentGlow = 0.25, -- stronger than default 0.4, standing in for v1's stroke brightening

    StatBackground = Color3.fromRGB(12, 20, 34),
    DropdownHighlight = Color3.fromRGB(200, 240, 255),

    FieldGlow = Color3.fromRGB(0, 200, 255),
    SurfaceStroke = Color3.fromRGB(0, 200, 255),

    -- v1's unlit toggle square, reused so the off state matches exactly.
    ToggleKnobOff = Color3.fromRGB(60, 80, 100),
    ToggleKnobOffTransparency = 0.35,

    TitlingColor = Color3.fromRGB(200, 240, 255),
    PlaceholderColor = Color3.fromRGB(110, 145, 175),

    NeutralButton = Color3.fromRGB(18, 28, 45),
    NeutralButtonHover = Color3.fromRGB(25, 40, 65),

    -- Red against this cyan holds a wide hue separation, so error stays legible without
    -- competing with the accent.
    ErrorColor = Color3.fromRGB(190, 48, 48),
    ErrorStrokeColor = Color3.fromRGB(244, 78, 78),

    -- v1 used Gotham throughout. Setting the faces here rather than in constants.fontAsset
    -- keeps the change scoped to this theme, so the other built-ins are unaffected -- and it
    -- needs no uploaded font asset.
    TitleFont = Font.fromEnum(Enum.Font.GothamBold),
    Font = Font.fromEnum(Enum.Font.Gotham),

    LiveAnimation = true,
}
