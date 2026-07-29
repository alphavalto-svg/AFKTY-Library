# Building a GUI with AFKTY — tutorial

A hands-on walkthrough for writing your own hub against the library. Everything here is taken
from the real API; if something doesn't work, the two demo scripts at the repo root
(`example.client.luau`, `studio.client.luau`) are the ground truth.

---

## 1. Loading the library

**In an executor** — this is what a shipped hub does:

```lua
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/alphavalto-svg/AFKTY-Library/main/dist/Library.lua"))()
```

**In Studio** — there is no executor, so require the module instead:

```lua
local Library = require(game:GetService("ReplicatedStorage").AFKTY)
```

Then wait a moment before building anything:

```lua
task.wait(2)
```

This is not superstition. The window sizes itself to the viewport once, at creation. Build it
before the camera exists and you get the full default size instead of one that fits the screen.

---

## 2. Your first window

```lua
local Window = Library:CreateWindow({
    name = "My Hub",
    subtitle = "Grow a Garden 2",
})
```

That is the whole minimum. You now have a draggable, resizable window with a search field, a
settings tab, minimise and close.

### Window options

| Option | Type | What it does |
|---|---|---|
| `name` | string | Title text |
| `subtitle` | string | Smaller text under the title |
| `icon` | number | Asset id shown left of the title |
| `theme` | string or table | See §8 |
| `resize` | boolean | Bottom-right resize grip. **On by default** — pass `false` for a fixed window |
| `configuration` | table | Config saving, see §7 |
| `locale` | string | Pin the UI language instead of following the player's |
| `translations` | table | Language tables keyed by locale id |
| `showName` / `showIcon` | string / number | Label and icon on the collapsed pill |

Props are lowercase. Capitalised names (`Name`, `Resize`) also work, so old Rayfield-style code
won't break, but prefer lowercase in new scripts.

**Moving the window:** grab the topbar. There is no drag bar under the window any more. Presses
over the tabs or the action icons are ignored, so those still work normally.

---

## 3. Tabs and sections

A tab is a page. A section is a labelled divider inside it.

```lua
local Main = Window:CreateTab({ name = "Farm", icon = 93364949241311 })

Main:CreateSection({ name = "Basics" })
```

Jump to a tab by name:

```lua
Window:Navigate("Farm")
```

Put a coloured chip next to the window title:

```lua
Window:CreateTag({ text = "beta", color = Color3.fromRGB(144, 231, 68) })
```

---

## 4. Elements

Every element takes one table and returns a handle. All of these are methods on a **tab**.

### Button

```lua
Main:CreateButton({
    name = "Start",
    icon = 93364949241311,       -- optional
    callback = function()
        print("clicked")
    end,
})
```

### Toggle

```lua
Main:CreateToggle({
    name = "Auto Farm",
    description = "Runs the farm loop in the background.",   -- optional
    value = true,                                            -- starting state
    flag = "AutoFarm",                                       -- see §7
    callback = function(on)
        print("Auto Farm:", on)
    end,
})
```

`CreateSwitch` is an alias for `CreateToggle` — same element, no difference.

### Slider

```lua
Main:CreateSlider({
    name = "Delay",
    range = { 0, 10 },
    increment = 0.5,
    value = 2,
    suffix = "s",
    flag = "Delay",
    callback = function(n)
        print("Delay:", n)
    end,
})
```

### Dropdown

Single select:

```lua
Main:CreateDropdown({
    name = "Seed",
    options = { "Tomato", "Carrot", "Corn" },
    value = "Tomato",
    flag = "Seed",
    callback = function(choice)
        print("Seed:", choice)
    end,
})
```

Multi select — note `value` becomes a table, and the callback receives a table:

```lua
Main:CreateDropdown({
    name = "Auto Buy",
    multiSelect = true,
    options = { "Tomato", "Carrot", "Corn" },
    value = { "Tomato" },
    placeholder = "None",
    flag = "AutoBuy",
    callback = function(list)
        print("Auto Buy:", table.concat(list, ", "))
    end,
})
```

Rebuild the option list at runtime with `dropdown:Refresh({ "New", "Options" })`.

### Input

```lua
Main:CreateInput({
    name = "Webhook",
    placeholder = "https://...",
    numeric = false,   -- true restricts to numbers
    flag = "Webhook",
    callback = function(text)
        print("Webhook:", text)
    end,
})
```

Commits when you click away or press enter — not on every keystroke.

### Keybind

