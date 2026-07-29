--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local variables = require(script.utility.variables)
local image = require(script.utility.image)
local locale = require(script.utility.locale)
local constants = require(script.utility.constants)
local types = require(script.types)

-- re-export public types so consumers can annotate against AFKTY.Window etc
export type Theme = types.Theme
export type Translator = types.Translator
export type Translations = types.Translations
export type WindowConfiguration = types.WindowConfiguration

export type WindowProps = types.WindowProps
export type TabProps = types.TabProps
export type RailItemProps = types.RailItemProps
export type RailProfileProps = types.RailProfileProps
export type TagProps = types.TagProps
export type SectionProps = types.SectionProps
export type GroupProps = types.GroupProps
export type ButtonProps = types.ButtonProps
export type ToggleProps = types.ToggleProps
export type SliderProps = types.SliderProps
export type DropdownProps = types.DropdownProps
export type InputProps = types.InputProps
export type KeybindProps = types.KeybindProps
export type ColorPickerProps = types.ColorPickerProps
export type StatProps = types.StatProps
export type NotifyProps = types.NotifyProps
export type ToastProps = types.ToastProps
export type PopupBox = types.PopupBox
export type PopupOption = types.PopupOption
export type PopupProps = types.PopupProps

export type Moveable = types.Moveable
export type Window = types.Window
export type Tab = types.Tab
export type RailItem = types.RailItem
export type Group = types.Group
export type Button = types.Button
export type Toggle = types.Toggle
export type Slider = types.Slider
export type Dropdown = types.Dropdown
export type Input = types.Input
export type Keybind = types.Keybind
export type ColorPicker = types.ColorPicker
export type Stat = types.Stat
export type Section = types.Section
export type Tag = types.Tag
export type Popup = types.Popup
export type AFKTY = types.AFKTY

-- the components are untyped luau, so this is where the window module meets the public contract
type WindowModule = { new: (types.WindowProps) -> types.Window }

local afkty = {} :: AFKTY

local function createBanner()
    local ui = Instance.new("ScreenGui")
    ui.Name = variables.httpService:GenerateGUID(false)
    ui.ClipToDeviceSafeArea = false
    ui.DisplayOrder = constants.displayOrder.banner
    ui.IgnoreGuiInset = true
    ui.ResetOnSpawn = false
    ui.Enabled = true
    ui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
    ui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
    ui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    -- the banner is on screen before the window exists, so it needs the same protection
    variables.parentGui(ui)

    local banner = Instance.new("ImageLabel")
    banner.Name = "Banner"
    banner.AnchorPoint = Vector2.new(0.5, 0.5)
    banner.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    banner.BackgroundTransparency = 1
    banner.BorderColor3 = Color3.fromRGB(0, 0, 0)
    banner.BorderSizePixel = 0
    banner.Image = image.resolve(constants.icons.banner)
    banner.Position = UDim2.fromScale(0.5, 0.5)
    -- square box + Fit, so the emblem letterboxes instead of stretching. the old 262x60 was
    -- cut for a wordmark; Fit keeps this correct if the art is ever swapped for a wide one.
    banner.ScaleType = Enum.ScaleType.Fit
    banner.Size = UDim2.fromOffset(140, 140)
    banner.Parent = ui

    return ui
end

function afkty:CreateWindow(properties: types.WindowProps): types.Window
    local banner = createBanner()

    local window: types.Window? -- forward declared so the settle callback below can reach it
    -- these can fire before the window is built; hold them until it is. a list rather than one
    -- slot, because caching and icon-blocking can both have something to say and the second
    -- would otherwise silently replace the first
    local queuedNotifies: { () -> () } = {}

    local function notifyWhenReady(notify: () -> ())
        if window then
            notify()
        else
            table.insert(queuedNotifies, notify)
        end
    end

    if variables.secureMode then
        -- cache icons locally so secureMode doesnt leak asset ids. non-blocking: whats already on
        -- disk applies now, the rest download in the background and rebind once ready. if any never
        -- cache, tell the dev once - on screen only, secure mode stays off the console
        image.preload(function(failed)
            if failed <= 0 then
                return
            end
            local function notify()
                if not window or window.unloaded then
                    return
                end
                window:Notify({
                    title = locale.resolve("Secure mode"),
                    content = if failed == 1
                        then locale.resolve("An asset couldn't be cached and won't appear.")
                        else locale.resolve("Some assets couldn't be cached and won't appear."),
                })
            end
            notifyWhenReady(notify)
        end)

        -- Secure mode blanks any icon it cannot serve from disk, which is every asset id a hub
        -- passes in beyond the library's own built-ins. That used to happen silently, so the
        -- only symptom was missing artwork with nothing saying why.
        --
        -- Only a non-built-in id is worth reporting. The library's own chrome resolves blank too
        -- until its download lands, so reporting those would fire on every cold start and tell
        -- the dev to cache icons that are about to appear on their own.
        local builtInIcon = {}
        for _, id in constants.icons do
            builtInIcon[id] = true
        end

        local warnedBlocked = false
        image.onBlock = function(value)
            if warnedBlocked then
                return
            end
            local id = if type(value) == "number" then value else tonumber(string.match(tostring(value), "%d+"))
            if id and builtInIcon[id] then
                return -- ours, and it appears as soon as the cache warms
            end
            warnedBlocked = true
            notifyWhenReady(function()
                if not window or window.unloaded then
                    return
                end
                window:Notify({
                    title = locale.resolve("Secure mode"),
                    content = locale.resolve(
                        "Custom icons are hidden in secure mode. Cache them yourself and pass the result."
                    ),
                    duration = 8,
                })
            end)
        end
    end

    -- the banner is only torn down once the window is up, so a throw in here (bad props) would
    -- otherwise strand it in the gui container for the rest of the session
    local made, result = pcall(function()
        return (require(script.components.window) :: WindowModule).new(properties)
    end)
    if not made then
        banner:Destroy()
        error(result, 0)
    end

    local built = result :: types.Window
    window = built

    for _, notify in queuedNotifies do
        task.spawn(notify)
    end
    table.clear(queuedNotifies)

    if variables.secureMode then
        -- secure mode renders the fallback up front (variables.brandFont), then downloads the real
        -- brand faces off the main thread and swaps them in once ready, so startup never blocks
        task.spawn(function()
            local body = variables.fontManager:loadFont(constants.fontAsset, Enum.FontWeight.Medium)
            local title = variables.fontManager:loadFont(constants.fontAsset, Enum.FontWeight.SemiBold)
            -- the download can outlast the window; dont swap into one thats been unloaded
            if
                not built.unloaded
                and body
                and title
                and body ~= variables.fallbackFont
                and title ~= variables.fallbackFont
            then
                built:ChangeTheme({ Font = body, TitleFont = title })
            end
        end)
    end

    task.spawn(function()
        task.wait(0.5)

        banner:Destroy()

        task.wait(0.5)
        -- the window can be unloaded inside this delay; showing it then would fire
        -- saved-config callbacks and build toasts on destroyed instances
        if not built.unloaded then
            built:Show()
        end
    end)

    return built
end

return afkty
