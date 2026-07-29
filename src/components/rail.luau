--!nonstrict

-- Left icon rail: a vertical strip of icon buttons down the window's left edge, with an
-- optional player avatar pinned at the bottom.
--
-- The rail is built lazily on the first CreateRailItem/CreateRailProfile call. A window that
-- never asks for one keeps its original geometry exactly, so adding this cannot shift any
-- existing layout.
--
-- Rail items carry no navigation model on purpose. Each is an icon plus a callback, and the
-- consuming script decides what one means -- switch tabs, open a popup, toggle something.
-- The avatar is the same: the library fetches and draws the headshot, and hands you a click.
-- What it *shows* (subscription tier, expiry, account state) is script logic, not library
-- policy.

local Rail = {}
Rail.__index = Rail
Rail.__type = "RailItem"

local utility = script.Parent.Parent.utility

local variables = require(utility.variables)
local image = require(utility.image)
local constants = require(utility.constants)

local SURFACE_IDLE = 0.6 -- rail + its edge cover at rest
local DIVIDER_IDLE = 0.85 -- the hairline on the rail's inner edge

local RAIL_WIDTH = 56
local ITEM_SIZE = 38
local ITEM_PADDING = 8
local EDGE_PADDING = 12
local ICON_INSET = 9 -- icon is ITEM_SIZE - 2*ICON_INSET square, centred
-- search + settings + avatar, stacked with padding between
local BOTTOM_STACK_HEIGHT = ITEM_SIZE * 3 + ITEM_PADDING * 2
local BRAND_SIZE = 28
-- brand + its divider + the gap under it, reserved above the category stack
local BRAND_BLOCK = BRAND_SIZE + 8 + 1 + ITEM_PADDING

local hoverInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local activeInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

-- Where the title sits while the window is collapsed to the minimise bar. Only the emblem is
-- left of it there, so the full rail-width inset would strand it in an empty gap - and on a
-- 300px bar it lands under the action icons.
local COLLAPSED_TITLE_X = RAIL_WIDTH / 2 + BRAND_SIZE / 2 + 10

-- Slide the title between its expanded home (inset past the whole rail) and its collapsed one
-- (tucked just clear of the emblem). Idempotent, so repeated show/hide can't walk it away.
local function setTitleInset(window, expanded, info)
    if not window.topContainer or window._titleExpanded == nil then
        return -- no rail was ever built, so the title was never inset
    end
    if window._titleExpanded == expanded then
        return
    end
    window._titleExpanded = expanded

    local position = window.topContainer.Position
    local target = if expanded then window._titleBaseX + RAIL_WIDTH else COLLAPSED_TITLE_X
    variables.tweenService
        :Create(window.topContainer, info, {
            Position = UDim2.new(position.X.Scale, target, position.Y.Scale, position.Y.Offset),
        })
        :Play()
end

-- Shift a container right by the rail width, keeping whatever anchoring it already had.
-- Called once, when the rail first appears.
local function insetForRail(window)
    local half = RAIL_WIDTH / 2

    -- tabList and elements are centre-anchored and full width: narrow them and nudge right
    -- by half the amount, which keeps them centred in the space that is left.
    if window.tabList then
        local size = window.tabList.Size
        window.tabList.Size = UDim2.new(size.X.Scale, size.X.Offset - RAIL_WIDTH, size.Y.Scale, size.Y.Offset)
        local pos = window.tabList.Position
        window.tabList.Position = UDim2.new(pos.X.Scale, pos.X.Offset + half, pos.Y.Scale, pos.Y.Offset)
    end

    if window.elements then
        local size = window.elements.Size
        window.elements.Size = UDim2.new(size.X.Scale, size.X.Offset - RAIL_WIDTH, size.Y.Scale, size.Y.Offset)
        local pos = window.elements.Position
        window.elements.Position = UDim2.new(pos.X.Scale, pos.X.Offset + half, pos.Y.Scale, pos.Y.Offset)
    end

    -- the search field is centre-anchored and full width like tabList, so without this it
    -- runs straight under the rail icons when search opens
    if window.searchPill then
        local size = window.searchPill.Size
        window.searchPill.Size = UDim2.new(size.X.Scale, size.X.Offset - RAIL_WIDTH, size.Y.Scale, size.Y.Offset)
        local pos = window.searchPill.Position
        window.searchPill.Position = UDim2.new(pos.X.Scale, pos.X.Offset + half, pos.Y.Scale, pos.Y.Offset)
    end

    -- the title block is left-anchored, so it only needs the full offset, not half
    if window.topContainer then
        local pos = window.topContainer.Position
        -- remembered so collapse can put it back without re-deriving where it started
        window._titleBaseX = pos.X.Offset
        window._titleExpanded = true
        window.topContainer.Position = UDim2.new(pos.X.Scale, pos.X.Offset + RAIL_WIDTH, pos.Y.Scale, pos.Y.Offset)
    end
