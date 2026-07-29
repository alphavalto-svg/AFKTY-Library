--[[
	AFKTY Library - real executor smoke test.

	Paste into your executor and run. This deliberately targets the two things Studio
	structurally cannot test, because the rest is already covered by studio.tour.client.luau:

	  1. Secure mode  - needs getgenv(), which Studio does not have
	  2. Real persistence - needs writefile/readfile, so config survives a rejoin

	HOW TO USE
	  Run once. Change some toggles/sliders, hit "Save config", then REJOIN the game and
	  run it again. If autoLoad worked, your values come back. That round trip is the
	  thing that has never actually been verified.

	SECURE MODE
	  Flip SECURE to true below. It must be set BEFORE the library loads - runtime.luau
	  reads getgenv().AFKTY_SECURE once at module load, so setting it afterwards does
	  nothing. In secure mode the library caches icons to disk instead of using asset ids,
	  and downloads the brand font in the background. Expect a brief plain-font moment.
]]

local SECURE = false -- <-- flip to true to test secure mode

if SECURE then
    -- guarded the same way runtime.luau checks it, so flipping this outside an executor
    -- fails with a clear message instead of "attempt to call a nil value"
    if typeof(getgenv) ~= "function" then
        warn("[AFKTY TEST] no getgenv() here - secure mode needs a real executor")
        return
    end
    getgenv().AFKTY_SECURE = true
end

local URL = "https://raw.githubusercontent.com/alphavalto-svg/AFKTY-Library/main/dist/Library.lua"

local ok, Library = pcall(function()
    return loadstring(game:HttpGet(URL))()
end)

if not ok then
    warn("[AFKTY TEST] failed to load the library:", Library)
    return
end

print("[AFKTY TEST] library loaded. secure mode =", SECURE)

local function log(...)
    print("[AFKTY TEST]", ...)
end

local Window = Library:CreateWindow({
    name = "AFKTY Executor Test",
    subtitle = if SECURE then "secure mode ON" else "secure mode off",
    configuration = {
        autoSave = true, -- writes on every change to a flagged control
        autoLoad = true, -- reads it back when this window opens
        fileName = "ExecutorTest",
    },
})

Window:CreateTag({ text = if SECURE then "secure" else "normal" })

local tab = Window:CreateTab({ name = "Persistence", icon = 93364949241311 })

-- Flagged controls. These are what get written to disk, so change them before saving.
tab:CreateSection({ name = "Change these, then rejoin" })

tab:CreateToggle({ name = "Toggle A", flag = "TestToggleA" })
tab:CreateToggle({ name = "Toggle B", flag = "TestToggleB", value = true })
tab:CreateSlider({ name = "Number", flag = "TestSlider", range = { 0, 100 }, value = 25, suffix = "%" })
tab:CreateInput({ name = "Text", flag = "TestInput", placeholder = "type something" })
tab:CreateDropdown({
    name = "Choice",
    flag = "TestDropdown",
    options = { "One", "Two", "Three" },
    value = "One",
})
tab:CreateColorPicker({ name = "Colour", flag = "TestColor", color = Color3.fromRGB(144, 231, 68) })

-- Disk ----------------------------------------------------------------------
tab:CreateSection({ name = "Disk" })

tab:CreateButton({
    name = "Where is the file?",
    callback = function()
        log("path:", Window:GetPath())
    end,
})

tab:CreateButton({
    name = "Save config",
    callback = function()
        local saved = Window:Save()
        log("Save() ->", saved)
        Window:Notify({
            title = if saved then "Saved" else "Save failed",
            content = Window:GetPath(),
        })
    end,
})

tab:CreateButton({
    name = "Load config",
    callback = function()
        log("Load() ->", Window:Load())
    end,
})

tab:CreateButton({
    name = "Read the file back",
    description = "Proves it actually hit the disk, not just memory.",
    callback = function()
        local path = Window:GetPath()
        if not isfile or not isfile(path) then
            log("no file at", path)
            return
        end
        log("file contents:", readfile(path))
    end,
})

tab:CreateButton({
    name = "Named config round trip",
    callback = function()
        log("Save('Slot1') ->", Window:Save("Slot1"))
        log("ListConfigs() ->", table.concat(Window:ListConfigs(), ", "))
        log("Load('Slot1') ->", Window:Load("Slot1"))
        log("DeleteConfig('Slot1') ->", Window:DeleteConfig("Slot1"))
    end,
})

-- Secure mode ---------------------------------------------------------------
tab:CreateSection({ name = "Secure mode" })

tab:CreateButton({
    name = "Report secure mode state",
    description = "Icons should render either way; in secure mode they come from disk.",
    callback = function()
        log("AFKTY_SECURE =", getgenv and getgenv().AFKTY_SECURE)
        log("gethui available =", typeof(gethui) == "function")
        log("getcustomasset available =", typeof(getcustomasset) == "function")
    end,
})

Window:Notify({
    title = "Executor test loaded",
    content = "Change something, Save, then rejoin and run again.",
})

log("ready. config path:", Window:GetPath())
