--[[
	AFKTY Library - full executor tour.

	The executor counterpart to studio.tour.client.luau. Paste it into your executor and run.

	It does two jobs at once:

	  1. AUTOMATED CHECKS. Everything that can be asserted without a human is asserted on load
	     and collected onto the Checks tab. Read that tab first -- if something is broken it
	     will say so there rather than making you hunt.

	  2. FULL API COVERAGE. Every public call the library exposes, each behind a labelled
	     control that records a [TOUR] line naming the method that ran.

	NOTHING IS PRINTED TO THE CONSOLE
	  Output goes to an in-memory buffer, readable from Session -> Show log. This is not
	  fussiness: a game LocalScript can hook LogService.MessageOut and read every print any
	  script makes, executor scripts included, and LogService:GetLogHistory() hands it the
	  backlog as well -- so a line stays readable long after it scrolled past.

	  Tested against this library on a live client with a simulated game-side detector. The
	  library itself emitted nothing at all in secure mode, through a bogus theme name, a
	  duplicate flag, an uncached icon and a hub callback that threw. The only thing the
	  detector could see was this script's own chatter. Hence the buffer.

	  Set LOG_TO_CONSOLE = true below when you are debugging and want it in the console.

	HOW TO USE
	  Run it. SECURE is true by default, matching what a shipped hub now gets. Set it false and
	  run again to compare -- the Checks tab reports different things in each mode.

	  For the persistence round trip: change some flagged controls, hit "Save config", REJOIN
	  the game, and run again. autoLoad should bring your values back.

	SECURE MODE
	  The library defaults it ON in any executor that can serve the icon cache (getcustomasset
	  plus isfile). Set getgenv().AFKTY_SECURE = false to opt out, or = true to force it even
	  where caching is unavailable, which blanks uncached icons rather than leaking asset ids.

	  It must be set BEFORE the library loads either way. runtime.luau reads it once at module
	  load, so setting it afterwards does nothing at all.

	  Expect a quieter console: secure mode gags the library's own warn/print. That is the
	  point, but it does mean a misconfiguration says nothing. Run with SECURE = false if you
	  are chasing something and want the library talking.

	WHAT THIS SUPERSEDES
	  executor.test.lua is the short smoke test -- secure mode and persistence only. This file
	  is the exhaustive one. Either is fine; this one tells you more.
]]

-- The library now defaults secure mode ON in any executor that can serve the icon cache, so
-- leaving this true matches what a shipped hub actually gets. Set it false to compare.
local SECURE = true

if typeof(getgenv) ~= "function" then
    warn("[AFKTY TOUR] no getgenv() here - this script needs a real executor")
    return
end

-- Set explicitly either way rather than relying on the default, so the run is unambiguous:
-- true is the strict opt-in, false is the opt-out.
getgenv().AFKTY_SECURE = SECURE

local URL = "https://raw.githubusercontent.com/alphavalto-svg/AFKTY-Library/main/dist/Library.lua"

-- ===========================================================================
-- Results plumbing
--
-- Nothing here reaches the console by default, and that is deliberate. A game LocalScript can
-- hook LogService.MessageOut and read every print any script makes, executor scripts included,
-- and LogService:GetLogHistory() hands it the backlog too -- so output survives long after the
-- line scrolled away. Verified against this library on a live client: the library itself stays
-- completely silent in secure mode, and the only thing a detector could see was this script's
-- own [TOUR] chatter sitting in the log.
--
-- So output goes to a buffer and is read back through the UI (Session -> Show log). Flip
-- LOG_TO_CONSOLE when you are debugging and would rather have it in the console.
-- ===========================================================================

local LOG_TO_CONSOLE = false

local results = {}
local passed, failed = 0, 0
local lines = {}
local LINE_CAP = 250

local function emit(text)
    table.insert(lines, text)
    if #lines > LINE_CAP then
        table.remove(lines, 1)
    end
    if LOG_TO_CONSOLE then
        print(text)
    end
end

local function log(...)
    local parts = {}
    for i = 1, select("#", ...) do
        table.insert(parts, tostring((select(i, ...))))
    end
    emit("[TOUR] " .. table.concat(parts, " "))
end

local function check(name, ok, detail)
    if ok then
        passed += 1
    else
        failed += 1
    end
    table.insert(results, { name = name, ok = ok, detail = detail })
    emit(string.format("[%s] %s%s", ok and "PASS" or "FAIL", name, detail and (" - " .. detail) or ""))
end

-- Some checks are only meaningful in one mode. Recording them as skipped keeps the summary
-- honest instead of inflating the pass count with things that never ran.
local function skip(name, why)
    table.insert(results, { name = name, ok = nil, detail = why })
    emit(string.format("[SKIP] %s - %s", name, why))
end