end

-- Build the rail frame and its two stacks (icons from the top, avatar pinned bottom).
local function ensureRail(window)
    if window.rail then
        return window.rail
    end

    local rail = {}

    rail.main = window:Create("Frame", {
        Name = "Rail",
        Size = UDim2.new(0, RAIL_WIDTH, 1, 0),
        Position = UDim2.fromScale(0, 0),
        BackgroundTransparency = SURFACE_IDLE,
        BorderSizePixel = 0,
        ZIndex = 2,

        Parent = window.main,
    }, { BackgroundColor3 = "StatBackground" })

    -- square off the right edge so the rail meets the content flush while the window's own
    -- rounded corners still shape its left side
    window:Create("UICorner", {
        CornerRadius = window.theme and window.theme.CornerRoundness or UDim.new(0, 8),

        Parent = rail.main,
    })

    rail.edgeCover = window:Create("Frame", {
        Name = "RailEdge",
        Size = UDim2.new(0, 12, 1, 0),
        Position = UDim2.new(1, -12, 0, 0),
        BackgroundTransparency = SURFACE_IDLE,
        BorderSizePixel = 0,
        ZIndex = 2,

        Parent = rail.main,
    }, { BackgroundColor3 = "StatBackground" })

    -- a hairline down the rail's inner edge, so it reads as a surface rather than a tint
    rail.divider = window:Create("Frame", {
        Name = "RailDivider",
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, -1, 0, 0),
        BackgroundTransparency = DIVIDER_IDLE,
        BorderSizePixel = 0,
        ZIndex = 3,

        Parent = rail.main,
    }, { BackgroundColor3 = "SurfaceStroke" })

    -- Brand mark. Deliberately not a button and never selectable: it marks the product, and
    -- letting it take the selection meant the menu opened on something that was not a page.
    rail.brand = window:Create("ImageLabel", {
        Name = "RailBrand",
        Size = UDim2.fromOffset(BRAND_SIZE, BRAND_SIZE),
        Position = UDim2.new(0.5, 0, 0, EDGE_PADDING),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 1,
        Image = image.resolve(window.icon or constants.icons.afkty),
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 4,

        Parent = rail.main,
    })

    rail.brandDivider = window:Create("Frame", {
        Name = "RailBrandDivider",
        Size = UDim2.new(0, BRAND_SIZE, 0, 1),
        Position = UDim2.new(0.5, 0, 0, EDGE_PADDING + BRAND_SIZE + 8),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 0.8,
        BorderSizePixel = 0,
        ZIndex = 4,

        Parent = rail.main,
    }, { BackgroundColor3 = "SurfaceStroke" })

    -- Category stack, below the brand. This is the caller's space: CreateRailItem lands here,
    -- so scripts can add their own sections without fighting the built-in controls below.
    rail.top = window:Create("Frame", {
        Name = "RailItems",
        Size = UDim2.new(1, 0, 1, -(BOTTOM_STACK_HEIGHT + BRAND_BLOCK + EDGE_PADDING * 2)),
        Position = UDim2.new(0, 0, 0, EDGE_PADDING + BRAND_BLOCK),
        BackgroundTransparency = 1,
        ZIndex = 3,

        Parent = rail.main,
    })

    window:Create("UIListLayout", {
        Padding = UDim.new(0, ITEM_PADDING),
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = rail.top,
    })

    -- Built-in controls, pinned bottom: search, settings, then the avatar last so it sits
    -- in the corner. Kept apart from the caller's stack so adding categories above never
    -- pushes these around.
    rail.bottom = window:Create("Frame", {
        Name = "RailControls",
        Size = UDim2.new(1, 0, 0, BOTTOM_STACK_HEIGHT),
        Position = UDim2.new(0, 0, 1, -EDGE_PADDING),
        AnchorPoint = Vector2.new(0, 1),
        BackgroundTransparency = 1,
        ZIndex = 3,

        Parent = rail.main,
    })

    window:Create("UIListLayout", {
        Padding = UDim.new(0, ITEM_PADDING),
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = rail.bottom,
    })

    insetForRail(window)

    -- assigned before the built-ins below are made, so their own ensureRail call short-circuits
    window.rail = rail

    -- The rail takes search and settings over from the topbar rather than duplicating them,
    -- leaving only minimise and close at the top right. They live in the bottom stack above
    -- the avatar, so the top of the rail stays free for the caller's categories.
    if window.searchAction and window.searchAction.action then
        window.searchAction.action.Visible = false
        local item = Rail.new(window, {
            icon = constants.icons.search,
            name = "Search",
            order = 0,
            slot = "bottom",
            callback = function()
                local searchModule = require(script.Parent.search)
                if window._searching then
                    -- closing search: go back to whichever category was open before it
                    searchModule.close(window, { showTabs = true })
                    local last = rail._lastCategory
                    if last and not last.destroyed then
                        last:Select()
                    end
                    return
                end
                -- Opening search is leaving the category, so drop the highlight. Otherwise
                -- the rail keeps showing a category as selected while search is what is
                -- actually on screen.
                rail._lastCategory = nil
                for _, entry in ipairs(window.railItems) do
                    if entry.main and entry.main.Parent == rail.top then
                        if entry.active then
                            rail._lastCategory = entry
                        end
                        entry:SetActive(false)
                    end
                end
                searchModule.toggle(window)
            end,
        })
        table.insert(window.railItems, item)
        rail.searchItem = item
    end

    if window.settingsAction and window.settingsAction.action then
        window.settingsAction.action.Visible = false
        local item = Rail.new(window, {
            icon = constants.icons.settings,
            name = "Settings",
            order = 1,
            slot = "bottom",
            callback = function()
                if not window.rfSettings then
                    return
                end
                -- Settings is not a main category, so it has no subcategories. Leaving the
                -- previous category's strip up made it look like you were still inside that
                -- category while actually being in settings, with no way back to its pages.
                for _, tab in ipairs(window.tabs or {}) do
                    if tab.topbarItem and tab.railCategory ~= nil then
                        tab.topbarItem.Visible = false
                    end
                end
                rail._lastCategory = nil
                for _, item in ipairs(window.railItems) do
                    if item.main and item.main.Parent == rail.top then
                        if item.active then
                            rail._lastCategory = item
                        end
                        item:SetActive(false)
                    end
                end
                window.rfSettings:Select()
            end,
        })
        table.insert(window.railItems, item)
        rail.settingsItem = item
    end

    return rail
