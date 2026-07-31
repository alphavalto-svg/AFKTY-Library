--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Haptic feedback: a thin wrapper over HapticEffect that buzzes the player's device on two
-- interactions, a press and a notification. The softer UIHover preset maps to a press, the
-- crisper UIClick to a notification. No-ops on devices without haptics.

local variables = require(script.Parent.variables)

local hapticEngine = {}

hapticEngine.enabled = false -- off by default; the settings toggle flips it (see setEnabled)

-- Resolve the presets once. HapticEffect and its enum only exist on newer clients, so on an
-- old client `types` stays empty and every call is a no-op. The enum lookup is pcall'd.
type HapticTypes = {
    click: Enum.HapticEffectType?,
    notify: Enum.HapticEffectType?,
}

local types: HapticTypes = {}
local supported, resolvedTypes = pcall(function()
    Instance.new("HapticEffect"):Destroy() -- probe: errors on clients without the class
    return {
        click = Enum.HapticEffectType.UIHover, -- presses use the softer hover tick
        notify = Enum.HapticEffectType.UIClick, -- notifications use the crisper click
    }
end)
if supported then
    types = resolvedTypes
end

-- One reusable effect per preset, made on first use and kept parented for the session.
-- They live with the interface rather than in Workspace, which the game's own scripts can
-- read: an effect only needs a parent to play, not a world one.
local effects: { [Enum.HapticEffectType]: Instance } = {}
local container: Instance? = nil

-- Where new effects get parented. The window hands over its ScreenGui; until then, fall back
-- to the container every AFKTY gui lives in.
function hapticEngine.setContainer(target: Instance?)
    container = target
end

-- Let go of a gui being torn down, without stamping on a container another window has set.
function hapticEngine.releaseContainer(target: Instance?)
    if target == nil or container == target then
        container = nil
    end
end

local function containerFor(): Instance
    if container and container.Parent then
        return container
    end
    return variables.guiContainer
end

local function effectFor(hapticType: Enum.HapticEffectType): Instance?
    local effect = effects[hapticType]
    -- recreate if it was never made, or got destroyed out from under us (Parent goes nil)
    if effect and effect.Parent then
        return effect
    end
    local ok, made = pcall(Instance.new, "HapticEffect")
    if not ok then
        return nil
    end
    local hapticEffect = made :: any
    hapticEffect.Type = hapticType
    local parented = pcall(function()
        made.Parent = containerFor()
    end)
    if not parented then
        made:Destroy()
        return nil
    end
    effects[hapticType] = made
    return made
end

local function play(hapticType: Enum.HapticEffectType?)
    if not hapticType or not hapticEngine.enabled then
        return
    end
    local effect = effectFor(hapticType)
    if effect then
        local hapticEffect = effect :: any
        pcall(hapticEffect.Play, effect)
    end
end

-- tap for a button, switch, tab or any discrete press
function hapticEngine.click()
    play(types.click)
end

-- attention buzz for a notification, toast or popup
function hapticEngine.notify()
    play(types.notify)
end

-- Global on/off for the settings toggle. Turning it off tears the pool down; it is remade lazily.
function hapticEngine.setEnabled(state: boolean?)
    hapticEngine.enabled = state and true or false
    if not hapticEngine.enabled then
        hapticEngine.teardown()
    end
end

-- Drop the pool without touching the enabled flag, so one window's cleanup does not decide
-- haptics for another.
function hapticEngine.teardown()
    for hapticType, effect in effects do
        pcall(effect.Destroy, effect)
        effects[hapticType] = nil
    end
end

return hapticEngine