-- A note attached only when the check failed. `cond and nil or text` looks like it does this
-- but always yields text, since `true and nil` is nil and `nil or text` is text.
local function note(cond, text)
    return if cond then nil else text
end

local env = getfenv()

local function hasGlobal(name)
    local ok, value = pcall(function()
        return env[name]
    end)
    return ok and typeof(value) == "function"
end

-- ===========================================================================
-- 1. Environment probe -- run BEFORE loading, so a missing global is attributed
--    to the executor rather than looking like a library fault
-- ===========================================================================

log("environment probe")

local canFile = hasGlobal("isfile") and hasGlobal("readfile") and hasGlobal("writefile")
local canCustomAsset = hasGlobal("getcustomasset")
local canList = hasGlobal("listfiles")
local canRequest = hasGlobal("request") or hasGlobal("http_request")
local hasGetHui = hasGlobal("gethui")
local hasCloneref = hasGlobal("cloneref")

check("executor: filesystem (isfile/readfile/writefile)", canFile)
check("executor: getcustomasset", canCustomAsset)
check("executor: listfiles", canList)
check("executor: http request function", canRequest)
check("executor: getgenv", hasGlobal("getgenv"))
check("executor: cloneref", hasCloneref, note(hasCloneref, "optional, services are used raw without it"))
check("executor: gethui", hasGetHui, note(hasGetHui, "optional, falls back to protect + RobloxGui"))

-- Secure mode caching needs all three of these together. Without any one of them preload bails
-- and every icon stays a plain asset id, which is the thing secure mode exists to avoid.
local secureCapable = canCustomAsset and canFile and canList
if SECURE then
    check("secure mode is supported by this executor", secureCapable, note(secureCapable, "caching will bail"))
else
    skip("secure mode support", "running with SECURE = false")
end

-- ===========================================================================
-- 2. Load
-- ===========================================================================

local ok, Library = pcall(function()
    -- loadstring hands back nil plus a message when the body does not parse, so a truncated
    -- or error-page response fails here with something readable instead of "call a nil value"
    local chunk, parseError = loadstring(game:HttpGet(URL))
    assert(chunk, "the bundle did not parse: " .. tostring(parseError))
    return chunk()
end)

check("library loads from the CDN", ok, note(ok, tostring(Library)))
if not ok then
    -- There is no UI to report into when the library is what failed, so this is the one place
    -- the console is the only channel. It stays gated: silence is the safe default, and a load
    -- failure is visible anyway (no window appears). Flip LOG_TO_CONSOLE to see why.
    if LOG_TO_CONSOLE then
        warn("[AFKTY TOUR] cannot continue: " .. tostring(Library))
    end
    return
end

log("library loaded, secure mode =", SECURE)

task.wait(2) -- let the viewport settle, or the window sizes against a camera that isn't there

-- ===========================================================================
-- 3. Window -- every WindowProps field, so each one's effect is visible in one place
-- ===========================================================================

-- The library's own icons. All ten are AlphaValto uploads as of the 2026-07-29 asset swap,
-- and all ten are what secure mode caches to disk.
local ICON = {
    close = 90172788330629,
    minimise = 136031305763694,
    maximise = 134279979385460,
    settings = 123873302071776,
    search = 102529133382626,
    chevron = 104706369326409,
    check = 95316442098951,
    dot = 95965547856004,
    config = 139478662436110,
    emblem = 85628806611332,
}

-- A real, valid asset that is deliberately NOT in the library's cached set. Renders normally
-- with secure mode off; in secure mode it must resolve blank AND raise the blocked-icon
-- notification. That notification is the thing this id exists to prove.
local UNCACHED_ICON = 93364949241311

local Window = Library:CreateWindow({
    name = "AFKTY Executor Tour",
    subtitle = if SECURE then "secure mode ON" else "secure mode off",
    icon = ICON.emblem,
    showName = "Executor Tour", -- label on the collapsed pill after Hide()
    showIcon = ICON.emblem,
    resize = true, -- bottom-right grip; this is the default, false removes it
    theme = "default",
    locale = "en",
    translations = {
        fr = { ["Buttons"] = "Boutons", ["Toggles"] = "Bascules" },
    },
    configuration = {
        autoSave = true,
        autoLoad = true,
        fileName = "ExecutorTour",
    },
})

check("CreateWindow returned a handle", typeof(Window) == "table")
check("window is not unloaded", Window.unloaded == false)

local tag = Window:CreateTag({ text = if SECURE then "secure" else "normal", color = Color3.fromRGB(144, 231, 68) })

-- ===========================================================================
-- 4. Where did the ScreenGui land?
--
--    This is the one piece of the library with real consequences if it regresses: a ScreenGui
--    the game can enumerate is the most detectable thing a UI library does. gethui() hands back
--    a container the game cannot walk; without it the ScreenGui itself goes through the protect
--    call and then RobloxGui.
-- ===========================================================================