end

-- Shared button body for both icon items and the avatar.
local function buildButton(self, window, parent, order, cornerRadius)
    self.main = window:Create("TextButton", {
        Name = Rail.__type,
        Size = UDim2.fromOffset(ITEM_SIZE, ITEM_SIZE),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        LayoutOrder = order,
        ZIndex = 4,

        Parent = parent,
    }, { BackgroundColor3 = "AccentColor" })

    window:Create("UICorner", {
        CornerRadius = cornerRadius,

        Parent = self.main,
    })

    self.stroke = window:Create("UIStroke", {
        Thickness = 1,
        Transparency = 1, -- revealed only while active

        Parent = self.main,
    }, { Color = "AccentStroke" })

    -- the glow is the same UIShadow primitive the toggles use, kept fully transparent until
    -- the item goes active
    self.glow = window:CreateGlow(self.main, "AccentStroke", 14, 1)

    self.hover = window:CreateHoverOverlay(self.main)
end

local function bindHover(self)
    self.main.MouseEnter:Connect(function()
        if self.destroyed then
            return
        end
        variables.tweenService:Create(self.hover, hoverInfo, { BackgroundTransparency = 0.94 }):Play()
    end)
    self.main.MouseLeave:Connect(function()
        if self.destroyed then
            return
        end
        variables.tweenService:Create(self.hover, hoverInfo, { BackgroundTransparency = 1 }):Play()
    end)
end

