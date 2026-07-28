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

-- Left icon rail. Items carry no built-in meaning; each is an icon plus a callback.
local railHome = Window:CreateRailItem({
    icon = 85628806611332,
    name = "Home",
    active = true,
    callback = function()
        Window:Navigate("Main")
        print("[AFKTY] rail: home")
    end,
})

-- No Search or Settings item here on purpose: the rail adopts both from the topbar itself,
-- so adding them by hand would show each twice.
local railConfigs = Window:CreateRailItem({
    icon = 125823673784681,
    name = "Configs",
    callback = function()
        railHome:SetActive(false)
        print("[AFKTY] rail: configs")
    end,
})

-- Demonstrates the active state moving between items.
railConfigs.callback = function()
    railHome:SetActive(false)
    railConfigs:SetActive(true)
    print("[AFKTY] rail: configs active")
end

-- Player avatar, pinned bottom. The library draws the headshot and reports the click; what
-- it shows about the account is up to this script.
Window:CreateRailProfile({
    callback = function(profile)
        -- deliberately silent: the library reports the click, the consuming script decides
        -- whether anything is shown at all
        print("[AFKTY] rail: profile", profile.userId)
    end,
})

local Tab = Window:CreateTab({ name = "Main", icon = 93364949241311 })

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

Window:Navigate("Main")
print("[AFKTY] Studio test loaded.")
