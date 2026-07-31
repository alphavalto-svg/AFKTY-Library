--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Public API types. camelCase is the documented surface; PascalCase keys still work.

export type Theme = string | { [string]: any }

-- Optional dev hook: given a source string (the English copy, which doubles as its key) and the
-- active locale id, return the translation, or nil/"" to fall through to the built-in tables.
export type Translator = (source: string, localeId: string) -> string?

-- Translation tables keyed by locale id, each mapping a source string to its translation, e.g.
-- { fr = { ["Close"] = "Fermer" }, ["pt-br"] = { ["Close"] = "Fechar" } }.
export type Translations = { [string]: { [string]: string } }

export type WindowConfiguration = {
    autoSave: boolean?,
    autoLoad: boolean?,
    fileName: string?,
    customFolder: string?,
}

export type WindowProps = {
    name: string?,
    subtitle: string?,
    theme: Theme?,
    icon: (string | number)?,
    showName: string?,
    showIcon: (string | number)?,
    configuration: WindowConfiguration?,
    resize: boolean?, -- drag the bottom-right grip to resize; on unless set false
    fallbackFont: (Font | Enum.Font)?, -- built-in stand-in shown in secure mode while the brand font downloads
    locale: string?, -- pin the UI language; defaults to the player's Roblox locale
    translations: Translations?, -- language tables keyed by locale id; the easy, table-first path
    translator: Translator?, -- resolve copy yourself; falls back to the built-in tables
}

export type TabProps = {
    name: string?,
    icon: (string | number)?,
    -- Owning rail category. Omit it and the tab stays visible under every category, so
    -- CreateTab is unchanged for hubs that never build a rail.
    category: RailItem?,
}

-- Left rail ----------------------------------------------------------------
-- An icon button in the rail's category stack. The icon is required: rail.new asserts on it.
export type RailItemProps = {
    icon: string | number,
    name: string?, -- kept on the handle for the caller; the rail is icon-only and draws no tooltip
    callback: ((item: RailItem) -> ())?,
    active: boolean?, -- start selected; the first category selects itself regardless
    order: number?,
}

-- The player avatar chip, pinned to the bottom of the rail. The library draws the headshot
-- and reports the click.
export type RailProfileProps = {
    userId: number?, -- defaults to the local player
    callback: ((profile: RailItem) -> ())?,
}

-- One handle covers both, since a profile chip is a rail item that draws an avatar.
-- SetUserId is only meaningful on the chip.
export type RailItem = {
    active: boolean,
    userId: number?, -- profile chips only
    Select: (self: RailItem) -> (), -- take the selection and clear every sibling
    SetActive: (self: RailItem, active: boolean) -> (), -- set the highlight without clearing siblings
    SetUserId: (self: RailItem, userId: number) -> (),
    Destroy: (self: RailItem) -> (),
}

export type TagProps = {
    text: string?,
    title: string?,
    icon: (string | number)?,
    color: Color3?,
    order: number?,
}

export type SectionProps = {
    name: string?,
    icon: (string | number)?,
}

export type GroupProps = {
    direction: string?, -- "row" | "column" (default row); "horizontal"/"vertical" also work
}

export type ButtonProps = {
    name: string?,
    description: string?,
    icon: (string | number)?,
    callback: (() -> ())?,
}

export type ToggleProps = {
    name: string?,
    description: string?,
    icon: (string | number)?,
    flag: string?,
    value: boolean?,
    forgetState: boolean?,
    callback: ((value: boolean) -> ())?,
}

export type SliderProps = {
    name: string?,
    description: string?,
    icon: (string | number)?,
    flag: string?,
    range: { number }?, -- { min, max }
    increment: number?,
    value: number?,
    suffix: string?,
    minimal: boolean?, -- track only, no name/value (for dense rows)
    forgetState: boolean?,
    callback: ((value: number) -> ())?,
}

export type DropdownProps = {
    name: string?,
    description: string?,
    icon: (string | number)?,
    flag: string?,
    options: { string }?,
    value: (string | { string })?,
    multiSelect: boolean?,
    placeholder: string?,
    forgetState: boolean?,
    callback: ((value: any) -> ())?,
}

export type InputProps = {
    name: string?,
    description: string?,
    icon: (string | number)?,
    flag: string?,
    value: string?,
    placeholder: string?,
    numeric: boolean?,
    clearOnFocus: boolean?,
    forgetState: boolean?,
    callback: ((value: string) -> ())?,
}