-- An icon button. properties: icon, callback, active, order.
function Rail.new(window, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        window = assert(window, "Missing argument #1 (Window expected)"),
        icon = properties.icon or properties.Icon,
        callback = properties.callback or properties.Callback,
        name = properties.name or properties.Name or properties.tooltip or properties.Tooltip,
    }, Rail)

    assert(self.icon, "A rail item requires an icon.")

    local rail = ensureRail(window)
    -- "bottom" is reserved for the built-in controls; callers land in the category stack
    local slot = if properties.slot == "bottom" then rail.bottom else rail.top
    buildButton(self, window, slot, properties.order or properties.Order or 0, UDim.new(0, 10))

    self.iconImage = window:Create("ImageLabel", {
        Size = UDim2.new(1, -ICON_INSET * 2, 1, -ICON_INSET * 2),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Image = image.resolve(self.icon),
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 5,

        Parent = self.main,
    }, { ImageColor3 = "ContentColor" })

    bindHover(self)

    self.main.MouseButton1Click:Connect(function()
        if self.destroyed then
            return
        end
        if typeof(self.callback) == "function" then
            task.spawn(self.callback, self)
        end
    end)

    -- The first category selects itself. A hub should not have to remember to mark one
    -- active, and the brand is not a category, so the selection can never land on it.
    local isCategory = slot == rail.top
    local wantsActive = properties.active == true or properties.Active == true
    if isCategory and not rail._hasActiveCategory then
        wantsActive = true
    end
    if isCategory and wantsActive then
        rail._hasActiveCategory = true
    end

    self:SetActive(wantsActive)

    return self
end

-- Select this category and clear every sibling, so callers get single-selection behaviour
-- without tracking the previous item themselves.
function Rail:Select()
    if self.destroyed then
        return
    end
    local rail = self.window.rail
    if not rail then
        return
    end
    for _, item in ipairs(self.window.railItems) do
        if item ~= self and not item.isProfile and item.main and item.main.Parent == rail.top then
            item:SetActive(false)
        end
    end
    self:SetActive(true)
    self:_applyTabs()
end

-- Show only this category's subcategory tabs.
--
-- A tab belongs to exactly one main category, so each category carries its own strip rather
-- than every category sharing one set. Tabs created with no category are treated as global
-- and stay visible throughout, which keeps CreateTab working unchanged for hubs that never
-- use the rail.
function Rail:_applyTabs()
    local window = self.window
    if not window.tabs then
        return
    end

    -- Picking a category means leaving search. Without this the strip reappears while the
    -- search field is still up and the page still shows results, so the category looks
    -- selected but nothing under it is reachable.
    if window._searching then
        require(script.Parent.search).close(window, { showTabs = true })
    end

    local first = nil
    for _, tab in ipairs(window.tabs) do
        if tab.topbarItem and not tab.neglectSelector then
            local mine = tab.railCategory == nil or tab.railCategory == self
            tab.topbarItem.Visible = mine
            if mine and not first then
                first = tab
            end
        end
    end

    -- Land on a tab that is actually in this category. Checking "is the open tab now one of
    -- the visible ones" rather than "does it belong to another category" matters: the
    -- settings page has no category at all, so the narrower check left you stranded on
    -- settings with the strip restored but the content unchanged.
    local open = window.selectedTab
    local openVisible = false
    if open and open.topbarItem and not open.neglectSelector then
        openVisible = open.railCategory == nil or open.railCategory == self
    end
    if first and not openVisible then
        first:Select()
    end
end

