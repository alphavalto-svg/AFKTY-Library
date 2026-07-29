--!nonstrict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local Resize = {}
Resize.__index = Resize
Resize.__type = "Resize"

-- Utility
local utility = script.Parent.Parent.utility

-- Variables
local variables = require(utility.variables)
local constants = require(utility.constants)

-- Deliberately small and quiet. It sits inside main's bottom-right corner, while the drag bar
-- hangs below the window entirely, so the two can never contend for the same grab.
local GRIP_SIZE = 16
local GRIP_INSET = 4
local GRIP_IDLE = 0.75
local GRIP_HOVER = 0.35

local hoverInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

function Resize.new(window, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        window = assert(window, "Missing argument #1 (Window expected)"),
    }, Resize)

    self.grip = self.window:Create("TextButton", {
        Name = "ResizeGrip",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -GRIP_INSET, 1, -GRIP_INSET),
        Size = UDim2.fromOffset(GRIP_SIZE, GRIP_SIZE),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = GRIP_IDLE,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ZIndex = constants.zIndex.resizeGrip,

        Parent = self.window.main,
    })

    self.window:Create("UICorner", {
        CornerRadius = UDim.new(0, 4),

        Parent = self.grip,
    })

    local grabbed = false
    local startMouse = Vector2.zero
    local startSize = Vector2.zero

    self.window:Connect(self.grip.MouseEnter, function()
        if self.window:_interactive() then
            variables.tweenService:Create(self.grip, hoverInfo, { BackgroundTransparency = GRIP_HOVER }):Play()
        end
    end)

    self.window:Connect(self.grip.MouseLeave, function()
        -- a grab keeps it lit even as the cursor runs off the corner it is dragging
        local settling = not grabbed and self.window:_interactive()
        if settling then
            variables.tweenService:Create(self.grip, hoverInfo, { BackgroundTransparency = GRIP_IDLE }):Play()
        end
    end)

    -- Letting go, however it happens: the button coming up, or the client losing focus with it
    -- still held. Without the second, an alt-tab mid-grab leaves the resize armed and the
    -- window jumps the moment you are back - the same trap the drag bar had.
    local function release()
        if not grabbed then
            return
        end
        grabbed = false
        self.window._resizing = false

        -- persist on release, never per frame: this writes a file
        self.window.settings.windowWidth = self.window.size.X.Offset
        self.window.settings.windowHeight = self.window.size.Y.Offset
        self.window:SaveSettings()

        if self.window:_interactive() then
            variables.tweenService:Create(self.grip, hoverInfo, { BackgroundTransparency = GRIP_IDLE }):Play()
        end
    end

    self.window:Connect(self.grip.InputBegan, function(input, processed)
        if processed then
            return
        end

        local inputType = input.UserInputType.Name
        if inputType ~= "MouseButton1" and inputType ~= "Touch" then
            return
        end

        -- a grab mid-reveal would fight the tween that is still sizing the window
        if not self.window:_interactive() then
            return
        end

        grabbed = true
        self.window._resizing = true
        startMouse = variables.userInputService:GetMouseLocation()
        startSize = Vector2.new(self.window.size.X.Offset, self.window.size.Y.Offset)

        variables.tweenService:Create(self.grip, hoverInfo, { BackgroundTransparency = 0 }):Play()
    end)

    self.window:Connect(variables.userInputService.InputEnded, function(input)
        local inputType = input.UserInputType.Name
        if inputType == "MouseButton1" or inputType == "Touch" then
            release()
        end
    end)

    self.window:Connect(variables.userInputService.WindowFocusReleased, release)

    -- Size by how far the cursor has travelled since the grab, never to where it happens to
    -- be: the corner keeps whatever offset it was grabbed at instead of snapping to the
    -- pointer on the first frame.
    self.window:Connect(variables.runService.RenderStepped, function()
        if not grabbed then
            return
        end

        -- hidden or mid-animation means the grab went stale under us, so drop it here rather
        -- than let it wake up later and yank the window to whatever size the cursor implies
        if not self.window:_interactive() then
            release()
            return
        end

        local travelled = variables.userInputService:GetMouseLocation() - startMouse
        self.window:_applySize(startSize.X + travelled.X, startSize.Y + travelled.Y)
    end)

    return self
end

-- Collapse takes the grip down with the rest of the window furniture, and restore brings it
-- back. Minimised, there is nothing left to size.
function Resize:SetShown(shown)
    self.grip.Visible = shown
end

return Resize