export type KeybindProps = {
    name: string?,
    description: string?,
    icon: (string | number)?,
    flag: string?,
    value: (EnumItem | string)?, -- an Enum.KeyCode / mouse button, or a KeyCode name
    forgetState: boolean?,
    isMenuToggle: boolean?, -- internal: the settings menu-toggle keybind, clash check runs in reverse
    hold: boolean?, -- fire callback(true) once held, callback(false) on release
    holdThreshold: number?, -- seconds to hold before it counts (default 0.2)
    callback: ((value: EnumItem | boolean) -> ())?, -- bound key on press, or true/false in hold mode
    onChanged: ((key: EnumItem) -> ())?, -- fires when the binding is changed
}

export type ColorPickerProps = {
    name: string?,
    description: string?,
    icon: (string | number)?,
    flag: string?,
    color: Color3?, -- initial colour (accepts a hex string too)
    alpha: number?, -- initial alpha 0..1 (default 1)
    forgetState: boolean?,
    callback: ((value: Color3, alpha: number) -> ())?,
}

export type StatProps = {
    name: string?,
    description: string?,
    icon: (string | number)?,
    prefix: string?,
    suffix: string?,
    value: number?,
    display: string?, -- "value" | "change"
    compact: boolean?,
    changeMode: string?, -- "percentage" | "absolute"
    changeBaseline: string?, -- "previous" | "initial"
    numberEasing: boolean?,
}

export type NotifyProps = {
    title: string?,
    content: string?,
    icon: (string | number)?,
    duration: number?,
}

export type ToastProps = {
    title: string?,
    subtitle: string?, -- optional second line
    subtitleAbove: boolean?, -- render the subtitle above the title (label-over-value)
    icon: (string | number)?, -- optional; asset id or ready image string (rbxthumb works)
    avatar: number?, -- optional user id; shows that user's headshot as a larger avatar
    minWidth: number?, -- floor the pill width; slack becomes right-hand room (content is left-aligned)
    duration: number?,
    position: "Top" | "Bottom"?,
}

export type PopupBox = {
    title: string?,
    description: string?,
    icon: (string | number)?,
}

export type PopupOption = {
    text: string?,
    style: string?, -- "neutral" (default) | "primary" | "danger"
    callback: (() -> ())?,
}

export type PopupProps = {
    title: string?,
    subtitle: string?,
    icon: (string | number)?,
    content: string?, -- a body paragraph
    boxes: { PopupBox }?, -- a list of cards (the changelog layout)
    options: { PopupOption }?, -- footer buttons; defaults to a single dismiss button
    dismissable: boolean?, -- click the dim or press Escape to close (default true)
}

-- Handles ------------------------------------------------------------------
-- Every element can be reordered within its tab.
export type Moveable = {
    MoveTo: (self: any, index: number) -> (),
    MoveToTop: (self: any) -> (),
    MoveToBottom: (self: any) -> (),
    MoveUp: (self: any) -> (),
    MoveDown: (self: any) -> (),
}

export type Button = Moveable & {}

export type Toggle = Moveable & {
    value: boolean,
    Set: (self: Toggle, value: boolean, skipCallback: boolean?) -> (),
}

export type Slider = Moveable & {
    value: number,
    Set: (self: Slider, value: number, skipCallback: boolean?) -> (),
}

export type Dropdown = Moveable & {
    value: { string }, -- always stored pruned to the current options, even single-select
    Set: (self: Dropdown, value: string | { string }, skipCallback: boolean?) -> (),
    Refresh: (self: Dropdown, options: { string }) -> (), -- replace the list; selections no longer in it are pruned
    Add: (self: Dropdown, option: string) -> (),
    Remove: (self: Dropdown, option: string) -> (),
}

export type Input = Moveable & {
    value: string,
    Set: (self: Input, value: string, skipCallback: boolean?) -> (),
}

export type Keybind = Moveable & {
    value: EnumItem,
    Set: (self: Keybind, value: EnumItem | string, skipChanged: boolean?) -> (),
}

export type ColorPicker = Moveable & {
    value: Color3,
    alpha: number,
    Set: (self: ColorPicker, value: Color3 | string, skipCallback: boolean?) -> (),
    SetAlpha: (self: ColorPicker, alpha: number, skipCallback: boolean?) -> (),
}

export type Stat = Moveable & {
    value: number,
    Set: (self: Stat, value: number) -> (),
    ResetBaseline: (self: Stat, value: number?) -> (),
}

export type Section = Moveable & {}