```lua
Main:CreateKeybind({
    name = "Toggle",
    value = Enum.KeyCode.F,
    flag = "Key",
    callback = function()
        print("pressed")
    end,
})
```

Pass `hold = true` and the callback fires `true` when held and `false` on release.

### Color picker

```lua
Main:CreateColorPicker({
    name = "ESP Color",
    color = Color3.fromRGB(144, 231, 68),
    flag = "Color",
    callback = function(c)
        print("Color:", c)
    end,
})
```

### Stat

A read-only number card that animates when it changes.

```lua
local kills = Main:CreateStat({ name = "Kills", value = 0 })
local cash  = Main:CreateStat({ name = "Revenue", prefix = "$", value = 12400 })

kills:Set(kills.value + 1)
```

---

## 5. Laying elements out side by side

`CreateGroup` is a container. On its own it's a row that wraps. Nest columns inside a row to get
a grid:

```lua
local grid = Main:CreateGroup()

local left = grid:CreateGroup({ direction = "column" })
left:CreateToggle({ name = "Auto Plant", flag = "AutoPlant" })
left:CreateToggle({ name = "Auto Water", flag = "AutoWater" })

local right = grid:CreateGroup({ direction = "column" })
right:CreateToggle({ name = "Auto Sell", flag = "AutoSell" })
right:CreateToggle({ name = "Auto Collect", flag = "AutoCollect" })
```

**Groups support fewer elements than tabs.** A group can hold `CreateButton`, `CreateToggle`,
`CreateSwitch`, `CreateStat`, `CreateSlider`, `CreateDropdown`, `CreateSection` and nested
`CreateGroup`. It has **no** `CreateInput`, `CreateKeybind` or `CreateColorPicker` — put those
directly on the tab.

---

## 6. The icon rail

The rail is the left strip of icons. It is a second level of navigation above tabs:

- **Rail item = main category**
- **Tab = subcategory of one category**

The top tab strip changes with the rail selection.

```lua
local main = Window:CreateRailItem({
    icon = 93364949241311,
    name = "Main",
    callback = function(item)
        item:Select()
    end,
})

local tools = Window:CreateRailItem({ icon = 139478662436110, name = "Tools" })

Window:CreateTab({ name = "Farm",    category = main })
Window:CreateTab({ name = "Shop",    category = main })
Window:CreateTab({ name = "Utility", category = tools })
```

Things the library already handles, so don't write them yourself:

- The first category is selected for you
- `item:Select()` clears the other categories
- Search and settings are **moved** off the topbar into the rail — adding them by hand shows
  each twice
- The emblem at the top is branding, not a button, and can never take the selection

A tab with **no** `category` stays visible under every category. So if you never call
`CreateRailItem`, `CreateTab` behaves exactly as it did before and no rail is built.

Player avatar chip, pinned to the bottom of the rail:

```lua
Window:CreateRailProfile({
    callback = function(profile)
        print("clicked profile", profile.userId)
    end,
})
```

---

## 7. Saving

### Flags

A control saves **only if it has a `flag`**. The flag is the key its value is stored under.

```lua
Main:CreateToggle({ name = "Auto Farm", flag = "AutoFarm" })
```

**Flags must be unique across the whole window.** If you have two toggles both called "Aimbot"
in different tabs, give at least one an explicit distinct flag or the second will clobber the
first:

```lua
left:CreateToggle({ name = "Aimbot", flag = "LoadoutAimbot" })
```

For a control that should never persist — a theme picker, a language switcher — pass
`forgetState = true` instead of a flag.

### Turning config saving on

```lua
local Window = Library:CreateWindow({
    name = "My Hub",
    configuration = {
        autoSave = true,
        autoLoad = true,
        fileName = "MyHubConfig",
    },
})
```

Manual control:

```lua
Window:Save()            -- returns false if it couldn't write
Window:Load()
Window:ListConfigs()
Window:DeleteConfig(name)
```

`autoLoad` applies once, on first open — reloading on every show would wipe changes the player
made and closed without saving.

> **In Studio, `Save()` returns `false`.** Config saving needs an executor's `writefile`, which
> Studio doesn't have. That's expected, not a bug.

Window settings — keybind, cursor unlock, keep-on-screen, haptics, and the window size — save
separately and automatically via `SaveSettings`. You don't call that yourself.

---

## 8. Themes

```lua
Window:ChangeTheme("default")
```

> **Only one theme ships right now: `default`.** The README's list of `amethyst`, `cobalt`,
> `ember`, `frost` and `rose` is stale — those files aren't in `src/themes/`. Passing an unknown
> name logs a warning and falls back to default, so `theme = "cobalt"` in `example.client.luau`
> silently renders as default.

