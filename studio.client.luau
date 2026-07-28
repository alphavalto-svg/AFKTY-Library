--[[
	AFKTY Library - Studio test client.

	Same coverage as HUB/AFKTY-Quick.lua, but requires the library from
	ReplicatedStorage instead of loadstring+HttpGet, since Studio has no executor.

	Expected to NOT work in Studio (needs executor globals):
	  - secure mode      (no getgenv)
	  - config save/load (no writefile/readfile) -- Save() returns false
	Everything else -- window, tabs, every element, themes, notifications -- is live.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Library = require(ReplicatedStorage.AFKTY)

-- let the viewport settle so the window sizes to the full screen
task.wait(2)

local Window = Library:CreateWindow({
    name = "AFKTY Hub",
    subtitle = "Grow a Garden 2",
    configuration = { autoSave = true, autoLoad = true, fileName = "AFKTY Hub" },
})

Window:CreateTag({ text = "studio", color = Color3.fromRGB(144, 231, 68) })

-- Left icon rail: category buttons. The emblem is deliberately not one of these -- it reads
-- as branding, and making it the default selection meant the menu opened on a button that
-- did not correspond to the page actually being shown.
--
-- No Search or Settings here either: the rail adopts both from the topbar itself, so adding
-- them by hand would show each twice.
-- The library selects the first category automatically and :Select() clears the siblings,
-- so a consuming script never tracks which one was previously active.
local mainCategory = Window:CreateRailItem({
    icon = 93364949241311,
    name = "Main",
    callback = function(item)
        item:Select()
        print("[AFKTY] category: main")
    end,
})

local toolsCategory = Window:CreateRailItem({
    icon = 125823673784681,
    name = "Tools",
    callback = function(item)
        item:Select()
        print("[AFKTY] category: tools")
    end,
})

-- Player avatar, pinned bottom. The library draws the headshot and reports the click; what
-- it shows about the account is up to this script.
Window:CreateRailProfile({
    callback = function(profile)
        -- deliberately silent: the library reports the click, the consuming script decides
        -- whether anything is shown at all
        print("[AFKTY] rail: profile", profile.userId)
    end,
})
-- Subcategories. Each tab belongs to one main category, so the top strip changes with the
-- rail selection instead of showing every tab under every category.
local Tab = Window:CreateTab({ name = "Farm", icon = 93364949241311, category = mainCategory })
local Tab2 = Window:CreateTab({ name = "Shop", icon = 125823673784681, category = mainCategory })
local ToolsTab = Window:CreateTab({ name = "Utility", icon = 129180860773723, category = toolsCategory })

Tab2:CreateSection({ name = "Shop" })
Tab2:CreateButton({
    name = "Buy Seeds",
    callback = function()
        print("buy")
    end,
})

ToolsTab:CreateSection({ name = "Utility" })
ToolsTab:CreateToggle({ name = "Noclip", flag = "Noclip" })

Tab:CreateSection({ name = "Basics" })

Tab:CreateButton({
    name = "Start",
    callback = function()
        Window:Notify({ title = "Loading...", content = "Script Loaded." })
    end,
})

Tab:CreateToggle({
    name = "Auto Farm",
    flag = "AutoFarm",
    callback = function(v)
        print("Auto Farm:", v)
    end,
})

Tab:CreateSlider({
    name = "Delay",
    range = { 0, 10 },
    increment = 0.5,
    value = 2,
    suffix = "s",
    flag = "Delay",
    callback = function(v)
        print("Delay:", v)
    end,
})

Tab:CreateSection({ name = "Dropdowns" })

Tab:CreateDropdown({
    name = "Seed",
    options = { "Tomato", "Carrot", "Corn" },
    value = "Tomato",
    flag = "Seed",
    callback = function(v)
        print("Seed:", v)
    end,
})

Tab:CreateDropdown({
    name = "Auto Buy",
    multiSelect = true,
    options = { "Tomato", "Carrot", "Corn" },
    value = { "Tomato" },
    placeholder = "None",
    flag = "AutoBuy",
    callback = function(v)
        print("Auto Buy:", table.concat(v, ", "))
    end,
})

Tab:CreateSection({ name = "Fields" })

Tab:CreateInput({
    name = "Webhook",
    placeholder = "https://...",
    flag = "Webhook",
    callback = function(v)
        print("Webhook:", v)
    end,
})

Tab:CreateKeybind({
    name = "Toggle",
    value = Enum.KeyCode.F,
    flag = "Key",
    callback = function()
        print("Key pressed")
    end,
})

Tab:CreateColorPicker({
    name = "ESP Color",
    color = Color3.fromRGB(144, 231, 68),
    flag = "Color",
    callback = function(v)
        print("Color:", v)
    end,
})

Tab:CreateSection({ name = "Layout" })

local grid = Tab:CreateGroup()
local left = grid:CreateGroup({ direction = "column" })
left:CreateToggle({ name = "Auto Plant", flag = "AutoPlant" })
left:CreateToggle({ name = "Auto Water", flag = "AutoWater" })
local right = grid:CreateGroup({ direction = "column" })
right:CreateToggle({ name = "Auto Sell", flag = "AutoSell" })
right:CreateToggle({ name = "Auto Collect", flag = "AutoCollect" })

Tab:CreateSection({ name = "Themes + Feedback" })

Tab:CreateDropdown({
    name = "Theme",
    options = { "default" },
    value = "default",
    forgetState = true,
    callback = function(v)
        Window:ChangeTheme(v)
        print("Theme:", v)
    end,
})

Tab:CreateButton({
    name = "Toast + Popup",
    callback = function()
        Window:Toast({ title = "Saved" })
        Window:Popup({
            title = "Reset?",
            content = "Clears every saved value.",
            options = { { text = "Cancel" }, { text = "Reset", style = "danger" } },
        })
    end,
})

Tab:CreateButton({
    name = "Save Config (expect false in Studio)",
    callback = function()
        print("Save ->", Window:Save())
    end,
})

Window:Navigate("Farm")
