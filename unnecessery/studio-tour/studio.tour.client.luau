--[[
	AFKTY Library - full API tour.

	A second Studio demo whose only job is to touch every public function once, with each
	control labelled with the call it makes. studio.client.luau is the realistic hub; this is
	the exhaustive one. Watch the Output window - every action prints a [TOUR] line naming the
	method that ran, so what you clicked and what it called are never in doubt.

	To run this instead of the normal demo:
	  in Studio, tick Disabled on StarterPlayerScripts.Client, untick it on StarterPlayerScripts.Tour.

	What cannot be tested here, and why:
	  - Secure mode. Gated on getgenv().AFKTY_SECURE, read once at load (utility/runtime.luau).
	    Studio has no getgenv, so secure mode is always false. Needs a real executor.
	  - Persistence across sessions. Studio has no writefile, so utility/filesystem.luau
	    simulates the disk with instances under ReplicatedStorage.Filesystem. Save/Load/List
	    all work and return true - open that folder to read the JSON - but it dies with the
	    session. Only a real executor writes to disk.
	  - Extra themes. src/themes/ contains only "default", so ChangeTheme is demonstrated with
	    a partial table override instead of a second named theme.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Library = require(ReplicatedStorage.AFKTY)

-- let the viewport settle so the window sizes to the full screen
task.wait(2)

local function log(...)
    print("[TOUR]", ...)
end

-- Icons reused from the other demos, so every id here is known-good.
local ICON = {
    leaf = 93364949241311,
    bolt = 139478662436110,
    warn = 90172788330629,
    sword = 84750991656135,
    page = 102529133382626,
    chart = 85925158736685,
    gear = 123873302071776,
}

-- Window --------------------------------------------------------------------
-- Every WindowProps field is passed here so you can see each one's effect in one place.
local Window = Library:CreateWindow({
    name = "AFKTY API Tour", -- window title
    subtitle = "every public call, once", -- second line under the title
    icon = ICON.leaf, -- title bar emblem
    showName = "API Tour", -- label on the collapsed pill after Hide()
    showIcon = ICON.leaf, -- icon on that pill
    resize = true, -- bottom-right grip (this is the default; false removes it)
    theme = "default", -- the only theme that ships
    locale = "en", -- pin the language; omit to follow the player's Roblox locale
    translations = { -- table-first localisation, exercised on the Locale tab
        fr = {
            ["Buttons"] = "Boutons",
            ["Fire callback"] = "Déclencher le rappel",
            ["Toggles"] = "Bascules",
        },
    },
    configuration = {
        autoSave = true, -- write the default config whenever a flagged control changes
        autoLoad = true, -- read it back on open
        fileName = "APITour", -- config file name
        customFolder = "AFKTY", -- folder it lives in
    },
})

-- Tags sit next to the title. They order themselves, so they are not Moveable.
local tag = Window:CreateTag({ text = "tour", color = Color3.fromRGB(144, 231, 68) })

-- Rail ----------------------------------------------------------------------
-- Left rail = main categories. Each tab below belongs to exactly one, so the top strip
-- changes with the rail selection. The library selects the first category itself, and
-- item:Select() clears the siblings, so nothing here tracks which was previously active.
local elementsCategory = Window:CreateRailItem({
    icon = ICON.leaf,
    name = "Elements", -- shows as the hover tooltip
    callback = function(item)
        item:Select() -- Rail:Select() - take the selection, clear every sibling
        log("Rail:Select() -> Elements")
    end,
})

local layoutCategory = Window:CreateRailItem({
    icon = ICON.sword,
    name = "Layout",
    callback = function(item)
        item:Select()
        log("Rail:Select() -> Layout")
    end,
})

local windowCategory = Window:CreateRailItem({
    icon = ICON.gear,
    name = "Window",
    callback = function(item)
        item:Select()
        log("Rail:Select() -> Window")
    end,
})

-- The avatar chip, pinned to the bottom of the rail. The library draws the headshot and
-- reports the click; what gets shown about the account is this script's business.
local profile = Window:CreateRailProfile({
    callback = function(self)
        log("CreateRailProfile callback, userId =", self.userId)
    end,
})

-- ===========================================================================
-- Category: Elements
-- ===========================================================================

-- Button --------------------------------------------------------------------
local buttonTab = Window:CreateTab({ name = "Button", icon = ICON.leaf, category = elementsCategory })

buttonTab:CreateSection({ name = "Buttons" }) -- CreateSection: a labelled divider

buttonTab:CreateButton({
    name = "Fire callback",
    description = "The plainest element. Runs its callback on click, holds no state.",
    icon = ICON.bolt,
    callback = function()
        log("Button callback fired")
    end,
})

buttonTab:CreateButton({
    name = "Callback that errors",
    description = "The library catches a throwing callback and flashes the row red rather than dying.",
    callback = function()
        error("deliberate error from the tour script")
    end,
})

-- Toggle --------------------------------------------------------------------
local toggleTab = Window:CreateTab({ name = "Toggle", icon = ICON.bolt, category = elementsCategory })

toggleTab:CreateSection({ name = "Toggles" })

local autoFarm = toggleTab:CreateToggle({
    name = "Auto Farm",
    description = "flag = AutoFarm, so this one is saved and restored.",
    flag = "AutoFarm",
    value = true,
    callback = function(value)
        log("Toggle callback:", value)
    end,
})

-- CreateSwitch is a straight alias for CreateToggle (tab.luau:393) - same element, same props.
toggleTab:CreateSwitch({
    name = "Switch (alias of CreateToggle)",
    flag = "TourSwitch",
})

toggleTab:CreateToggle({
    name = "Not saved",
    description = "forgetState = true keeps this out of the config file.",
    forgetState = true,
})

toggleTab:CreateButton({
    name = "Toggle:Set(true)",
    callback = function()
        autoFarm:Set(true) -- fires the callback
        log("Toggle:Set(true), value is now", autoFarm.value)
    end,
})

toggleTab:CreateButton({
    name = "Toggle:Set(false, skipCallback)",
    description = "Second argument suppresses the callback - use it when restoring state.",
    callback = function()
        autoFarm:Set(false, true)
        log("Toggle:Set(false, true) - callback suppressed, value is", autoFarm.value)
    end,
})

-- Slider --------------------------------------------------------------------
local sliderTab = Window:CreateTab({ name = "Slider", icon = ICON.chart, category = elementsCategory })

sliderTab:CreateSection({ name = "Sliders" })

local delay = sliderTab:CreateSlider({
    name = "Delay",
    description = "range + increment + suffix.",
    flag = "TourDelay",
    range = { 0, 10 },
    increment = 0.5,
    value = 2,
    suffix = "s",
    callback = function(value)
        log("Slider callback:", value)
    end,
})

sliderTab:CreateSlider({
    name = "Minimal",
    description = "minimal = true draws the track alone, for dense rows.",
    range = { 0, 100 },
    value = 40,
    minimal = true,
    forgetState = true,
})

sliderTab:CreateButton({
    name = "Slider:Set(7.5)",
    callback = function()
        delay:Set(7.5)
        log("Slider:Set(7.5), value is now", delay.value)
    end,
})

-- Dropdown ------------------------------------------------------------------
local dropdownTab = Window:CreateTab({ name = "Dropdown", icon = ICON.page, category = elementsCategory })

dropdownTab:CreateSection({ name = "Dropdowns" })

local seed = dropdownTab:CreateDropdown({
    name = "Seed",
    description = "Single select. value is always stored as a pruned list, even here.",
    flag = "TourSeed",
    options = { "Tomato", "Carrot", "Corn" },
    value = "Tomato",
    callback = function(value)
        log("Dropdown callback:", typeof(value) == "table" and table.concat(value, ", ") or value)
    end,
})

dropdownTab:CreateDropdown({
    name = "Auto Buy",
    description = "multiSelect = true, with a placeholder for the empty state.",
    flag = "TourAutoBuy",
    multiSelect = true,
    options = { "Tomato", "Carrot", "Corn" },
    value = { "Tomato" },
    placeholder = "None selected",
})

dropdownTab:CreateButton({
    name = "Dropdown:Add('Pumpkin')",
    callback = function()
        seed:Add("Pumpkin")
        log("Dropdown:Add('Pumpkin')")
    end,
})

dropdownTab:CreateButton({
    name = "Dropdown:Remove('Corn')",
    callback = function()
        seed:Remove("Corn")
        log("Dropdown:Remove('Corn')")
    end,
})

dropdownTab:CreateButton({
    name = "Dropdown:Refresh({...})",
    description = "Replaces the whole option list. Selections no longer in the list are pruned.",
    callback = function()
        seed:Refresh({ "Wheat", "Barley", "Rye" })
        log("Dropdown:Refresh(), value is now", table.concat(seed.value, ", "))
    end,
})

dropdownTab:CreateButton({
    name = "Dropdown:Set('Barley')",
    callback = function()
        seed:Set("Barley")
        log("Dropdown:Set('Barley')")
    end,
})

-- Input, Keybind, Color Picker ----------------------------------------------
local fieldsTab = Window:CreateTab({ name = "Fields", icon = ICON.gear, category = elementsCategory })

fieldsTab:CreateSection({ name = "Input" })

local webhook = fieldsTab:CreateInput({
    name = "Webhook",
    description = "Commits on focus loss or Enter, not per keystroke.",
    flag = "TourWebhook",
    placeholder = "https://...",
    callback = function(value)
        log("Input callback:", value)
    end,
})

fieldsTab:CreateInput({
    name = "Max Players",
    description = "numeric = true rejects non-digits. clearOnFocus empties the box on click.",
    flag = "TourMaxPlayers",
    value = "16",
    numeric = true,
    clearOnFocus = true,
})

fieldsTab:CreateButton({
    name = "Input:Set('https://set-by-code')",
    callback = function()
        webhook:Set("https://set-by-code")
        log("Input:Set(), value is now", webhook.value)
    end,
})

fieldsTab:CreateSection({ name = "Keybind" })

local sprint = fieldsTab:CreateKeybind({
    name = "Sprint",
    description = "Press mode: the callback gets the bound key on each press.",
    flag = "TourSprint",
    value = Enum.KeyCode.LeftShift,
    callback = function(key)
        log("Keybind callback, key =", key)
    end,
    onChanged = function(key)
        log("Keybind onChanged, rebound to", key)
    end,
})

fieldsTab:CreateKeybind({
    name = "Zoom (hold)",
    description = "hold = true fires true once held past holdThreshold, false on release.",
    flag = "TourZoom",
    value = Enum.KeyCode.C,
    hold = true,
    holdThreshold = 0.2,
    callback = function(holding)
        log("Hold keybind:", holding)
    end,
})

fieldsTab:CreateButton({
    name = "Keybind:Set(Enum.KeyCode.G)",
    callback = function()
        sprint:Set(Enum.KeyCode.G)
        log("Keybind:Set(G), value is now", sprint.value)
    end,
})

fieldsTab:CreateSection({ name = "Color Picker" })

local espColor = fieldsTab:CreateColorPicker({
    name = "ESP Colour",
    description = "Colour plus an alpha channel; both are saved.",
    flag = "TourColor",
    color = Color3.fromRGB(144, 231, 68),
    alpha = 1,
    callback = function(color, alpha)
        log("ColorPicker callback:", color, "alpha", alpha)
    end,
})

fieldsTab:CreateButton({
    name = "ColorPicker:Set('#ff8800')",
    description = "Set accepts a Color3 or a hex string.",
    callback = function()
        espColor:Set("#ff8800")
        log("ColorPicker:Set(), value is now", espColor.value)
    end,
})

fieldsTab:CreateButton({
    name = "ColorPicker:SetAlpha(0.4)",
    callback = function()
        espColor:SetAlpha(0.4)
        log("ColorPicker:SetAlpha(0.4), alpha is now", espColor.alpha)
    end,
})

-- Stat ----------------------------------------------------------------------
local statTab = Window:CreateTab({ name = "Stat", icon = ICON.chart, category = elementsCategory })

statTab:CreateSection({ name = "Read-outs" })

local revenue = statTab:CreateStat({
    name = "Revenue",
    description = "display = 'value' shows the number itself.",
    prefix = "$",
    value = 12400,
    display = "value",
    compact = true, -- the 41px single-readout card instead of the 90px one
    numberEasing = true, -- animate between values instead of snapping
})

local kills = statTab:CreateStat({
    name = "Kills since open",
    description = "display = 'change' shows movement against a baseline.",
    value = 128,
    display = "change",
    changeMode = "percentage", -- or "absolute"
    changeBaseline = "initial", -- or "previous"
})

statTab:CreateButton({
    name = "Stat:Set(random)",
    callback = function()
        revenue:Set(revenue.value + math.random(500, 3000))
        kills:Set(kills.value + math.random(1, 20))
        log("Stat:Set() ->", revenue.value, kills.value)
    end,
})

statTab:CreateButton({
    name = "Stat:ResetBaseline()",
    description = "Re-zeroes the change read-out against the current value.",
    callback = function()
        kills:ResetBaseline()
        log("Stat:ResetBaseline()")
    end,
})

-- ===========================================================================
-- Category: Layout
-- ===========================================================================

-- Groups --------------------------------------------------------------------
local groupsTab = Window:CreateTab({ name = "Groups", icon = ICON.sword, category = layoutCategory })

groupsTab:CreateSection({ name = "A row of columns is a grid" })

-- A group lays its children along one axis and nests. A row takes the compact elements
-- (button/toggle/stat) plus slider; a column also takes dropdown and section. Input,
-- keybind and colorpicker stay tab-level.
local grid = groupsTab:CreateGroup() -- default direction is "row"

local leftColumn = grid:CreateGroup({ direction = "column" })
leftColumn:CreateSection({ name = "Left" })
leftColumn:CreateToggle({ name = "Auto Plant", flag = "TourAutoPlant" })
leftColumn:CreateToggle({ name = "Auto Water", flag = "TourAutoWater" })
leftColumn:CreateSlider({ name = "Rate", range = { 0, 10 }, value = 5, flag = "TourRate" })

local rightColumn = grid:CreateGroup({ direction = "column" })
rightColumn:CreateSection({ name = "Right" })
rightColumn:CreateToggle({ name = "Auto Sell", flag = "TourAutoSell" })
rightColumn:CreateStat({ name = "Sold", value = 42 })
rightColumn:CreateDropdown({
    name = "Target",
    options = { "Nearest", "Furthest" },
    value = "Nearest",
    flag = "TourTarget",
})

groupsTab:CreateSection({ name = "Buttons in a row" })

local buttonRow = groupsTab:CreateGroup({ direction = "row" })
buttonRow:CreateButton({
    name = "One",
    callback = function()
        log("Group button: one")
    end,
})
buttonRow:CreateButton({
    name = "Two",
    callback = function()
        log("Group button: two")
    end,
})
buttonRow:CreateSwitch({ name = "Three", flag = "TourRowSwitch" })

-- Ordering ------------------------------------------------------------------
-- Every element carries the Moveable methods, mixed in by utility/moveable.
local orderTab = Window:CreateTab({ name = "Ordering", icon = ICON.page, category = layoutCategory })

orderTab:CreateSection({ name = "Moveable - watch the marked row jump" })

orderTab:CreateToggle({ name = "Filler A", forgetState = true })
orderTab:CreateToggle({ name = "Filler B", forgetState = true })
local mover = orderTab:CreateToggle({
    name = ">>> THIS ONE MOVES <<<",
    description = "The buttons below reposition this row within its tab.",
    forgetState = true,
})
orderTab:CreateToggle({ name = "Filler C", forgetState = true })
orderTab:CreateToggle({ name = "Filler D", forgetState = true })

orderTab:CreateButton({
    name = "MoveToTop()",
    callback = function()
        mover:MoveToTop()
        log("Moveable:MoveToTop()")
    end,
})
orderTab:CreateButton({
    name = "MoveToBottom()",
    callback = function()
        mover:MoveToBottom()
        log("Moveable:MoveToBottom()")
    end,
})
orderTab:CreateButton({
    name = "MoveUp()",
    callback = function()
        mover:MoveUp()
        log("Moveable:MoveUp()")
    end,
})
orderTab:CreateButton({
    name = "MoveDown()",
    callback = function()
        mover:MoveDown()
        log("Moveable:MoveDown()")
    end,
})
orderTab:CreateButton({
    name = "MoveTo(3)",
    callback = function()
        mover:MoveTo(3)
        log("Moveable:MoveTo(3)")
    end,
})

-- ===========================================================================
-- Category: Window
-- ===========================================================================

-- Chrome --------------------------------------------------------------------
local chromeTab = Window:CreateTab({ name = "Chrome", icon = ICON.gear, category = windowCategory })

chromeTab:CreateSection({ name = "Visibility - K brings the window back" })

chromeTab:CreateButton({
    name = "Window:ToggleMinimise()",
    description = "Collapses to the 300x66 bar. The emblem stays on it.",
    callback = function()
        Window:ToggleMinimise()
        log("Window:ToggleMinimise()")
    end,
})

chromeTab:CreateButton({
    name = "Window:Hide()",
    description = "Hides to the pill labelled by showName. Press K to bring it back.",
    callback = function()
        log("Window:Hide() - press K to restore")
        task.wait(0.2)
        Window:Hide()
    end,
})

chromeTab:CreateButton({
    name = "Window:ToggleHide()",
    description = "Hide or show depending on current state. Same K to restore.",
    callback = function()
        log("Window:ToggleHide() - press K if it goes away")
        task.wait(0.2)
        Window:ToggleHide()
    end,
})

chromeTab:CreateButton({
    name = "Window:Show()",
    description = "Only observable from a hidden window, so pair it with the keybind.",
    callback = function()
        Window:Show()
        log("Window:Show()")
    end,
})

chromeTab:CreateSection({ name = "Navigation" })

chromeTab:CreateButton({
    name = "Window:Navigate('Button')",
    description = "Accepts a tab name or a tab handle.",
    callback = function()
        Window:Navigate("Button")
        log("Window:Navigate('Button')")
    end,
})

chromeTab:CreateButton({
    name = "Tab:Select() / Tab:Deselect()",
    callback = function()
        buttonTab:Select()
        log("Tab:Select() on the Button tab")
    end,
})

chromeTab:CreateSection({ name = "Tags" })

chromeTab:CreateButton({
    name = "Tag:SetText('live')",
    callback = function()
        tag:SetText("live")
        log("Tag:SetText('live')")
    end,
})
chromeTab:CreateButton({
    name = "Tag:SetColor(orange)",
    callback = function()
        tag:SetColor(Color3.fromRGB(255, 175, 15))
        log("Tag:SetColor()")
    end,
})
chromeTab:CreateButton({
    name = "Tag:SetIcon(bolt)",
    callback = function()
        tag:SetIcon(ICON.bolt)
        log("Tag:SetIcon()")
    end,
})
chromeTab:CreateButton({
    name = "Tag:Set({...})",
    description = "Sets text, colour and icon in one call.",
    callback = function()
        tag:Set({ text = "tour", color = Color3.fromRGB(144, 231, 68), icon = ICON.leaf })
        log("Tag:Set()")
    end,
})
chromeTab:CreateButton({
    name = "Tag:Remove()",
    callback = function()
        tag:Remove()
        log("Tag:Remove() - gone until you rerun the script")
    end,
})

chromeTab:CreateSection({ name = "Rail" })

chromeTab:CreateButton({
    name = "Rail:Select() on Layout",
    callback = function()
        layoutCategory:Select()
        log("Rail:Select() on the Layout category")
    end,
})
chromeTab:CreateButton({
    name = "Rail:SetActive(false) on Window",
    description = "Sets the highlight directly, without clearing siblings the way Select does.",
    callback = function()
        windowCategory:SetActive(false)
        log("Rail:SetActive(false)")
    end,
})
chromeTab:CreateButton({
    name = "RailProfile:SetUserId(1)",
    description = "Repoints the avatar chip at another account.",
    callback = function()
        profile:SetUserId(1)
        log("Rail:SetUserId(1)")
    end,
})

-- Overlays ------------------------------------------------------------------
local overlayTab = Window:CreateTab({ name = "Overlays", icon = ICON.warn, category = windowCategory })

overlayTab:CreateSection({ name = "Three different things" })

overlayTab:CreateButton({
    name = "Window:Notify()",
    description = "The stacked card, top right. Title, body, icon, duration.",
    callback = function()
        Window:Notify({
            title = "Auto-saved",
            content = "Your configuration was written to disk.",
            icon = ICON.bolt,
            duration = 4,
        })
        log("Window:Notify()")
    end,
})

overlayTab:CreateButton({
    name = "Window:Toast()",
    description = "The small pill. Two lines, optional icon or avatar.",
    callback = function()
        Window:Toast({
            title = "Saved",
            subtitle = "APITour.json",
            icon = ICON.bolt,
            duration = 3,
            position = "Top",
        })
        log("Window:Toast()")
    end,
})

overlayTab:CreateButton({
    name = "Window:Toast() with an avatar",
    description = "avatar takes a user id and draws that headshot instead of an icon.",
    callback = function()
        Window:Toast({
            title = "Player joined",
            subtitle = "Roblox",
            subtitleAbove = true, -- label over value
            avatar = 1,
            minWidth = 220,
        })
        log("Window:Toast() with avatar")
    end,
})

overlayTab:CreateButton({
    name = "Window:Popup()",
    description = "The modal. Returns a handle with Close().",
    callback = function()
        local popup = Window:Popup({
            title = "Reset everything?",
            subtitle = "This cannot be undone",
            icon = ICON.warn,
            content = "Clears every saved value and puts the menu back to its defaults.",
            dismissable = true, -- click the dim or press Escape
            options = {
                { text = "Cancel", style = "neutral" },
                {
                    text = "Reset",
                    style = "danger",
                    callback = function()
                        log("Popup option: Reset")
                    end,
                },
            },
        })
        log("Window:Popup() ->", popup)
    end,
})

overlayTab:CreateButton({
    name = "Popup() then Popup:Close() after 2s",
    description = "Closing the modal from code rather than from a button.",
    callback = function()
        local popup = Window:Popup({
            title = "Closing in 2 seconds",
            content = "This one is dismissed by the script, not by you.",
            boxes = { -- the changelog layout: a list of cards
                { title = "1.1.0", description = "Window resizing.", icon = ICON.leaf },
                { title = "1.0.0", description = "First release.", icon = ICON.bolt },
            },
        })
        task.wait(2)
        popup:Close()
        log("Popup:Close()")
    end,
})

-- Saving --------------------------------------------------------------------
local saveTab = Window:CreateTab({ name = "Saving", icon = ICON.page, category = windowCategory })

saveTab:CreateSection({ name = "Configs - inspect ReplicatedStorage.Filesystem" })

saveTab:CreateButton({
    name = "Window:GetPath()",
    callback = function()
        log("Window:GetPath() ->", Window:GetPath())
    end,
})

saveTab:CreateButton({
    name = "Window:Save()",
    description = "No argument writes the default config named by configuration.fileName.",
    callback = function()
        log("Window:Save() ->", Window:Save())
    end,
})

saveTab:CreateButton({
    name = "Window:Save('LoadoutA')",
    description = "A name writes a separate config alongside the default one.",
    callback = function()
        log("Window:Save('LoadoutA') ->", Window:Save("LoadoutA"))
    end,
})

saveTab:CreateButton({
    name = "Window:Load('LoadoutA')",
    description = "Applies a named config to the live UI.",
    callback = function()
        log("Window:Load('LoadoutA') ->", Window:Load("LoadoutA"))
    end,
})

saveTab:CreateButton({
    name = "Window:ListConfigs()",
    callback = function()
        local list = Window:ListConfigs()
        log("Window:ListConfigs() ->", #list > 0 and table.concat(list, ", ") or "(none)")
    end,
})

saveTab:CreateButton({
    name = "Window:DeleteConfig('LoadoutA')",
    callback = function()
        log("Window:DeleteConfig('LoadoutA') ->", Window:DeleteConfig("LoadoutA"))
    end,
})

saveTab:CreateSection({ name = "Flags - reach any control by its flag" })

saveTab:CreateButton({
    name = "Window:Get('AutoFarm')",
    callback = function()
        log("Window:Get('AutoFarm') ->", Window:Get("AutoFarm"))
    end,
})

saveTab:CreateButton({
    name = "Window:Set('AutoFarm', true)",
    description = "Routes through the control, so the UI updates and the callback fires.",
    callback = function()
        log("Window:Set('AutoFarm', true) ->", Window:Set("AutoFarm", true))
    end,
})

saveTab:CreateButton({
    name = "Window:Set('TourDelay', 9)",
    callback = function()
        log("Window:Set('TourDelay', 9) ->", Window:Set("TourDelay", 9))
    end,
})

saveTab:CreateSection({ name = "Library settings - theme, keybind, window size" })

saveTab:CreateButton({
    name = "Window:SaveSettings()",
    description = "The library's own settings file, separate from your configs.",
    callback = function()
        Window:SaveSettings()
        log("Window:SaveSettings()")
    end,
})

saveTab:CreateButton({
    name = "Window:LoadSettings()",
    callback = function()
        Window:LoadSettings()
        log("Window:LoadSettings()")
    end,
})

-- Locale and theme ----------------------------------------------------------
local localeTab = Window:CreateTab({ name = "Locale", icon = ICON.leaf, category = windowCategory })

localeTab:CreateSection({ name = "Localisation" })

localeTab:CreateDropdown({
    name = "Language",
    description = "Switches every localised label in place. Untranslated strings stay in English.",
    options = { "English", "Français", "Deutsch (registered at runtime)" },
    value = "English",
    forgetState = true,
    callback = function(value)
        if value == "Deutsch (registered at runtime)" then
            -- RegisterTranslations merges new tables into the existing ones after open
            Window:RegisterTranslations({
                de = { ["Buttons"] = "Schaltflächen", ["Toggles"] = "Schalter" },
            })
            Window:SetLocale("de")
        elseif value == "Français" then
            Window:SetLocale("fr")
        else
            Window:SetLocale("en")
        end
        log("Window:SetLocale() ->", value)
    end,
})

localeTab:CreateButton({
    name = "Window:SetTranslator(fn)",
    description = "Resolve copy yourself. This one upper-cases everything so the hook is obvious.",
    callback = function()
        Window:SetTranslator(function(source, _localeId)
            return string.upper(source)
        end)
        log("Window:SetTranslator() - everything is upper-case now")
    end,
})

localeTab:CreateButton({
    name = "Window:SetTranslator(nil)",
    description = "Clearing it falls back to the built-in tables.",
    callback = function()
        Window:SetTranslator(nil)
        log("Window:SetTranslator(nil)")
    end,
})

localeTab:CreateSection({ name = "Theme" })

localeTab:CreateButton({
    name = "Window:ChangeTheme({ AccentColor = blue })",
    description = "ChangeTheme takes a partial table, so you can override single keys.",
    callback = function()
        Window:ChangeTheme({
            AccentColor = Color3.fromRGB(96, 160, 255),
            AccentStroke = Color3.fromRGB(150, 200, 255),
        })
        log("Window:ChangeTheme(partial table)")
    end,
})

localeTab:CreateButton({
    name = "Window:ChangeTheme('default')",
    description = "A string names a theme in src/themes. Only 'default' ships today.",
    callback = function()
        Window:ChangeTheme("default")
        log("Window:ChangeTheme('default')")
    end,
})

-- Teardown ------------------------------------------------------------------
local teardownTab = Window:CreateTab({ name = "Teardown", icon = ICON.warn, category = windowCategory })

teardownTab:CreateSection({ name = "Destructive - these do not come back" })

-- A throwaway tab so Tab:Remove has something safe to delete.
local scratchTab = Window:CreateTab({ name = "Scratch", icon = ICON.page, category = windowCategory })
scratchTab:CreateSection({ name = "Delete me from the Teardown tab" })
scratchTab:CreateButton({ name = "I do nothing" })

teardownTab:CreateButton({
    name = "Tab:Remove() the Scratch tab",
    callback = function()
        scratchTab:Remove()
        log("Tab:Remove() - the Scratch tab is gone")
    end,
})

teardownTab:CreateButton({
    name = "Rail:Destroy() the Layout category",
    description = "Removes the rail item. Its tabs stay in the window but lose their category.",
    callback = function()
        layoutCategory:Destroy()
        log("Rail:Destroy() on Layout")
    end,
})

teardownTab:CreateButton({
    name = "Window:Unload()",
    description = "Tears the whole window down. Rerun the script to get it back.",
    callback = function()
        Window:Popup({
            title = "Unload the window?",
            content = "This destroys the UI. You will need to stop and replay to get it back.",
            icon = ICON.warn,
            options = {
                { text = "Cancel", style = "neutral" },
                {
                    text = "Unload",
                    style = "danger",
                    callback = function()
                        log("Window:Unload() - unloaded flag will read", true)
                        Window:Unload()
                    end,
                },
            },
        })
    end,
})

-- Open on the first tab of the first category.
Window:Navigate("Button")

log("tour ready - window.unloaded is", Window.unloaded)