You can pass a partial override table instead of a name. Anything you leave out inherits from
default:

```lua
local Window = Library:CreateWindow({
    name = "My Hub",
    theme = {
        AccentColor = Color3.fromRGB(80, 160, 255),
        AccentStroke = Color3.fromRGB(140, 200, 255),
    },
})
```

If you recolour a surface but don't set its stroke, a sensible stroke is derived for you.

---

## 9. Feedback

```lua
Window:Notify({
    title = "Auto-saved",
    content = "Your configuration was saved.",
    icon = 139478662436110,
})

Window:Toast({ title = "Saved", icon = 139478662436110 })

Window:Popup({
    title = "Reset everything?",
    content = "This clears every saved value. You can't undo it.",
    options = {
        { text = "Cancel" },
        { text = "Reset", style = "danger" },
    },
})
```

Notifications are bottom-right cards. Toasts are small and centred. Popups are modal and block
the window until answered.

---

## 10. Window control

```lua
Window:Hide()             -- collapse to the pill
Window:Show()
Window:ToggleMinimise()   -- collapse to the bar
Window:Unload()           -- tear the whole thing down
```

The player can also toggle the menu with **K** by default, rebindable in the settings tab.

---

## 11. A complete starter script

Copy this, change the names, and you have a working hub.

```lua
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/alphavalto-svg/AFKTY-Library/main/dist/Library.lua"))()

task.wait(2)

local Window = Library:CreateWindow({
    name = "My Hub",
    subtitle = "Grow a Garden 2",
    configuration = {
        autoSave = true,
        autoLoad = true,
        fileName = "MyHubConfig",
    },
})

Window:CreateTag({ text = "v1", color = Color3.fromRGB(144, 231, 68) })

-- Categories (left rail)
local farming = Window:CreateRailItem({ icon = 93364949241311, name = "Farming" })
local tools   = Window:CreateRailItem({ icon = 139478662436110, name = "Tools" })

-- Subcategories (top strip)
local Seeds   = Window:CreateTab({ name = "Seeds",   category = farming })
local Selling = Window:CreateTab({ name = "Selling", category = farming })
local Misc    = Window:CreateTab({ name = "Misc",    category = tools })

Window:CreateRailProfile({})

-- Seeds page
Seeds:CreateSection({ name = "Automation" })

Seeds:CreateToggle({
    name = "Auto Plant",
    flag = "AutoPlant",
    callback = function(on)
        print("Auto Plant:", on)
    end,
})

Seeds:CreateDropdown({
    name = "Seed",
    options = { "Tomato", "Carrot", "Corn" },
    value = "Tomato",
    flag = "Seed",
    callback = function(seed)
        print("Seed:", seed)
    end,
})

Seeds:CreateSlider({
    name = "Delay",
    range = { 0, 10 },
    increment = 0.5,
    value = 2,
    suffix = "s",
    flag = "Delay",
})

-- Selling page
Selling:CreateSection({ name = "Shop" })

Selling:CreateToggle({ name = "Auto Sell", flag = "AutoSell" })

Selling:CreateButton({
    name = "Sell Now",
    callback = function()
        Window:Notify({ title = "Sold", content = "Inventory sold." })
    end,
})

-- Misc page
Misc:CreateSection({ name = "Misc" })

Misc:CreateKeybind({ name = "Panic", value = Enum.KeyCode.P, flag = "Panic" })
Misc:CreateColorPicker({ name = "ESP Colour", color = Color3.fromRGB(144, 231, 68), flag = "ESPColour" })

Window:Navigate("Seeds")
```

---

## 12. Gotchas

| Trap | What happens |
|---|---|
| No `task.wait` before `CreateWindow` | The window sizes to a viewport that doesn't exist yet and opens at full default size |
| Two controls sharing a flag | The second silently clobbers the first's saved value |
| No flag on a control | It never saves, no warning |
| `CreateInput` on a group | Not implemented — put it on the tab |
| Adding search or settings to the rail | They appear twice; the rail adopts the topbar's own |
| `Save()` in Studio | Returns `false` — needs an executor filesystem |
| Unknown theme name | Warns and falls back to default; only `default` exists today |

---

## Where to look next

- `example.client.luau` — every element, localisation, groups, stats
- `studio.client.luau` — the rail, categories and subcategories
- `README.md` — build steps and secure mode (its theme list is out of date)
