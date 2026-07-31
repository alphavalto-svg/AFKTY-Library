--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Localization core. Both the library's own chrome and the names a hub gives its elements
-- resolve the same way: the dev translator first, then the built-in table for the active
-- locale, then the source string itself, so anything untranslated still reads in English.
--
-- Only strings wrapped in locale.t() are treated as copy. Element values, slider readouts,
-- keybind keys and hex codes are data, not language, and are left alone.

local variables = require(script.Parent.variables)
local log = require(script.Parent.log)

local locale = {}

export type LocaleToken = { [any]: string }
export type Translator = (source: string, localeId: string) -> string?
export type TranslationTables = { [string]: { [string]: string } }

-- English is canonical: every wrapped string in src is written in it, so the source text is
-- also its own lookup key. A new language is a table keyed by those same source strings.
-- Regional tables ("pt-br") win over the bare language ("pt") when both exist.
locale.strings = {} :: TranslationTables
-- ["fr"] = { ["Signed in as"] = "Connecte en tant que", ... },

-- active locale id and the optional dev hook (source, localeId) -> string?, both neutral by default
locale.current = "en"
locale.translator = nil :: Translator?

-- a wrapped string carries this tag so Window:Create can tell copy from a plain value; property
-- values are never plain tables, so the shape is unambiguous
local tokenTag = {}

local function languageOf(id: string): string
    return string.match(id, "^(%a+)") or id
end

-- Wrap a string so it localizes. Returns the value untouched when there is nothing to
-- translate, so callers can wrap unconditionally.
function locale.t(source: unknown): unknown
    if type(source) ~= "string" or source == "" then
        return source
    end
    return { [tokenTag] = source }
end

-- True for a value produced by locale.t that still carries a source string.
function locale.isToken(value: unknown): boolean
    return type(value) == "table" and type((value :: { [any]: unknown })[tokenTag]) == "string"
end

function locale.sourceOf(token: LocaleToken): string
    return token[tokenTag]
end

-- Resolve a source string to the active locale: dev translator, exact-locale table,
-- language-only table, then the source itself. The translator is pcall'd.
function locale.resolve(source: unknown): any
    if type(source) ~= "string" then
        return source
    end

    if locale.translator then
        local ok, translated = pcall(locale.translator, source, locale.current)
        if ok and type(translated) == "string" and translated ~= "" then
            return translated
        end
    end

    local exact = locale.strings[locale.current]
    if exact and exact[source] then
        return exact[source]
    end

    local language = locale.strings[languageOf(locale.current)]
    if language and language[source] then
        return language[source]
    end

    return source
end

-- Merge dev-supplied translation tables into the built-in set, keyed by lowercased locale id.
-- Merges rather than replaces, so repeated calls accumulate. A dev translator still wins.
-- Entries are type-checked here: a non-string translation would otherwise only fail at render.
function locale.register(tables: TranslationTables?)
    if type(tables) ~= "table" then
        return
    end
    for id, entries in tables do
        if type(id) == "string" and type(entries) == "table" then
            id = string.lower(id)
            local target = locale.strings[id]
            if not target then
                target = {}
                locale.strings[id] = target
            end
            for source, translated in entries do
                if type(source) == "string" and type(translated) == "string" then
                    target[source] = translated
                else
                    log.warn(`AFKTY: skipping a '{id}' translation, entries must be string to string.`)
                end
            end
        end
    end
end

-- Point the active locale at `localeId`, falling back to English. Touches nothing on screen;
-- callers re-resolve their own labels.
function locale.setActive(localeId: string?): string
    locale.current = if type(localeId) == "string" and localeId ~= "" then string.lower(localeId) else "en"
    return locale.current
end

-- The player's language from Roblox's locale id (e.g. "fr-fr"), kept whole so a translator sees
-- the region; resolve() narrows to the language part when it needs to.
function locale.detect(): string
    local id = variables.localizationService.RobloxLocaleId
    if type(id) == "string" and id ~= "" then
        return string.lower(id)
    end
    return "en"
end

return locale
