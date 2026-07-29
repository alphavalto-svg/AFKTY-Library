local helpers = (_G :: any).__AFKTY_TEST_HELPERS

return function()
    local Window = helpers.requireComponent("window")
    local services = helpers.services

    describe("component resize", function()
        local window

        local function makeWindow(properties)
            properties = properties or {}
            properties.name = properties.name or "Resize Spec"
            properties.configuration = { autoSave = false, autoLoad = false }
            window = Window.new(properties)
            return window
        end

        -- geometry only moves once the window is actually up; _interactive() gates the grab
        local function shown(w)
            w.hidden = false
            w.hasShownOnce = true
            return w
        end

        local function press()
            return { UserInputType = Enum.UserInputType.MouseButton1 }
        end

        -- main's centre in absolute pixels, whether Position is still scale-based (fresh) or
        -- has been resolved to offsets (dragged or resized)
        local function centreOf(w)
            local screen = w.screenGui.AbsoluteSize
            local position = w.main.Position
            local x = position.X.Scale * screen.X + position.X.Offset
            local y = position.Y.Scale * screen.Y + position.Y.Offset
            return x, y
        end

        afterEach(function()
            if window and not window.unloaded then
                window:Unload()
            end
            window = nil
        end)

        describe("clampSize", function()
            it("floors a size below the minimum", function()
                local w, h = Window.clampSize(10, 10, nil)

                expect(w).to.equal(300)
                expect(h).to.equal(320)
            end)

            it("leaves a size inside the bounds alone", function()
                local w, h = Window.clampSize(600, 700, Vector2.new(1920, 1080))

                expect(w).to.equal(600)
                expect(h).to.equal(700)
            end)

            it("ceilings a size to the viewport less its margin", function()
                local w, h = Window.clampSize(5000, 5000, Vector2.new(1280, 720))

                expect(w).to.equal(1220)
                expect(h).to.equal(660)
            end)

            it("keeps the floor when the viewport is smaller than the minimum", function()
                -- a tiny screen must not shrink the window to nothing: the floor wins, the
                -- same way fitWindowSize refuses to go under it
                local w, h = Window.clampSize(475, 500, Vector2.new(200, 200))

                expect(w).to.equal(300)
                expect(h).to.equal(320)
            end)

            it("applies only the floor when there is no camera yet", function()
                local w, h = Window.clampSize(5000, 5000, nil)

                expect(w).to.equal(5000)
                expect(h).to.equal(5000)
            end)
        end)

        describe("clampCentreOnScreen", function()
            it("leaves a centred window alone", function()
                local x, y = Window.clampCentreOnScreen(640, 360, Vector2.new(400, 400), Vector2.new(1280, 720))

                expect(x).to.equal(640)
                expect(y).to.equal(360)
            end)

            it("pulls a window back from the right and bottom edges", function()
                local x, y = Window.clampCentreOnScreen(1270, 715, Vector2.new(400, 400), Vector2.new(1280, 720))

                expect(x).to.equal(1280 - 200 - 8)
                expect(y).to.equal(720 - 200 - 8)
            end)

            it("settles on the near edge when the window is bigger than the screen", function()
                -- the clamp would otherwise invert, so the low bound has to win
                local x, y = Window.clampCentreOnScreen(100, 100, Vector2.new(900, 900), Vector2.new(400, 400))

                expect(x).to.equal(458)
                expect(y).to.equal(458)
            end)
        end)

        describe("the grip", function()
            it("is built by default, so a hub gets resizing without asking", function()
                local w = makeWindow()

                expect(w.resize).to.be.ok()
                expect(w.resize.grip).to.be.ok()
                expect(w.resize.grip.Parent).to.equal(w.main)
            end)

            it("is omitted when resize is false", function()
                local w = makeWindow({ resize = false })

                expect(w.resize == nil).to.equal(true)
            end)

            it("accepts the capitalised prop, like the other window props", function()
                local w = makeWindow({ Resize = false })

                expect(w.resize == nil).to.equal(true)
            end)

            it("brightens on hover and settles back on leave", function()
                local w = shown(makeWindow())
                local resting = w.resize.grip.BackgroundTransparency

                w.resize.grip.MouseEnter:Fire()
                expect(w.resize.grip.BackgroundTransparency < resting).to.equal(true)

                w.resize.grip.MouseLeave:Fire()
                expect(w.resize.grip.BackgroundTransparency).to.equal(resting)
            end)

            it("hides while the window is collapsed and comes back with it", function()
                local w = shown(makeWindow())

                w.resize:SetShown(false)
                expect(w.resize.grip.Visible).to.equal(false)

                w.resize:SetShown(true)
                expect(w.resize.grip.Visible).to.equal(true)
            end)
        end)

        describe("_applySize", function()
            it("updates window.size, which every show and minimise path reads", function()
                local w = makeWindow()

                w:_applySize(600, 640)

                expect(w.size.X.Offset).to.equal(600)
                expect(w.size.Y.Offset).to.equal(640)
            end)

            it("clamps through the same bounds as clampSize", function()
                local w = makeWindow()

                w:_applySize(10, 10)

                expect(w.size.X.Offset).to.equal(300)
                expect(w.size.Y.Offset).to.equal(320)
            end)

            it("pins the top-left corner as the window grows", function()
                local w = shown(makeWindow())
                local startX, startY = centreOf(w)
                local startWidth = w.size.X.Offset
                local startHeight = w.size.Y.Offset
                local leftEdge = startX - startWidth / 2
                local topEdge = startY - startHeight / 2

                w:_applySize(startWidth + 100, startHeight + 80)

                -- main is centre-anchored, so the centre has to move out by half the growth or
                -- the window would grow leftwards and upwards too
                local grownX, grownY = centreOf(w)
                expect(grownX - (startWidth + 100) / 2).to.equal(leftEdge)
                expect(grownY - (startHeight + 80) / 2).to.equal(topEdge)
                expect(w.main.Size.X.Offset).to.equal(startWidth + 100)
                expect(w.main.Size.Y.Offset).to.equal(startHeight + 80)
            end)

            it("leaves the intro sweep intact while the window has never been shown", function()
                local w = makeWindow()

                -- a size restored from disk must not snap main to full size before the first
                -- reveal, or the intro animation starts already finished
                w:_applySize(600, 640)

                expect(w.size.X.Offset).to.equal(600)
                expect(w.main.Size.X.Offset).to.equal(550)
                expect(w.main.Size.Y.Offset).to.equal(0)
            end)

            it("leaves the collapsed bar alone while minimised", function()
                local w = shown(makeWindow())
                w.minimised = true
                local collapsed = w.main.Size

                w:_applySize(600, 640)

                -- the minimised bar is a fixed size; a resize only changes what it restores to
                expect(w.main.Size).to.equal(collapsed)
                expect(w.size.X.Offset).to.equal(600)
                expect(w.size.Y.Offset).to.equal(640)
            end)
        end)

        describe("minimise", function()
            it("collapses to a fixed bar, not the width the window was left at", function()
                local w = shown(makeWindow())
                w:_applySize(700, 640)

                w:ToggleMinimise()

                expect(w.minimised).to.equal(true)
                expect(w.main.Size.X.Offset).to.equal(300)
                expect(w.main.Size.Y.Offset).to.equal(66)
            end)

            it("pulls the title in beside the emblem while collapsed", function()
                local w = shown(makeWindow())
                w:CreateRailItem({ icon = 85628806611332, name = "Home" })
                local expanded = w.topContainer.Position.X.Offset

                w:ToggleMinimise()

                -- the rail is down, so the full rail-width inset would leave the title floating
                -- in an empty gap - and at a 300px bar it lands under the action icons
                expect(w.topContainer.Position.X.Offset < expanded).to.equal(true)
                expect(w.topContainer.Position.X.Offset).to.equal(52)

                w.animating = false
                w:ToggleMinimise()
                expect(w.topContainer.Position.X.Offset).to.equal(expanded)
            end)

            it("keeps the emblem on the bar, but not on the collapsed pill", function()
                local w = shown(makeWindow())
                w:CreateRailItem({ icon = 85628806611332, name = "Home" })

                w:ToggleMinimise()
                -- the bar still reads as the product, so the mark stays
                expect(w.rail.brand.ImageTransparency).to.equal(0)

                w.animating = false
                w:ToggleMinimise()
                w.animating = false
                w:Hide()

                -- the pill draws its own face, so the rail mark goes with the rest of the rail
                expect(w.rail.brand.ImageTransparency).to.equal(1)
            end)

            it("restores to the resized size, not the default", function()
                local w = shown(makeWindow())
                w:_applySize(700, 640)
                w:ToggleMinimise()
                w.animating = false -- the reset is on a task.delay the harness never reaches

                w:ToggleMinimise()

                expect(w.minimised).to.equal(false)
                expect(w.main.Size.X.Offset).to.equal(700)
                expect(w.main.Size.Y.Offset).to.equal(640)
            end)
        end)

        describe("the grab", function()
            it("arms on a press and disarms when the button comes up", function()
                local w = shown(makeWindow())

                w.resize.grip.InputBegan:Fire(press(), false)
                expect(w._resizing).to.equal(true)

                services.UserInputService.InputEnded:Fire(press())
                expect(w._resizing).to.equal(false)
            end)

            it("ignores a press the game already handled", function()
                local w = shown(makeWindow())

                w.resize.grip.InputBegan:Fire(press(), true)

                expect(w._resizing).to.equal(false)
            end)

            it("refuses to arm while the window is hidden or mid-animation", function()
                local w = makeWindow()

                -- still hidden: a grab here would fight the reveal tween
                w.resize.grip.InputBegan:Fire(press(), false)

                expect(w._resizing).to.equal(false)
            end)

            it("disarms when the client loses focus, so an alt-tab cannot leave it stuck", function()
                local w = shown(makeWindow())
                w.resize.grip.InputBegan:Fire(press(), false)

                services.UserInputService.WindowFocusReleased:Fire()

                expect(w._resizing).to.equal(false)
            end)

            it("resizes by how far the cursor moved, not to where it is", function()
                local w = shown(makeWindow())
                local startWidth = w.size.X.Offset
                local startHeight = w.size.Y.Offset

                w.resize.grip.InputBegan:Fire(press(), false)
                -- the harness cursor never moves, so a frame of drag is a zero delta. grabbing
                -- must not jump the corner to the cursor.
                services.RunService.RenderStepped:Fire(1 / 60)

                expect(w.size.X.Offset).to.equal(startWidth)
                expect(w.size.Y.Offset).to.equal(startHeight)
            end)

            it("does nothing on a frame when nothing is grabbed", function()
                local w = shown(makeWindow())
                local startWidth = w.size.X.Offset

                services.RunService.RenderStepped:Fire(1 / 60)

                expect(w.size.X.Offset).to.equal(startWidth)
            end)
        end)

        describe("teardown", function()
            it("goes with the window, rather than outliving it", function()
                local w = shown(makeWindow())
                local grip = w.resize.grip
                w.resize.grip.InputBegan:Fire(press(), false)

                w:Unload()

                expect(w.unloaded).to.equal(true)
                -- registered through window:Create, so Unload destroys it with everything else
                expect(grip.Parent == nil).to.equal(true)
                expect(#w.connections).to.equal(0)
            end)
        end)
    end)
end