local function findOurGui()
    -- the window's ScreenGui carries DisplayOrder 99999 and a GUID name
    local candidates = {}
    if hasGetHui then
        local hui = select(2, pcall(gethui))
        if hui then
            table.insert(candidates, { name = "gethui()", container = hui })
        end
    end
    local coreGui = game:GetService("CoreGui")
    local robloxGui = coreGui:FindFirstChild("RobloxGui")
    if robloxGui then
        table.insert(candidates, { name = "CoreGui.RobloxGui", container = robloxGui })
    end
    table.insert(candidates, { name = "CoreGui (exposed!)", container = coreGui })

    for _, candidate in candidates do
        local listed, children = pcall(function()
            return candidate.container:GetChildren()
        end)
        if listed then
            for _, child in children do
                if child:IsA("ScreenGui") and child.DisplayOrder == 99999 then
                    return candidate.name
                end
            end
        end
    end
    return nil
end

local guiHome = findOurGui()
if guiHome then
    -- landing in raw CoreGui is the failure case: a game script walking CoreGui:GetChildren()
    -- finds us there, which is exactly what the gethui/protect/RobloxGui chain exists to avoid
    local hidden = guiHome ~= "CoreGui (exposed!)"
    check("ScreenGui is out of the game's reach", hidden, "parented to " .. guiHome)
else
    skip("ScreenGui location", "could not be identified from outside the library")
end

-- ===========================================================================
-- 5. Rail -- main categories. Each tab below belongs to exactly one, so the top strip
--    changes with the rail selection.
-- ===========================================================================

local catChecks = Window:CreateRailItem({
    icon = ICON.check,
    name = "Checks",
    callback = function(item)
        item:Select()
        log("Rail:Select() -> Checks")
    end,
})

local catElements = Window:CreateRailItem({
    icon = ICON.dot,
    name = "Elements",
    callback = function(item)
        item:Select()
        log("Rail:Select() -> Elements")
    end,
})

local catLayout = Window:CreateRailItem({
    icon = ICON.chevron,
    name = "Layout",
    callback = function(item)
        item:Select()
        log("Rail:Select() -> Layout")
    end,
})

local catWindow = Window:CreateRailItem({
    icon = ICON.settings,
    name = "Window",
    callback = function(item)
        item:Select()
        log("Rail:Select() -> Window")
    end,
})

local profile = Window:CreateRailProfile({
    callback = function(self)
        log("CreateRailProfile callback, userId =", self.userId)
    end,
})

check("CreateRailItem returned handles", typeof(catChecks) == "table" and typeof(catElements) == "table")
check("the first category selected itself", catChecks.active == true, "the library picks one so a hub doesn't have to")
check("CreateRailProfile returned a handle", typeof(profile) == "table")

-- ===========================================================================
-- 6. Checks tab
-- ===========================================================================

local checksTab = Window:CreateTab({ name = "Results", icon = ICON.check, category = catChecks })

checksTab:CreateSection({ name = string.format("%d passed, %d failed", passed, failed) })

for _, entry in results do
    local mark = if entry.ok == nil then "[skip]" elseif entry.ok then "[pass]" else "[FAIL]"
    checksTab:CreateButton({
        name = mark .. " " .. entry.name,
        description = entry.detail,
        callback = function()
            log(mark, entry.name, entry.detail or "")
        end,
    })
end

-- Assets -------------------------------------------------------------------
local assetTab = Window:CreateTab({ name = "Assets", icon = ICON.config, category = catChecks })

assetTab:CreateSection({ name = "Icon cache" })

-- Every id the library owns, and every id it used to use. In secure mode the first set must
-- appear on disk and the second must not -- that is the proof the 2026-07-29 swap is live in
-- the bundle you just loaded, not merely in the repo.
local NEW_IDS = {
    "90172788330629",
    "136031305763694",
    "134279979385460",
    "123873302071776",
    "102529133382626",
    "104706369326409",
    "95316442098951",
    "95965547856004",
    "139478662436110",
    "85628806611332",
}

local OLD_IDS = {
    "83277910885129",
    "108115485663409",
    "88738500661569",
    "129180860773723",
    "100604009889706",
    "88479147175134",
    "125626312718314",
    "91452555903853",
    "125823673784681",
}

