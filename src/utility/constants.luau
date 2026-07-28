--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Shared visual constants. Theme-varying colours/fonts live in themes/; these dont.

local constants = {}

-- Brand font family. A built-in Roblox family, so nothing has to be uploaded or downloaded
-- at runtime, and it matches the typography of the original hand-built hub.
constants.fontAsset = "rbxasset://fonts/families/GothamSSm.json"

-- the input/keybind fields hug their text, tweening width instead of AutomaticSize so it animates
constants.pillResizeInfo = TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

-- Every built-in icon AFKTY ships, by name. Single source of truth: secure mode caches
-- exactly these (see utility/image) so the UI never has to fall back to a raw asset id at
-- runtime. Add a new built-in icon here and it's cached automatically.
constants.icons = {
    close = 83277910885129,
    minimise = 108115485663409,
    maximise = 88738500661569,
    settings = 129180860773723,
    search = 100604009889706,
    chevron = 88479147175134,
    check = 125626312718314,
    dot = 91452555903853, -- unselected dropdown option (also the colorpicker "invisible" mark)
    colorpicker = 91452555903853, -- same hollow-box glyph as dot
    banner = 85628806611332, -- AFKTY emblem, shown while the window builds
    config = 125823673784681, -- saved-configurations picker
    afkty = 85628806611332, -- default show icon on the sign-in toast
}

-- Accent used by the toggle switch + slider glow when active.
constants.accent = {
    on = Color3.fromRGB(112, 190, 48),
    onStroke = Color3.fromRGB(166, 250, 92),
}

-- Stat card accents per direction (fill drives the card + glow, stroke is the brighter edge).
constants.statAccents = {
    positive = {
        fill = ColorSequence.new(Color3.fromRGB(122, 205, 54), Color3.fromRGB(94, 168, 36)),
        stroke = ColorSequence.new(Color3.fromRGB(166, 250, 92), Color3.fromRGB(140, 224, 74)),
    },
    negative = {
        fill = ColorSequence.new(Color3.fromRGB(172, 47, 47), Color3.fromRGB(135, 37, 37)),
        stroke = ColorSequence.new(Color3.fromRGB(255, 75, 75), Color3.fromRGB(244, 67, 67)),
    },
    -- Neutral deliberately matches the positive accent
    neutral = {
        fill = ColorSequence.new(Color3.fromRGB(122, 205, 54), Color3.fromRGB(94, 168, 36)),
        stroke = ColorSequence.new(Color3.fromRGB(166, 250, 92), Color3.fromRGB(140, 224, 74)),
    },
}

-- Named stacking layers for window furniture (assumes Global ZIndexBehavior)
constants.zIndex = {
    bottomFade = 100,
    -- bottom-right notification cards, above the bottom fade + drag so they aren't dimmed or
    -- pierced by them (they land over the window's lower-right corner)
    notification = 1500,
    drag = 1000,
    -- top-centre and bottom-centre toasts float over the whole window
    toast = 2000,
    toastContent = 2001,
    restoreContent = 100001,
    restoreInteract = 100002,
}

-- DisplayOrder for the top-level ScreenGuis (the window vs the loading banner).
constants.displayOrder = {
    window = 99999,
    banner = 100000,
    -- modal popups sit above everything, dim included
    popup = 100001,
}

return constants
