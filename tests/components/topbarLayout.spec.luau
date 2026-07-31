local helpers = (_G :: any).__AFKTY_TEST_HELPERS

return function()
    local Window = helpers.requireComponent("window")

    describe("component window topbar layout", function()
        local window

        -- the same two insets window.luau reserves with; kept here so a change there has to be
        -- made deliberately rather than silently agreeing with whatever the code now does
        local actionInset = 20
        local titleActionGap = 10

        -- what Window minimises to, and the width the title and the actions used to collide at
        local minimisedWidth = 300

        local function makeWindow()
            window = Window.new({
                name = "Topbar Spec",
                configuration = { autoSave = false, autoLoad = false },
            })
            return window
        end

        -- the harness writes AbsoluteSize straight onto the instance table, so nothing is
        -- raised for it; a real client gets this signal from the engine as the row lays out
        local function withActionRow(w, width)
            w.actionContainer.AbsoluteSize = Vector2.new(width, 24)
            w.actionContainer:GetPropertyChangedSignal("AbsoluteSize"):Fire()
            return w
        end

        afterEach(function()
            if window and not window.unloaded then
                window:Unload()
            end
            window = nil
        end)

        it("sizes the title block against the room the actions leave", function()
            local w = withActionRow(makeWindow(), 111)
            local left = w.topContainer.Position.X.Offset

            expect(w.topContainer.Size.X.Scale).to.equal(1)
            expect(w.topContainer.Size.X.Offset).to.equal(-(left + 111 + actionInset + titleActionGap))
        end)

        it("refits when the action row grows", function()
            local w = withActionRow(makeWindow(), 111)
            local before = w.topContainer.Size.X.Offset

            withActionRow(w, 140)

            expect(w.topContainer.Size.X.Offset).to.equal(before - 29)
        end)

        it("keeps the title block clear of the actions at the minimised width", function()
            local w = withActionRow(makeWindow(), 111)

            local left = w.topContainer.Position.X.Offset
            local titleRight = left + minimisedWidth + w.topContainer.Size.X.Offset
            local actionsLeft = minimisedWidth - actionInset - 111

            expect(titleRight <= actionsLeft).to.equal(true)
            expect(actionsLeft - titleRight).to.equal(titleActionGap)
        end)

        it("clips the title block, so an overlong name is cut instead of overlapping", function()
            expect(makeWindow().topContainer.ClipsDescendants).to.equal(true)
        end)

        describe("minimised with a rail", function()
            -- the rail draws its emblem from window.icon, the same image the topbar icon uses,
            -- and minimise keeps that emblem, so both would sit in the bar together
            local function railedWindow()
                window = Window.new({
                    name = "Topbar Spec",
                    icon = 85628806611332,
                    configuration = { autoSave = false, autoLoad = false },
                })
                window:CreateRailItem({ name = "One", icon = 85628806611332, callback = function() end })
                window.hidden = false
                window.hasShownOnce = true
                return window
            end

            it("drops the topbar icon, leaving the rail emblem to stand for it", function()
                local w = railedWindow()
                expect(w.topbarIcon.Visible).to.equal(true)

                w:ToggleMinimise()

                expect(w.topbarIcon.Visible).to.equal(false)
            end)

            it("brings the topbar icon back on restore", function()
                local w = railedWindow()

                w:ToggleMinimise()
                w.animating = false
                w:ToggleMinimise()

                expect(w.topbarIcon.Visible).to.equal(true)
            end)
        end)

        describe("tags while minimised", function()
            -- the row is hidden inside a task.delay, which the harness runs straight through,
            -- so the settled state is already in place when ToggleMinimise returns
            local function minimise(w)
                w:ToggleMinimise()
                return w
            end

            local function restore(w)
                w.animating = false
                w:ToggleMinimise()
                return w
            end

            local function taggedWindow()
                window = Window.new({
                    name = "Topbar Spec",
                    configuration = { autoSave = false, autoLoad = false },
                })
                window.hidden = false
                window.hasShownOnce = true
                window:CreateTag({ text = "v1.0.3" })
                return window
            end

            it("takes the tag row down with the rest of the bar", function()
                local w = taggedWindow()
                expect(w.tagContainer.Visible).to.equal(true)

                minimise(w)

                expect(w.tagContainer.Visible).to.equal(false)
            end)

            it("brings the tag row back on restore", function()
                local w = restore(minimise(taggedWindow()))

                expect(w.tagContainer.Visible).to.equal(true)
            end)

            it("leaves the row down when its last tag went away while minimised", function()
                local w = taggedWindow()
                minimise(w)

                w.tags[1]:Remove()
                restore(w)

                expect(w.tagContainer.Visible).to.equal(false)
            end)

            it("does not let a tag added while minimised pull the row up", function()
                local w = minimise(taggedWindow())

                w:CreateTag({ text = "late" })

                expect(w.tagContainer.Visible).to.equal(false)
            end)
        end)
    end)
end
