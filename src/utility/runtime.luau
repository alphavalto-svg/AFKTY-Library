--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- What the library learns about its host the moment it loads: the services it needs, whether
-- secure mode was asked for, and where a ScreenGui can be parented so the game cannot find it.
-- Read once here rather than per call site, so the answers cannot drift mid-session.

local services = require(script.Parent.services)

export type RuntimeState = {
    secureMode: boolean,
    coreGui: CoreGui,
    workspace: Workspace,
    runService: RunService,
    userInputService: UserInputService,
    guiService: GuiService,
    localPlayer: Player?,
    tweenService: TweenService,
    httpService: HttpService,
    textService: TextService,
    replicatedStorage: ReplicatedStorage,
    localizationService: LocalizationService,
    guiContainer: Instance,
    guiContainerHidden: boolean,
    resolveProtect: () -> ((Instance) -> ())?,
    parentGui: (gui: Instance) -> (),
    retireStaleGuis: (gui: Instance) -> (),
}

local runtime = {} :: RuntimeState

-- Secure mode is on by default wherever it can do its job. getgenv lives in the executor's
-- script environment, not _G; its absence means Studio or the test harness, where secure mode
-- cannot work at all.
--
--   AFKTY_SECURE = false  opt out, whatever the executor can do
--   AFKTY_SECURE = true   opt in strictly, honoured even where icons cannot be cached
--   unset                 on, but only where the icon cache can actually be served
--
-- An uncached icon resolves to "" in secure mode, so defaulting it on unconditionally would
-- blank every icon on an executor without getcustomasset.
runtime.secureMode = (function()
    if typeof(getgenv) ~= "function" then
        return false
    end
    local ok, value = pcall(function()
        return getgenv().AFKTY_SECURE
    end)
    if not ok or value == false then
        return false
    end
    if value == true then
        return true
    end

    -- these are the two the icon cache needs; imageCache.preload bails without them
    local envOk, env = pcall(getfenv)
    if not envOk or type(env) ~= "table" then
        return false
    end
    return type(env.getcustomasset) == "function" and type(env.isfile) == "function"
end)()

runtime.coreGui = services.getService("CoreGui") :: CoreGui
runtime.workspace = services.getService("Workspace") :: Workspace -- read for CurrentCamera
runtime.runService = services.getService("RunService") :: RunService
runtime.userInputService = services.getService("UserInputService") :: UserInputService
runtime.guiService = services.getService("GuiService") :: GuiService
runtime.localPlayer = (services.getService("Players") :: Players).LocalPlayer
runtime.tweenService = services.getService("TweenService") :: TweenService
runtime.httpService = services.getService("HttpService") :: HttpService
runtime.textService = services.getService("TextService") :: TextService
runtime.replicatedStorage = services.getService("ReplicatedStorage") :: ReplicatedStorage
runtime.localizationService = services.getService("LocalizationService") :: LocalizationService
-- a gethui stub returning nil would parent every ScreenGui nowhere, so fall back to CoreGui.
-- guiContainerHidden records whether the container is actually out of the game's reach, which
-- decides whether each ScreenGui still needs its own protect call below.
local containerHidden = false
runtime.guiContainer = (function(): Instance
    if runtime.runService:IsStudio() then
        return (runtime.localPlayer :: Player).PlayerGui
    end
    if typeof(gethui) == "function" then
        local ok, container = pcall(gethui)
        if ok and typeof(container) == "Instance" then
            -- not every gethui returns somewhere hidden: one observed handing back
            -- CoreGui.RobloxGui, which anything walking CoreGui enumerates
            local hidden = container ~= runtime.coreGui
                and container ~= runtime.coreGui:FindFirstChild("RobloxGui")
                and not container:IsDescendantOf(runtime.coreGui)
            containerHidden = hidden
            return container
        end
    end
    -- RobloxGui is a child of CoreGui, so a script walking CoreGui:GetChildren() for stray
    -- ScreenGuis does not trip over us. Weaker than gethui, better than the top level.
    local robloxGui = runtime.coreGui:FindFirstChild("RobloxGui")
    if robloxGui then
        return robloxGui
    end
    return runtime.coreGui
end)()
runtime.guiContainerHidden = containerHidden

-- Executors without gethui often still expose a protect call, which takes the ScreenGui itself
-- rather than handing back a container. Every ScreenGui goes through here rather than assigning
-- Parent directly: protect first, then parent, which is the order these implementations expect.
-- a field rather than a local so specs can hand back a stub
function runtime.resolveProtect(): ((Instance) -> ())?
    local ok, env = pcall(getfenv)
    if not ok or type(env) ~= "table" then
        return nil
    end
    local syn = env.syn
    if type(syn) == "table" and type(syn.protect_gui) == "function" then
        return syn.protect_gui
    end
    if type(env.protectgui) == "function" then
        return env.protectgui
    end
    return nil
end

-- Re-running a hub script builds a fresh window while the previous run's is still parented, and
-- nothing holds the old handle, so they pile up in the container. A second window opened in the
-- same run is legitimate, so the two are told apart by runToken, a new table per module load.
-- The register lives in getgenv because that is what survives between loads.
local runToken = {}

function runtime.retireStaleGuis(gui: Instance)
    if typeof(getgenv) ~= "function" then
        return
    end
    local ok, env = pcall(getgenv)
    if not ok or type(env) ~= "table" then
        return
    end

    local live = env.__afktyLiveGuis
    if type(live) ~= "table" then
        live = {}
        env.__afktyLiveGuis = live
    end

    for i = #live, 1, -1 do
        local entry = live[i]
        -- duck-typed rather than `typeof(gui) == "Instance"`: the spec harness stands its
        -- instances up as plain tables
        local tracked = if type(entry) == "table" then entry.gui else nil
        local usable = tracked ~= nil and type(tracked.Destroy) == "function" and tracked.Parent ~= nil
        if not usable then
            table.remove(live, i)
        elseif entry.token ~= runToken then
            table.remove(live, i)
            pcall(function()
                tracked:Destroy()
            end)
        end
    end

    table.insert(live, { token = runToken, gui = gui })
end

function runtime.parentGui(gui: Instance)
    -- gethui already put us somewhere the game cannot enumerate; protecting again is a no-op
    -- at best and an error on some executors
    if not runtime.guiContainerHidden then
        local protect = runtime.resolveProtect()
        if protect then
            pcall(protect, gui)
        end
    end
    gui.Parent = runtime.guiContainer
end

return runtime
