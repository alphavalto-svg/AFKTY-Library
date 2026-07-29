--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
}

local runtime = {} :: RuntimeState

runtime.secureMode = (function()
    -- getgenv lives in the executor's script environment, not _G, same as gethui below
    if typeof(getgenv) ~= "function" then
        return false
    end
    local ok, val = pcall(function()
        return getgenv().AFKTY_SECURE
    end)
    return ok and val == true
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
-- a gethui stub that returns nil would parent every ScreenGui nowhere, so fall back to CoreGui.
-- guiContainerHidden records whether what we landed on is actually out of reach of the game:
-- gethui()'s container is, raw CoreGui is not, and the difference decides whether each
-- ScreenGui still needs an individual protect call below.
local containerHidden = false
runtime.guiContainer = (function(): Instance
    if runtime.runService:IsStudio() then
        return (runtime.localPlayer :: Player).PlayerGui
    end
    if typeof(gethui) == "function" then
        local ok, container = pcall(gethui)
        if ok and container then
            containerHidden = true
            return container
        end
    end
    -- RobloxGui is a child of CoreGui rather than CoreGui itself, so a script walking
    -- CoreGui:GetChildren() looking for stray ScreenGuis does not trip over us. Weaker than
    -- gethui, better than sitting at the top level.
    local robloxGui = runtime.coreGui:FindFirstChild("RobloxGui")
    if robloxGui then
        return robloxGui
    end
    return runtime.coreGui
end)()
runtime.guiContainerHidden = containerHidden

-- Executors without gethui often still expose a protect call, and unlike gethui it takes the
-- ScreenGui itself rather than handing back a container. Every ScreenGui therefore goes through
-- here instead of assigning Parent directly: protect first, then parent, which is the order
-- these implementations expect.
-- a field rather than a local so specs can hand back a stub; outside an executor the lookup
-- below finds nothing anyway, which is why there is no separate Studio guard
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
