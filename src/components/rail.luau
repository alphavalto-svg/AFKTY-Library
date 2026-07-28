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

local RAIL_WIDTH = 56
local ITEM_SIZE = 38
local ITEM_PADDING = 8
local EDGE_PADDING = 12
local ICON_INSET = 9 -- icon is ITEM_SIZE - 2*ICON_INSET square, centred

local hoverInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local activeInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

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

    -- the title block is left-anchored, so it only needs the full offset, not half
    if window.topContainer then
        local pos = window.topContainer.Position
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
        BackgroundTransparency = 0.6,
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
        BackgroundTransparency = 0.6,
        BorderSizePixel = 0,
        ZIndex = 2,

        Parent = rail.main,
    }, { BackgroundColor3 = "StatBackground" })

    -- a hairline down the rail's inner edge, so it reads as a surface rather than a tint
    rail.divider = window:Create("Frame", {
        Name = "RailDivider",
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, -1, 0, 0),
        BackgroundTransparency = 0.85,
        BorderSizePixel = 0,
        ZIndex = 3,

        Parent = rail.main,
    }, { BackgroundColor3 = "SurfaceStroke" })

    -- icon stack, from the top
    rail.top = window:Create("Frame", {
        Name = "RailItems",
        Size = UDim2.new(1, 0, 1, -(ITEM_SIZE + EDGE_PADDING * 2)),
        Position = UDim2.new(0, 0, 0, EDGE_PADDING),
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

    -- avatar slot, pinned to the bottom
    rail.bottom = window:Create("Frame", {
        Name = "RailProfile",
        Size = UDim2.new(1, 0, 0, ITEM_SIZE),
        Position = UDim2.new(0, 0, 1, -EDGE_PADDING),
        AnchorPoint = Vector2.new(0, 1),
        BackgroundTransparency = 1,
        ZIndex = 3,

        Parent = rail.main,
    })

    window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = rail.bottom,
    })

    insetForRail(window)

    window.rail = rail
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
    buildButton(self, window, rail.top, properties.order or properties.Order or 0, UDim.new(0, 10))

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

    self:SetActive(properties.active == true or properties.Active == true)

    return self
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
    buildButton(self, window, rail.bottom, 0, UDim.new(1, 0)) -- circular

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