-- Tags sit in the window's title bar and order themselves, so they aren't Moveable.
export type Tag = {
    Set: (self: Tag, props: TagProps) -> (),
    SetColor: (self: Tag, color: Color3) -> (),
    SetText: (self: Tag, text: string?) -> (),
    SetIcon: (self: Tag, icon: (string | number)?) -> (),
    Remove: (self: Tag) -> (),
}

export type Popup = {
    Close: (self: Popup) -> (),
}

-- A group lays elements along one axis and nests, so a row of columns builds a grid.
-- A row accepts the compact elements (button/toggle/stat) and slider; a column also takes
-- dropdown and section. Input, keybind and colorpicker stay tab-level.
export type Group = Moveable & {
    CreateButton: (self: Group, props: ButtonProps) -> Button,
    CreateToggle: (self: Group, props: ToggleProps) -> Toggle,
    CreateSwitch: (self: Group, props: ToggleProps) -> Toggle,
    CreateStat: (self: Group, props: StatProps) -> Stat,
    CreateSlider: (self: Group, props: SliderProps) -> Slider,
    CreateDropdown: (self: Group, props: DropdownProps) -> Dropdown,
    CreateSection: (self: Group, props: SectionProps) -> Section,
    CreateGroup: (self: Group, props: GroupProps?) -> Group,
}

export type Tab = {
    Select: (self: Tab, noAnimation: boolean?) -> (),
    Deselect: (self: Tab, noAnimation: boolean?) -> (),
    Remove: (self: Tab) -> (), -- drops the tab, its page and its connections
    CreateButton: (self: Tab, props: ButtonProps) -> Button,
    CreateToggle: (self: Tab, props: ToggleProps) -> Toggle,
    CreateSwitch: (self: Tab, props: ToggleProps) -> Toggle,
    CreateSlider: (self: Tab, props: SliderProps) -> Slider,
    CreateDropdown: (self: Tab, props: DropdownProps) -> Dropdown,
    CreateInput: (self: Tab, props: InputProps) -> Input,
    CreateKeybind: (self: Tab, props: KeybindProps) -> Keybind,
    CreateColorPicker: (self: Tab, props: ColorPickerProps) -> ColorPicker,
    CreateStat: (self: Tab, props: StatProps) -> Stat,
    CreateSection: (self: Tab, props: SectionProps) -> Section,
    CreateGroup: (self: Tab, props: GroupProps?) -> Group,
}

export type Window = {
    unloaded: boolean, -- true once Unload has run; the handle is spent
    CreateTab: (self: Window, props: TabProps) -> Tab,
    CreateTag: (self: Window, props: TagProps) -> Tag,
    -- The rail is built on the first of these calls and insets the window's content; a
    -- window that never calls them keeps its original geometry.
    CreateRailItem: (self: Window, props: RailItemProps) -> RailItem,
    CreateRailProfile: (self: Window, props: RailProfileProps?) -> RailItem,
    Notify: (self: Window, props: NotifyProps) -> (),
    Toast: (self: Window, props: ToastProps) -> (),
    Popup: (self: Window, props: PopupProps) -> Popup,
    Show: (self: Window) -> (),
    Hide: (self: Window) -> (),
    ToggleHide: (self: Window) -> (),
    ToggleMinimise: (self: Window) -> (),
    Navigate: (self: Window, tab: string | Tab) -> (),
    ChangeTheme: (self: Window, theme: Theme) -> (),
    SetLocale: (self: Window, localeId: string) -> (),
    SetTranslator: (self: Window, translator: Translator?) -> (),
    RegisterTranslations: (self: Window, translations: Translations) -> (),
    Save: (self: Window, name: string?) -> boolean,
    Load: (self: Window, name: string?) -> boolean,
    ListConfigs: (self: Window) -> { string },
    DeleteConfig: (self: Window, name: string) -> boolean,
    GetPath: (self: Window) -> string,
    -- The library's own settings (theme, menu keybind, window size and position), kept in a
    -- separate file from the caller's configs.
    SaveSettings: (self: Window) -> boolean,
    LoadSettings: (self: Window) -> boolean,
    -- Reach any registered control by its flag. Get returns nil when nothing is registered;
    -- Set routes through the control, so the UI updates and the callback fires.
    Get: (self: Window, flag: string) -> any,
    Set: (self: Window, flag: string, value: any) -> boolean,
    Unload: (self: Window) -> (),
}

export type AFKTY = {
    version: string,
    CreateWindow: (self: AFKTY, props: WindowProps) -> Window,
}

return {}
