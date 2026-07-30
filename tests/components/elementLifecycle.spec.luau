local helpers = (_G :: any).__AFKTY_TEST_HELPERS

return function()
    local Window = helpers.requireComponent("window")
    local variables = helpers.requireUtility("variables")

    describe("element lifecycle", function()
        local window

        local function makeTab()
            window = Window.new({
                name = "Lifecycle Spec",
                configuration = { autoSave = false, autoLoad = false },
            })
            return window:CreateTab({ name = "Elements" })
        end

        afterEach(function()
            if window and not window.unloaded then
                window:Unload()
            end
            window = nil
        end)

        -- The constructor took a string happily while Set asserted on one, so a hub that seeded a
        -- stat with "0" only found out on the first update -- and an assert raised outside a
        -- guarded callback lands on the console, which is the thing secure mode exists to prevent.
        describe("Statistic accepts the same values at both ends", function()
            it("coerces a numeric string given at construction", function()
                local stat = makeTab():CreateStat({ name = "s", value = "42" })

                expect(stat.value).to.equal(42)
                expect(stat._hasValue).to.equal(true)
            end)

            it("coerces a numeric string given to Set", function()
                local stat = makeTab():CreateStat({ name = "s", value = 1 })

                stat:Set("99")

                expect(stat.value).to.equal(99)
            end)

            it("ignores a value it cannot use instead of throwing", function()
                local stat = makeTab():CreateStat({ name = "s", value = 5 })

                -- throwing here would reach the console through any hub that called Set outside
                -- a guarded callback, and secure mode has no way to report it either
                for _, junk in { "not a number", {}, true, Vector2.new(1, 1) } do
                    local ok, err = pcall(function()
                        stat:Set(junk)
                    end)
                    expect(ok).to.equal(true)
                    expect(err).never.to.be.ok()
                end
                expect(pcall(function()
                    stat:Set(nil)
                end)).to.equal(true)

                expect(stat.value).to.equal(5)
            end)

            it("refuses nan and infinity, which have no readable form", function()
                local stat = makeTab():CreateStat({ name = "s", value = 3 })

                stat:Set(0 / 0)
                stat:Set(math.huge)

                expect(stat.value).to.equal(3)
            end)

            it("treats a junk seed as no value at all", function()
                local stat = makeTab():CreateStat({ name = "s", value = "abc" })

                expect(stat.value).to.equal(0)
                -- the first real Set should establish the baseline rather than report a change
                expect(stat._hasValue).to.equal(false)
            end)
        end)

        -- A hub could drop a whole tab but not one control it had built, so anything conditional
        -- had to be rebuilt by tearing the tab down around it.
        describe("elements can remove themselves", function()
            it("gives every element a Destroy", function()
                local tab = makeTab()

                expect(typeof(tab:CreateButton({ name = "b" }).Destroy)).to.equal("function")
                expect(typeof(tab:CreateToggle({ name = "t" }).Destroy)).to.equal("function")
                expect(typeof(tab:CreateSlider({ name = "s", range = { 0, 1 } }).Destroy)).to.equal("function")
            end)

            it("drops the element from its tab and destroys its instances", function()
                local tab = makeTab()
                local button = tab:CreateButton({ name = "goes away" })
                local main = button.main

                expect(table.find(tab.elements, button)).to.be.ok()

                expect(button:Destroy()).to.equal(true)

                expect(table.find(tab.elements, button)).never.to.be.ok()
                expect(main.Parent).never.to.be.ok()
            end)

            it("releases the flag so the name can be reused", function()
                local tab = makeTab()
                local toggle = tab:CreateToggle({ name = "t", flag = "LifecycleFlag" })

                expect(window.controls.LifecycleFlag).to.equal(toggle)

                toggle:Destroy()

                expect(window.controls.LifecycleFlag).never.to.be.ok()
            end)

            it("is safe to call twice", function()
                local tab = makeTab()
                local button = tab:CreateButton({ name = "b" })

                expect(button:Destroy()).to.equal(true)
                expect(button:Destroy()).to.equal(false)
            end)
        end)

        -- The ScreenGui above it is already a GUID; naming this one after the window put the
        -- hub's product name back into the tree in plaintext for anything that can walk it.
        it("does not write the window name into the instance tree", function()
            window = Window.new({
                name = "Totally Identifying Hub Name",
                configuration = { autoSave = false, autoLoad = false },
            })

            expect(window.main.Name).never.to.equal("Totally Identifying Hub Name")
            expect(#window.main.Name).to.equal(36)
            expect(window.name).to.equal("Totally Identifying Hub Name")

            local _ = variables
        end)
    end)
end
