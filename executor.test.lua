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

	NOTHING IS PRINTED TO THE CONSOLE
	  This script's output goes to a buffer, read back from the "Show log" button. A game
	  LocalScript can hook LogService.MessageOut and read every print any script makes,
	  executor scripts included, and LogService:GetLogHistory() hands it the backlog too.

	  Verified on a live client against a simulated game-side detector: the library itself
	  emitted nothing in secure mode, even through a callback that threw. The only readable
	  trace was this script's own prints. Set LOG_TO_CONSOLE = true while debugging.

	  The one console check that remains deliberate is "Is the library silent?" -- that one is
	  testing the LIBRARY's output, so you do want to watch the real console for it.

	SECURE MODE
	  The library defaults it ON in any executor that can serve the icon cache (getcustomasset
	  plus isfile), so SECURE is true here to match. Set it false to opt out and compare.

	  It must be set BEFORE the library loads either way - runtime.luau reads
	  getgenv().AFKTY_SECURE once at module load, so setting it afterwards does nothing. In
	  secure mode the library caches icons to disk instead of using asset ids. Note the brand
	  font does NOT swap in secure mode -- you get the BuilderSans fallback, because
	  constants.fontAsset is a built-in rbxasset:// path rather than a numeric id that
	  fontManager can resolve. Both are built-in faces, so nothing leaks either way.
]]

local SECURE = true -- <-- set false to compare against normal mode

-- guarded the same way runtime.luau checks it, so running this outside an executor fails
-- with a clear message instead of "attempt to call a nil value"
if typeof(getgenv) ~= "function" then
    warn("[AFKTY TEST] no getgenv() here - this script needs a real executor")
    return
end

-- set explicitly either way rather than relying on the default, so the run is unambiguous
getgenv().AFKTY_SECURE = SECURE

local URL = "https://raw.githubusercontent.com/alphavalto-svg/AFKTY-Library/main/dist/Library.lua"

-- Output goes to a buffer, not the console. A game LocalScript can hook LogService.MessageOut
-- and read every print any script makes, executor scripts included, and GetLogHistory() hands it
-- the backlog too. Verified on a live client: the library is silent in secure mode, and this
-- script's own prints were the only thing a detector could see. Read them from the Log section
-- in the UI, or flip this while debugging.
local LOG_TO_CONSOLE = false

local lines = {}

local function log(...)
    local parts = {}
    for i = 1, select("#", ...) do
        table.insert(parts, tostring((select(i, ...))))
    end
    local line = table.concat(parts, " ")
    table.insert(lines, line)
    if #lines > 250 then
        table.remove(lines, 1)
    end
    if LOG_TO_CONSOLE then
        print("[AFKTY TEST]", line)
    end
end

local ok, Library = pcall(function()
    local chunk, parseError = loadstring(game:HttpGet(URL))
    assert(chunk, "the bundle did not parse: " .. tostring(parseError))
    return chunk()
end)

if not ok then
    -- the library is what failed, so there is no UI to report into. Still gated: a failed load
    -- is obvious anyway (no window appears), and silence is the safe default.
    if LOG_TO_CONSOLE then
        warn("[AFKTY TEST] failed to load the library:", Library)
    end
    return
end

log("library loaded. secure mode =", SECURE)

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

-- The avatar chip takes a different secure-mode path from the icons: image.avatar caches to
-- avatar_<userId>.png rather than <id>.png. Without one on screen that branch never runs, so
-- the disk check below would only ever prove half of it.
Window:CreateRailProfile({
    callback = function(profile)
        log("rail profile clicked, userId =", profile.userId)
    end,
})

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
-- What secure mode actually changes, and how you can see each one:
--   1. Icons are downloaded, written to AFKTY/Assets/<id>.png and loaded back through
--      getcustomasset, so no asset id ever goes out over the wire. Visible as files.
--   2. Avatars the same way, as avatar_<userId>.png.
--   3. The brand font is fetched off the main thread; until it lands you get the fallback
--      family, so the first moment after open looks plainer.
--   4. The library stops logging entirely -- log.warn/log.print are gagged, so any AFKTY
--      warning you would normally see in the console is silent.
tab:CreateSection({ name = "Secure mode" })

tab:CreateButton({
    name = "Can this executor do secure mode?",
    description = "Caching needs all three. Missing any one and preload bails and icons stay as plain asset ids.",
    callback = function()
        log("AFKTY_SECURE set by this script =", typeof(getgenv) == "function" and getgenv().AFKTY_SECURE)
        log("getcustomasset =", typeof(getcustomasset) == "function")
        log("isfile =", typeof(isfile) == "function")
        log("listfiles =", typeof(listfiles) == "function")
    end,
})

tab:CreateButton({
    name = "Did icons actually cache to disk?",
    description = "The real proof. In secure mode this folder fills with .png files; with it off it stays empty.",
    callback = function()
        if typeof(listfiles) ~= "function" then
            log("no listfiles() in this executor - can't check")
            return
        end
        local folder = "AFKTY/Assets"
        local listed, files = pcall(listfiles, folder)
        if not listed then
            log("no", folder, "folder yet - nothing has cached")
            return
        end
        local icons, avatars = 0, 0
        for _, file in files do
            if string.find(file, "avatar_", 1, true) then
                avatars += 1
            elseif string.sub(file, -4) == ".png" then
                icons += 1
            end
        end
        log(("%s: %d icon(s), %d avatar(s)"):format(folder, icons, avatars))
        for i = 1, math.min(#files, 5) do
            log("  ", files[i])
        end
        Window:Notify({
            title = if icons + avatars > 0 then "Icons are cached" else "Nothing cached",
            content = ("%d icon(s), %d avatar(s) in %s"):format(icons, avatars, folder),
        })
    end,
})

tab:CreateButton({
    name = "Is the library silent?",
    description = "Forces a library-side warning. Secure mode gags it, so an empty console is the pass. Check the real console for this one - it is the library being tested, not this script.",
    callback = function()
        -- an unknown theme name makes the library log.warn and fall back. With secure mode on
        -- that warning is suppressed; with it off you get "AFKTY: unknown theme ..."
        Window:ChangeTheme("definitely-not-a-real-theme")
        log("asked for a bogus theme. secure ON = no AFKTY warning in the console")
        log("secure OFF = you should see 'AFKTY: unknown theme' there")
        Window:ChangeTheme("default")
    end,
})

-- Log ------------------------------------------------------------------------
-- Everything this script would have printed. Popup's box layout is a scrolling list of cards,
-- which is the shape a log wants, and it is public API rather than rewriting element internals.
tab:CreateSection({ name = "Log - nothing goes to the console" })

tab:CreateButton({
    name = "Show log",
    description = "The last 12 lines this script recorded.",
    icon = 139478662436110,
    callback = function()
        if #lines == 0 then
            Window:Toast({ title = "Log is empty" })
            return
        end
        local boxes = {}
        for i = math.max(1, #lines - 11), #lines do
            table.insert(boxes, { title = "#" .. i, description = lines[i] })
        end
        Window:Popup({
            title = "Script log",
            subtitle = string.format("%d line(s) recorded, newest last", #lines),
            boxes = boxes,
        })
    end,
})

Window:Notify({
    title = "Executor test loaded",
    content = "Change something, Save, then rejoin and run again.",
})

log("ready. config path:", Window:GetPath())
