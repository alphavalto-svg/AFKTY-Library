--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Shared visual constants. Theme-varying colours/fonts live in themes/; these dont.

local constants = {}

-- Bundle version, surfaced as AFKTY.version. The bundle is fetched over HttpGet and executors
-- cache that per URL, so a hub can be running a build several days old with nothing to show
-- for it. Keep this in step with version.txt.
constants.version = "1.0.3"

-- Brand font family. Built into Roblox, so nothing is uploaded or downloaded at runtime.
constants.fontAsset = "rbxasset://fonts/families/GothamSSm.json"

-- the input/keybind fields hug their text, tweening width instead of AutomaticSize so it animates
constants.pillResizeInfo = TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

-- Every built-in icon AFKTY ships, by name. Secure mode caches exactly these, so the UI never
-- has to fall back to a raw asset id at runtime.
constants.icons = {
    close = 90172788330629,
    minimise = 136031305763694,
    maximise = 134279979385460,
    settings = 123873302071776,
    search = 102529133382626,
    chevron = 104706369326409,
    check = 95316442098951,
    dot = 95965547856004, -- unselected dropdown option (also the colorpicker "invisible" mark)
    colorpicker = 95965547856004, -- same hollow-box glyph as dot
    banner = 85628806611332, -- AFKTY emblem, shown while the window builds
    config = 139478662436110, -- saved-configurations picker
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
    -- over the bottom fade it shares a corner with, but under the notification cards
    resizeGrip = 200,
    -- bottom-right cards, above the fade and the grip so they are not dimmed or pierced
    notification = 1500,
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