-- The player avatar, pinned bottom-left. properties: userId, callback.
-- Defaults to the local player. The library draws the headshot and reports clicks; anything
-- shown about the account is the caller's job.
function Rail.profile(window, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local localPlayer = variables.localPlayer
    local self = setmetatable({
        window = assert(window, "Missing argument #1 (Window expected)"),
        userId = properties.userId or properties.UserId or (localPlayer and localPlayer.UserId) or 1,
        callback = properties.callback or properties.Callback,
        isProfile = true,
    }, Rail)

    local rail = ensureRail(window)
    buildButton(self, window, rail.bottom, 2, UDim.new(1, 0)) -- circular, last in the stack

    self.iconImage = window:Create("ImageLabel", {
        Size = UDim2.new(1, -4, 1, -4),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 5,

        Parent = self.main,
    })

    window:Create("UICorner", {
        CornerRadius = UDim.new(1, 0),

        Parent = self.iconImage,
    })

    self:SetUserId(self.userId)

    -- the avatar always carries its accent ring, so it reads as the account chip rather than
    -- just another icon
    self.stroke.Transparency = 0.35
    self.glow.Transparency = 0.55

    bindHover(self)

    self.main.MouseButton1Click:Connect(function()
        if self.destroyed then
            return
        end
        if typeof(self.callback) == "function" then
            task.spawn(self.callback, self)
        end
    end)

    return self
end

-- Point the avatar at a different user. Safe to call before the headshot has resolved.
function Rail:SetUserId(userId)
    if self.destroyed or not self.iconImage then
        return
    end
    self.userId = userId

    -- secure mode returns a cached-file uri asynchronously, so take the callback form and
    -- re-assign if a later value arrives while the chip is still alive
    local uri = image.avatar(userId, function(ready)
        if self.destroyed or not self.iconImage or not self.iconImage.Parent then
            return
        end
        self.iconImage.Image = ready
    end)
    self.iconImage.Image = uri
end

-- Light the item: accent fill, visible stroke, and the glow brought up.
function Rail:SetActive(active)
    if self.destroyed then
        return
    end
    self.active = active == true

    local fillTarget = if self.active then 0.15 else 1
    local strokeTarget = if self.active then 0 else (if self.isProfile then 0.35 else 1)
    local glowIdle = if self.isProfile then 0.55 else 1
    local glowTarget = if self.active then (self.window.theme and self.window.theme.AccentGlow or 0.15) else glowIdle

    variables.tweenService:Create(self.main, activeInfo, { BackgroundTransparency = fillTarget }):Play()
    variables.tweenService:Create(self.stroke, activeInfo, { Transparency = strokeTarget }):Play()
    variables.tweenService:Create(self.glow, activeInfo, { Transparency = glowTarget }):Play()
end

-- Fade one item's own parts. Split out so setShown can drive every item without knowing
-- which are icons and which is the avatar.
function Rail:_setShown(shown, info)
    if self.destroyed or not self.main then
        return
    end

    local fill = if not shown then 1 else (if self.active then 0.15 else 1)
    local stroke = if not shown then 1 else (if self.active then 0 else (if self.isProfile then 0.35 else 1))
    local glow = if not shown
        then 1
        else (if self.active
            then (self.window.theme and self.window.theme.AccentGlow or 0.15)
            else (if self.isProfile then 0.55 else 1))

    variables.tweenService:Create(self.main, info, { BackgroundTransparency = fill }):Play()
    variables.tweenService:Create(self.stroke, info, { Transparency = stroke }):Play()
    variables.tweenService:Create(self.glow, info, { Transparency = glow }):Play()

    if self.iconImage then
        variables.tweenService:Create(self.iconImage, info, { ImageTransparency = if shown then 0 else 1 }):Play()
    end
end

-- Fade the whole rail with the window.
--
-- The rail is parented to `main`, and Hide collapses main into a small pill rather than
-- hiding it -- so without this the rail keeps drawing over the collapsed "Tap to show" face.
-- Visible is only dropped once the fade has finished, so the collapse still animates.
--- `keepBrand` collapses everything except the emblem, for minimise: the bar still has to read
--- as the product. Hide passes it up, because the collapsed pill draws its own face.
function Rail.setShown(window, shown, info, keepBrand)
    local rail = window.rail
    if not rail or not rail.main then
        return
    end

    info = info or TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

    local brandStays = not shown and keepBrand == true
    setTitleInset(window, shown, info)

    if rail.brand then
        local brandFade = if shown or brandStays then 0 else 1
        variables.tweenService:Create(rail.brand, info, { ImageTransparency = brandFade }):Play()
    end

    -- the divider under the emblem separates it from the category stack, and there is no stack
    -- while collapsed - so it goes even when the mark stays
    if rail.brandDivider then
        variables.tweenService
            :Create(rail.brandDivider, info, { BackgroundTransparency = if shown then 0.8 else 1 })
            :Play()
    end

    -- token so a quick hide/show doesn't let a stale delayed Visible=false land on a rail
    -- that has since been brought back
    rail._shownToken = (rail._shownToken or 0) + 1
    local token = rail._shownToken

    if shown then
        rail.main.Visible = true
    end

    variables.tweenService
        :Create(rail.main, info, { BackgroundTransparency = if shown then SURFACE_IDLE else 1 })
        :Play()
    variables.tweenService
        :Create(rail.edgeCover, info, { BackgroundTransparency = if shown then SURFACE_IDLE else 1 })
        :Play()
    variables.tweenService
        :Create(rail.divider, info, { BackgroundTransparency = if shown then DIVIDER_IDLE else 1 })
        :Play()

    for _, item in ipairs(window.railItems) do
        item:_setShown(shown, info)
    end

    -- keeping the emblem means the rail frame has to stay up to carry it; everything else on it
    -- has already been faded out above
    if not shown and not brandStays then
        task.delay(info.Time, function()
            if rail._shownToken ~= token or not rail.main or not rail.main.Parent then
                return
            end
            rail.main.Visible = false
        end)
    end
end

function Rail:Destroy()
    if self.destroyed then
        return
    end
    self.destroyed = true
    if self.main then
        self.main:Destroy()
    end
end

return Rail