local function auditAssetCache(announce)
    if not canList then
        skip("icon cache audit", "no listfiles() in this executor")
        return
    end

    local listed, files = pcall(listfiles, "AFKTY/Assets")
    if not listed or typeof(files) ~= "table" then
        if SECURE then
            check("AFKTY/Assets exists", false, "secure mode should have created it")
        else
            skip("icon cache audit", "nothing caches with secure mode off")
        end
        return
    end

    local blob = table.concat(files, "|")
    local foundNew, foundOld, avatars = 0, 0, 0
    local missing = {}

    for _, id in NEW_IDS do
        if string.find(blob, id, 1, true) then
            foundNew += 1
        else
            table.insert(missing, id)
        end
    end
    for _, id in OLD_IDS do
        if string.find(blob, id, 1, true) then
            foundOld += 1
        end
    end
    for _, file in files do
        if string.find(file, "avatar_", 1, true) then
            avatars += 1
        end
    end

    log(string.format("AFKTY/Assets: %d files, %d/10 owned icons, %d avatars", #files, foundNew, avatars))

    if SECURE then
        -- a cold first run downloads in the background, so a partial count is not a failure
        check(
            "owned icons cached to disk",
            foundNew > 0,
            string.format("%d/10 present%s", foundNew, #missing > 0 and (", still missing " .. #missing) or "")
        )
        check("no superseded icon ids on disk", foundOld == 0, note(foundOld == 0, foundOld .. " stale file(s)"))
    else
        skip("icon cache audit", "secure mode off, nothing is expected to cache")
    end

    if announce then
        Window:Notify({
            title = "Icon cache",
            content = string.format("%d files, %d/10 owned icons, %d avatars", #files, foundNew, avatars),
            icon = ICON.config,
        })
    end
end

auditAssetCache(false)

assetTab:CreateButton({
    name = "Re-audit the icon cache",
    description = "Secure mode downloads in the background, so a cold first run may be partial. Run again after a few seconds.",
    callback = function()
        auditAssetCache(true)
    end,
})

assetTab:CreateButton({
    name = "List AFKTY/Assets",
    callback = function()
        if not canList then
            log("no listfiles() in this executor")
            return
        end
        local listed, files = pcall(listfiles, "AFKTY/Assets")
        if not listed then
            log("no AFKTY/Assets folder yet")
            return
        end
        log(#files .. " file(s):")
        for _, file in files do
            log("  ", file)
        end
    end,
})

-- Persistence --------------------------------------------------------------
local diskTab = Window:CreateTab({ name = "Disk", icon = ICON.config, category = catChecks })

diskTab:CreateSection({ name = "Config round trip" })

diskTab:CreateButton({
    name = "Window:GetPath()",
    callback = function()
        log("GetPath() ->", Window:GetPath())
    end,
})

diskTab:CreateButton({
    name = "Save, then read the file back",
    description = "Proves it reached the disk rather than just memory.",
    callback = function()
        local saved = Window:Save()
        log("Save() ->", saved)
        local path = Window:GetPath()
        if canFile and isfile(path) then
            local body = readfile(path)
            log("file is", #body, "bytes")
            log(body)
            Window:Notify({ title = "Saved", content = path, icon = ICON.config })
        else
            log("no file at", path)
            Window:Notify({ title = "Save did not reach the disk", content = path })
        end
    end,
})

diskTab:CreateButton({
    name = "Named config round trip",
    description = "Save('Slot1') -> ListConfigs -> Load('Slot1') -> DeleteConfig('Slot1')",
    callback = function()
        local s = Window:Save("Slot1")
        local list = Window:ListConfigs()
        local l = Window:Load("Slot1")
        local d = Window:DeleteConfig("Slot1")
        log("Save('Slot1') ->", s)
        log("ListConfigs() ->", #list > 0 and table.concat(list, ", ") or "(none)")
        log("Load('Slot1') ->", l)
        log("DeleteConfig('Slot1') ->", d)
        local allOk = s and l and d
        Window:Toast({ title = allOk and "Round trip OK" or "Round trip failed", icon = ICON.config })
    end,
})

diskTab:CreateButton({
    name = "Window:SaveSettings() / LoadSettings()",
    description = "The library's own settings file (keybind, cursor, window size), separate from your configs.",
    callback = function()
        log("SaveSettings() ->", Window:SaveSettings())
        log("LoadSettings() ->", Window:LoadSettings())
    end,
})

-- ===========================================================================
-- 7. Elements
-- ===========================================================================

-- Button -------------------------------------------------------------------
local buttonTab = Window:CreateTab({ name = "Button", icon = ICON.dot, category = catElements })

buttonTab:CreateSection({ name = "Buttons" })

buttonTab:CreateButton({
    name = "Fire callback",
    description = "The plainest element. Runs its callback, holds no state.",
    icon = ICON.check,
    callback = function()
        log("Button callback fired")
    end,
})

buttonTab:CreateButton({
    name = "Callback that errors",
    description = "The library catches a throwing callback and flashes the row red instead of dying.",
    callback = function()
        error("deliberate error from the tour script")
    end,
})

-- Toggle -------------------------------------------------------------------
local toggleTab = Window:CreateTab({ name = "Toggle", icon = ICON.check, category = catElements })

toggleTab:CreateSection({ name = "Toggles" })

local autoFarm = toggleTab:CreateToggle({
    name = "Auto Farm",
    description = "flag = AutoFarm, so this one saves and restores.",
    flag = "AutoFarm",
    value = true,
    callback = function(value)
        log("Toggle callback:", value)
    end,
})

toggleTab:CreateSwitch({ name = "Switch (alias of CreateToggle)", flag = "TourSwitch" })

toggleTab:CreateToggle({
    name = "Not saved",
    description = "forgetState = true keeps this out of the config file.",
    forgetState = true,
})

toggleTab:CreateButton({
    name = "Toggle:Set(true)",
    callback = function()
        autoFarm:Set(true)
        log("Toggle:Set(true), value =", autoFarm.value)
    end,
})

toggleTab:CreateButton({
    name = "Toggle:Set(false, skipCallback)",
    description = "The second argument suppresses the callback - what a config restore uses.",
    callback = function()
        autoFarm:Set(false, true)
        log("Toggle:Set(false, true), value =", autoFarm.value)
    end,
})

-- Slider -------------------------------------------------------------------
local sliderTab = Window:CreateTab({ name = "Slider", icon = ICON.chevron, category = catElements })

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
        log("Slider:Set(7.5), value =", delay.value)
    end,
})

-- Dropdown -----------------------------------------------------------------
local dropdownTab = Window:CreateTab({ name = "Dropdown", icon = ICON.config, category = catElements })

dropdownTab:CreateSection({ name = "Dropdowns" })

local seed = dropdownTab:CreateDropdown({
    name = "Seed",
    description = "Single select. value is stored as a pruned list even here.",
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
    name = "Dropdown:Refresh({ Wheat, Barley, Rye })",
    description = "Replaces the whole list. Selections no longer in it are pruned.",
    callback = function()
        seed:Refresh({ "Wheat", "Barley", "Rye" })
        log("Dropdown:Refresh(), value =", table.concat(seed.value, ", "))
    end,
})

dropdownTab:CreateButton({
    name = "Dropdown:Set('Barley')",
    callback = function()
        seed:Set("Barley")
        log("Dropdown:Set('Barley')")
    end,
})

-- Fields -------------------------------------------------------------------
local fieldsTab = Window:CreateTab({ name = "Fields", icon = ICON.search, category = catElements })

fieldsTab:CreateSection({ name = "Input" })

local webhook = fieldsTab:CreateInput({
    name = "Webhook",
    description = "Commits on focus loss or Enter, never per keystroke.",
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
        log("Input:Set(), value =", webhook.value)
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
        log("Keybind:Set(G), value =", sprint.value)
    end,
})

fieldsTab:CreateSection({ name = "Colour picker" })

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
        log("ColorPicker:Set(), value =", espColor.value)
    end,
})

fieldsTab:CreateButton({
    name = "ColorPicker:SetAlpha(0.4)",
    callback = function()
        espColor:SetAlpha(0.4)
        log("ColorPicker:SetAlpha(0.4), alpha =", espColor.alpha)
    end,
})

-- Stat ---------------------------------------------------------------------
local statTab = Window:CreateTab({ name = "Stat", icon = ICON.chevron, category = catElements })

statTab:CreateSection({ name = "Read-outs" })

local revenue = statTab:CreateStat({
    name = "Revenue",
    description = "display = 'value' shows the number itself.",
    prefix = "$",
    value = 12400,
    display = "value",
    compact = true, -- the 41px single-readout card instead of the 90px one
    numberEasing = true,
})

local kills = statTab:CreateStat({
    name = "Kills since open",
    description = "display = 'change' shows movement against a baseline.",
    value = 128,
    display = "change",
    changeMode = "percentage",
    changeBaseline = "initial",
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
    callback = function()
        kills:ResetBaseline()
        log("Stat:ResetBaseline()")
    end,
})

-- ===========================================================================
-- 8. Layout
-- ===========================================================================

local groupsTab = Window:CreateTab({ name = "Groups", icon = ICON.chevron, category = catLayout })

groupsTab:CreateSection({ name = "A row of columns is a grid" })

-- A row holds the compact elements (button/toggle/stat) plus slider. A column also takes
-- dropdown and section. Input, keybind and colorpicker stay tab-level in both.
local grid = groupsTab:CreateGroup()

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

-- Ordering -----------------------------------------------------------------
local orderTab = Window:CreateTab({ name = "Ordering", icon = ICON.dot, category = catLayout })

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

for _, move in
    {
        {
            name = "MoveToTop()",
            fn = function()
                mover:MoveToTop()
            end,
        },
        {
            name = "MoveToBottom()",
            fn = function()
                mover:MoveToBottom()
            end,
        },
        {
            name = "MoveUp()",
            fn = function()
                mover:MoveUp()
            end,
        },
        {
            name = "MoveDown()",
            fn = function()
                mover:MoveDown()
            end,
        },
        {
            name = "MoveTo(3)",
            fn = function()
                mover:MoveTo(3)
            end,
        },
    }
do
    orderTab:CreateButton({
        name = move.name,
        callback = function()
            move.fn()
            log("Moveable:" .. move.name)
        end,
    })
end

-- ===========================================================================
-- 9. Window
-- ===========================================================================

local chromeTab = Window:CreateTab({ name = "Chrome", icon = ICON.settings, category = catWindow })

chromeTab:CreateSection({ name = "Visibility - K brings the window back" })

chromeTab:CreateButton({
    name = "Window:ToggleMinimise()",
    description = "Collapses to the fixed 300x66 bar. The emblem stays on it.",
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
    callback = function()
        log("Window:ToggleHide() - press K if it goes away")
        task.wait(0.2)
        Window:ToggleHide()
    end,
})

chromeTab:CreateSection({ name = "Navigation" })

chromeTab:CreateButton({
    name = "Window:Navigate('Button')",
    callback = function()
        Window:Navigate("Button")
        log("Window:Navigate('Button')")
    end,
})

chromeTab:CreateButton({
    name = "Tab:Select() on Toggle",
    callback = function()
        toggleTab:Select()
        log("Tab:Select()")
    end,
})

chromeTab:CreateSection({ name = "Tags" })

chromeTab:CreateButton({
    name = "Tag:SetText / SetColor / SetIcon",
    callback = function()
        tag:SetText("live")
        tag:SetColor(Color3.fromRGB(255, 175, 15))
        tag:SetIcon(ICON.check)
        log("Tag:SetText / SetColor / SetIcon")
    end,
})

chromeTab:CreateButton({
    name = "Tag:Set({...}) then Tag:Remove()",
    callback = function()
        tag:Set({ text = "tour", color = Color3.fromRGB(144, 231, 68), icon = ICON.emblem })
        log("Tag:Set()")
        task.wait(1)
        tag:Remove()
        log("Tag:Remove() - gone until you rerun")
    end,
})

chromeTab:CreateSection({ name = "Rail" })

chromeTab:CreateButton({
    name = "Rail:Select() on Layout",
    callback = function()
        catLayout:Select()
        log("Rail:Select()")
    end,
})

chromeTab:CreateButton({
    name = "Rail:SetActive(false) on Window",
    description = "Sets the highlight directly, without clearing siblings the way Select does.",
    callback = function()
        catWindow:SetActive(false)
        log("Rail:SetActive(false)")
    end,
})

chromeTab:CreateButton({
    name = "RailProfile:SetUserId(1)",
    description = "Repoints the avatar chip. In secure mode the headshot caches as avatar_<id>.png.",
    callback = function()
        profile:SetUserId(1)
        log("Rail:SetUserId(1)")
    end,
})

-- Overlays -----------------------------------------------------------------
local overlayTab = Window:CreateTab({ name = "Overlays", icon = ICON.config, category = catWindow })

overlayTab:CreateSection({ name = "Three different things" })

overlayTab:CreateButton({
    name = "Window:Notify()",
    callback = function()
        Window:Notify({
            title = "Auto-saved",
            content = "Your configuration was written to disk.",
            icon = ICON.check,
            duration = 4,
        })
        log("Window:Notify()")
    end,
})

overlayTab:CreateButton({
    name = "Window:Toast()",
    callback = function()
        Window:Toast({ title = "Saved", subtitle = "ExecutorTour", icon = ICON.config, duration = 3, position = "Top" })
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
            subtitleAbove = true,
            avatar = 1,
            minWidth = 220,
        })
        log("Window:Toast() with avatar")
    end,
})

overlayTab:CreateButton({
    name = "Window:Popup()",
    callback = function()
        local popup = Window:Popup({
            title = "Reset everything?",
            subtitle = "This cannot be undone",
            icon = ICON.close,
            content = "Clears every saved value and puts the menu back to its defaults.",
            dismissable = true,
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
    name = "Popup with boxes, closed from code",
    description = "The changelog layout, dismissed by the script after 2s rather than by you.",
    callback = function()
        local popup = Window:Popup({
            title = "Closing in 2 seconds",
            boxes = {
                { title = "Asset swap", description = "Every shipped icon is now an owned upload.", icon = ICON.check },
                {
                    title = "Secure mode",
                    description = "Gui protect chain and blocked-icon notice.",
                    icon = ICON.settings,
                },
            },
        })
        task.wait(2)
        popup:Close()
        log("Popup:Close()")
    end,
})

-- Locale and theme ---------------------------------------------------------
local localeTab = Window:CreateTab({ name = "Locale", icon = ICON.search, category = catWindow })

localeTab:CreateSection({ name = "Localisation" })

localeTab:CreateDropdown({
    name = "Language",
    description = "Switches every localised label in place. Untranslated strings stay English.",
    options = { "English", "Francais", "Deutsch (registered at runtime)" },
    value = "English",
    forgetState = true,
    callback = function(value)
        if value == "Deutsch (registered at runtime)" then
            Window:RegisterTranslations({ de = { ["Buttons"] = "Schaltflachen", ["Toggles"] = "Schalter" } })
            Window:SetLocale("de")
        elseif value == "Francais" then
            Window:SetLocale("fr")
        else
            Window:SetLocale("en")
        end
        log("Window:SetLocale() ->", value)
    end,
})

localeTab:CreateButton({
    name = "Window:SetTranslator(fn) - upper-cases everything",
    callback = function()
        Window:SetTranslator(function(source)
            return string.upper(source)
        end)
        Window:SetLocale("en") -- re-resolve what is already on screen through the new hook
        log("Window:SetTranslator()")
    end,
})

localeTab:CreateButton({
    name = "Window:SetTranslator(nil)",
    callback = function()
        Window:SetTranslator(nil)
        Window:SetLocale("en")
        log("Window:SetTranslator(nil)")
    end,
})

localeTab:CreateSection({ name = "Theme" })

localeTab:CreateButton({
    name = "ChangeTheme({ AccentColor = blue })",
    description = "ChangeTheme takes a partial table, so single keys can be overridden.",
    callback = function()
        Window:ChangeTheme({
            AccentColor = Color3.fromRGB(96, 160, 255),
            AccentStroke = Color3.fromRGB(150, 200, 255),
        })
        log("Window:ChangeTheme(partial table)")
    end,
})

localeTab:CreateButton({
    name = "ChangeTheme('default')",
    callback = function()
        Window:ChangeTheme("default")
        log("Window:ChangeTheme('default')")
    end,
})

localeTab:CreateSection({ name = "Flags" })

localeTab:CreateButton({
    name = "Window:Get('AutoFarm') / Set('AutoFarm', true)",
    description = "Set routes through the control, so the UI updates and the callback fires.",
    callback = function()
        log("Get('AutoFarm') ->", Window:Get("AutoFarm"))
        log("Set('AutoFarm', true) ->", Window:Set("AutoFarm", true))
        log("Get('AutoFarm') ->", Window:Get("AutoFarm"))
    end,
})

-- ===========================================================================
-- 10. Session-specific checks -- the things changed on 2026-07-29
-- ===========================================================================

local sessionTab = Window:CreateTab({ name = "Session", icon = ICON.check, category = catWindow })

-- Log viewer ----------------------------------------------------------------
-- Everything this script would have printed is here instead. Popup's box layout is a
-- scrolling list of cards, which is exactly the shape a log wants, and it is public API -
-- no reaching into element internals to rewrite labels.
sessionTab:CreateSection({ name = "Log - nothing goes to the console" })

local LOG_PAGE = 12

local function showLog(fromEnd)
    local total = #lines
    if total == 0 then
        Window:Toast({ title = "Log is empty" })
        return
    end

    local last = math.max(1, total - fromEnd + 1)
    local first = math.max(1, last - LOG_PAGE + 1)

    local boxes = {}
    for i = first, last do
        table.insert(boxes, { title = "#" .. i, description = lines[i] })
    end

    Window:Popup({
        title = "Script log",
        subtitle = string.format("lines %d-%d of %d, newest last", first, last, total),
        icon = ICON.config,
        options = {
            { text = "Close" },
            {
                text = "Older",
                callback = function()
                    if first > 1 then
                        showLog(fromEnd + LOG_PAGE)
                    end
                end,
            },
        },
        boxes = boxes,
    })
end

sessionTab:CreateButton({
    name = "Show log",
    description = "The newest lines. 'Older' pages back through the buffer.",
    icon = ICON.config,
    callback = function()
        showLog(0)
    end,
})

sessionTab:CreateButton({
    name = "Why not the console?",
    description = "A game LocalScript can hook LogService.MessageOut and read every print any script makes, and GetLogHistory hands it the backlog too. Tested on a live client: the library stays silent, but this script's own output was fully readable.",
    callback = function()
        log("console output is readable by any game script, live and retroactively")
        log("the library emits nothing in secure mode; this script is the only thing that would")
        Window:Toast({ title = "Logged", subtitle = "see Show log", icon = ICON.check })
    end,
})

sessionTab:CreateSection({ name = "Secure mode" })

sessionTab:CreateButton({
    name = "Is the library silent?",
    description = "Forces a library-side warning. Secure mode gags it, so an EMPTY console is the pass.",
    callback = function()
        log("asking for a bogus theme...")
        log("secure ON  = no 'AFKTY: unknown theme' line below")
        log("secure OFF = you should see one")
        Window:ChangeTheme("definitely-not-a-real-theme")
        Window:ChangeTheme("default")
    end,
})

sessionTab:CreateButton({
    name = "Blocked-icon notification",
    description = "Builds a tab with an icon the cache cannot serve. In secure mode that must raise exactly one notification, however many icons are affected.",
    callback = function()
        local probe = Window:CreateTab({ name = "Uncached", icon = UNCACHED_ICON, category = catWindow })
        probe:CreateSection({ name = "This tab's icon is not in the cached set" })
        probe:CreateButton({
            name = "Remove this tab",
            callback = function()
                probe:Remove()
                log("Tab:Remove()")
            end,
        })
        if SECURE then
            log("secure ON: expect ONE 'Secure mode' notification, and a blank tab icon")
        else
            log("secure OFF: the icon renders normally and nothing is reported")
        end
        Window:Navigate("Uncached")
    end,
})

sessionTab:CreateSection({ name = "Gui protection" })

sessionTab:CreateButton({
    name = "Where is the ScreenGui?",
    description = "Landing in raw CoreGui is the failure case - a game script can enumerate it there.",
    callback = function()
        local home = findOurGui()
        log("ScreenGui parent ->", home or "not found")
        Window:Notify({
            title = "Gui parent",
            content = home or "could not identify",
            icon = ICON.settings,
        })
    end,
})

sessionTab:CreateButton({
    name = "Can a game script find us in CoreGui?",
    description = "Walks CoreGui:GetChildren() the way a detection script would.",
    callback = function()
        local exposed = 0
        for _, child in game:GetService("CoreGui"):GetChildren() do
            if child:IsA("ScreenGui") and child.DisplayOrder == 99999 then
                exposed += 1
            end
        end
        log("AFKTY ScreenGuis directly under CoreGui:", exposed, exposed == 0 and "(good)" or "(EXPOSED)")
        Window:Notify({
            title = exposed == 0 and "Not enumerable" or "Exposed in CoreGui",
            content = exposed == 0 and "CoreGui:GetChildren() does not see the window." or "Found " .. exposed,
        })
    end,
})

sessionTab:CreateSection({ name = "Resize and hover" })

sessionTab:CreateButton({
    name = "How to check resizing",
    description = "Drag the 16x16 grip in the window's bottom-right. Size persists on release - reopen and it should return.",
    callback = function()
        log("grip is bottom-right; size saves to the settings file on release, never per frame")
        log("min 300x320, max viewport-60, and the top-left corner stays pinned as it grows")
    end,
})

sessionTab:CreateButton({
    name = "How to check row lighting",
    description = "Element rows rest with no outline and light only under the cursor. Panels (dropdown cards, popups, stat tiles) keep a constant edge.",
    callback = function()
        log("hover any button/toggle/slider row: stroke should appear only under the cursor")
        log("dropdown panels and stat tiles keep their edge at all times - that is deliberate")
    end,
})

-- Teardown -----------------------------------------------------------------
local teardownTab = Window:CreateTab({ name = "Teardown", icon = ICON.close, category = catWindow })

teardownTab:CreateSection({ name = "Destructive - these do not come back" })

local scratchTab = Window:CreateTab({ name = "Scratch", icon = ICON.dot, category = catWindow })
scratchTab:CreateSection({ name = "Delete me from the Teardown tab" })
scratchTab:CreateButton({ name = "I do nothing" })

teardownTab:CreateButton({
    name = "Tab:Remove() the Scratch tab",
    callback = function()
        scratchTab:Remove()
        log("Tab:Remove()")
    end,
})

teardownTab:CreateButton({
    name = "Rail:Destroy() the Layout category",
    description = "Removes the rail item. Its tabs stay in the window but lose their category.",
    callback = function()
        catLayout:Destroy()
        log("Rail:Destroy()")
    end,
})

teardownTab:CreateButton({
    name = "Window:Unload()",
    description = "Tears the whole thing down. Rerun the script to get it back.",
    callback = function()
        Window:Popup({
            title = "Unload the window?",
            content = "This destroys the UI. You will need to rerun the script.",
            icon = ICON.close,
            options = {
                { text = "Cancel", style = "neutral" },
                {
                    text = "Unload",
                    style = "danger",
                    callback = function()
                        Window:Unload()
                        log("Window:Unload(), unloaded =", Window.unloaded)
                    end,
                },
            },
        })
    end,
})

-- ===========================================================================
-- 11. Summary
-- ===========================================================================

Window:Navigate("Results")

local summary = string.format("%d passed, %d failed", passed, failed)
log("=====================================")
log("checks:", summary)
log("secure mode:", SECURE)
log("config path:", Window:GetPath())
log("=====================================")
log("open the Checks category for the breakdown; every other tab is interactive")

Window:Notify({
    title = failed == 0 and "All checks passed" or (failed .. " check(s) failed"),
    content = summary .. " - open the Checks category for detail.",
    icon = failed == 0 and ICON.check or ICON.close,
    duration = 8,
})
