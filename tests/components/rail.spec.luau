local helpers = (_G :: any).__AFKTY_TEST_HELPERS

return function()
    local Window = helpers.requireComponent("window")

    describe("component rail", function()
        local window

        local function makeWindow()
            window = Window.new({
                name = "Rail Spec",
                subtitle = "Harness",
                showName = "Rail",
                configuration = { autoSave = false, autoLoad = false },
            })
            return window
        end

        afterEach(function()
            if window and not window.unloaded then
                window:Unload()
            end
            window = nil
        end)

        it("does not build a rail, or move anything, until one is asked for", function()
            local w = makeWindow()

            expect(w.rail == nil).to.equal(true)
            expect(#w.railItems).to.equal(0)

            -- the whole point of building it lazily: a window with no rail keeps the
            -- geometry it has always had, so no existing layout can shift
            expect(w.tabList.Size.X.Offset).to.equal(0)
            expect(w.tabList.Position.X.Offset).to.equal(0)
            expect(w.elements.Size.X.Offset).to.equal(0)
        end)

        it("builds the rail on first use and insets the content once", function()
            local w = makeWindow()

            local tabWidth = w.tabList.Size.X.Offset
            local elementsWidth = w.elements.Size.X.Offset
            local titleX = w.topContainer.Position.X.Offset

            w:CreateRailItem({ icon = 85628806611332, name = "Home" })

            expect(w.rail).to.be.ok()
            expect(w.rail.main).to.be.ok()

            local railWidth = w.rail.main.Size.X.Offset
            expect(railWidth > 0).to.equal(true)

            -- narrowed by the rail, nudged right by half so it stays centred in what is left
            expect(w.tabList.Size.X.Offset).to.equal(tabWidth - railWidth)
            expect(w.tabList.Position.X.Offset).to.equal(railWidth / 2)
            expect(w.elements.Size.X.Offset).to.equal(elementsWidth - railWidth)
            -- the title is left-anchored, so it takes the full offset rather than half
            expect(w.topContainer.Position.X.Offset).to.equal(titleX + railWidth)

            -- a second item reuses the rail; insetting twice would push content off-window
            w:CreateRailItem({ icon = 129180860773723, name = "Settings" })
            expect(#w.railItems).to.equal(2)
            expect(w.tabList.Size.X.Offset).to.equal(tabWidth - railWidth)
            expect(w.topContainer.Position.X.Offset).to.equal(titleX + railWidth)
        end)

        it("fires an item's callback when clicked", function()
            local w = makeWindow()
            local clicks = 0

            local item = w:CreateRailItem({
                icon = 85628806611332,
                callback = function()
                    clicks += 1
                end,
            })

            item.main.MouseButton1Click:Fire()
            expect(clicks).to.equal(1)

            item.main.MouseButton1Click:Fire()
            expect(clicks).to.equal(2)
        end)

        it("tracks its active state and stops responding once destroyed", function()
            local w = makeWindow()
            local clicks = 0
            local item = w:CreateRailItem({
                icon = 85628806611332,
                active = true,
                callback = function()
                    clicks += 1
                end,
            })

            expect(item.active).to.equal(true)
            item:SetActive(false)
            expect(item.active).to.equal(false)
            item:SetActive(true)
            expect(item.active).to.equal(true)

            item:Destroy()
            expect(item.destroyed).to.equal(true)

            -- a destroyed item must not keep invoking its callback
            item:SetActive(false)
            expect(item.active).to.equal(true)

            -- and destroying twice should be harmless
            item:Destroy()
            expect(clicks).to.equal(0)
        end)

        it("hovers without touching the callback", function()
            local w = makeWindow()
            local clicks = 0
            local item = w:CreateRailItem({
                icon = 85628806611332,
                callback = function()
                    clicks += 1
                end,
            })

            item.main.MouseEnter:Fire()
            item.main.MouseLeave:Fire()
            expect(clicks).to.equal(0)
        end)

        it("draws a profile chip that defaults to the local player", function()
            local w = makeWindow()

            local profile = w:CreateRailProfile({})
            expect(profile).to.be.ok()
            expect(profile.isProfile).to.equal(true)
            expect(w.railProfile).to.equal(profile)
            expect(profile.userId).to.be.ok()
            expect(profile.iconImage.Image ~= "").to.equal(true)

            -- the chip carries its ring at rest, so it reads as the account rather than an icon
            expect(profile.stroke.Transparency < 1).to.equal(true)
        end)

        it("repoints the profile at another user", function()
            local w = makeWindow()
            local profile = w:CreateRailProfile({ userId = 1 })
            local first = profile.iconImage.Image

            profile:SetUserId(261)
            expect(profile.userId).to.equal(261)
            expect(profile.iconImage.Image ~= first).to.equal(true)

            -- a destroyed chip must not write to an instance that is already gone
            profile:Destroy()
            profile:SetUserId(1)
            expect(profile.userId).to.equal(261)
        end)

        it("reports profile clicks so the caller can decide what to show", function()
            local w = makeWindow()
            local seen = nil

            local profile = w:CreateRailProfile({
                userId = 42,
                callback = function(chip)
                    seen = chip.userId
                end,
            })

            profile.main.MouseButton1Click:Fire()
            expect(seen).to.equal(42)
        end)

        it("rejects an item with no icon", function()
            local w = makeWindow()
            local ok = pcall(function()
                w:CreateRailItem({ name = "No icon" })
            end)
            expect(ok).to.equal(false)
        end)
    end)
end
