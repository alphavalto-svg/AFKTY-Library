local helpers = (_G :: any).__AFKTY_TEST_HELPERS

return function()
    local Window = helpers.requireComponent("window")

    -- The library ships exactly one theme, `default`, and resolves every other request against
    -- it. That is a deliberate shape rather than an oversight: a theme is a partial override
    -- table, so `default` is the floor every missing key lands on, and adding a palette later
    -- means dropping a file in src/themes/ with no code change anywhere. These pin the contract
    -- that makes that true, so adding the second theme cannot quietly break the first.
    describe("theming with a single built-in", function()
        local window

        local function makeWindow(theme)
            window = Window.new({
                name = "Theme Spec",
                theme = theme,
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

        it("builds a complete theme from the only name that ships", function()
            local w = makeWindow("default")

            expect(w.theme).to.be.ok()
            expect(typeof(w.theme.AccentColor)).to.equal("Color3")
            expect(typeof(w.theme.CornerRoundness)).to.equal("UDim")
        end)

        it("falls back to default rather than failing on a name that does not exist", function()
            -- a hub written against upstream's six-theme list must still get a working window,
            -- not a crash and not a half-styled one
            local w = makeWindow("cobalt")
            local reference = Window.new({
                name = "Reference",
                theme = "default",
                configuration = { autoSave = false, autoLoad = false },
            })

            expect(w.theme.AccentColor).to.equal(reference.theme.AccentColor)
            expect(w.theme.CornerRoundness).to.equal(reference.theme.CornerRoundness)

            reference:Unload()
        end)

        it("is case insensitive about the name", function()
            local w = makeWindow("DEFAULT")
            local reference = Window.new({
                name = "Reference",
                theme = "default",
                configuration = { autoSave = false, autoLoad = false },
            })

            expect(w.theme.AccentColor).to.equal(reference.theme.AccentColor)

            reference:Unload()
        end)

        it("takes a partial table and inherits the rest, which is how you recolour today", function()
            local custom = Color3.fromRGB(80, 160, 255)
            local w = makeWindow({ AccentColor = custom })
            local reference = Window.new({
                name = "Reference",
                theme = "default",
                configuration = { autoSave = false, autoLoad = false },
            })

            expect(w.theme.AccentColor).to.equal(custom)
            -- everything not named still comes from default
            expect(w.theme.CornerRoundness).to.equal(reference.theme.CornerRoundness)

            reference:Unload()
        end)

        it("survives a theme argument of the wrong type", function()
            expect(pcall(function()
                Window.new({
                    name = "Junk Theme",
                    theme = 12345,
                    configuration = { autoSave = false, autoLoad = false },
                }):Unload()
            end)).to.equal(true)
        end)

        it("resets keys an earlier custom theme set when switching back by name", function()
            local w = makeWindow({ AccentColor = Color3.fromRGB(255, 0, 0) })
            local reference = Window.new({
                name = "Reference",
                theme = "default",
                configuration = { autoSave = false, autoLoad = false },
            })

            -- a named theme is a full switch, so it must not leave the old accent behind
            w:ChangeTheme("default")

            expect(w.theme.AccentColor).to.equal(reference.theme.AccentColor)

            reference:Unload()
        end)

        it("keeps a partial ChangeTheme table scoped to the keys it names", function()
            local w = makeWindow("default")
            local before = w.theme.CornerRoundness
            local custom = Color3.fromRGB(10, 20, 30)

            w:ChangeTheme({ AccentColor = custom })

            expect(w.theme.AccentColor).to.equal(custom)
            expect(w.theme.CornerRoundness).to.equal(before)
        end)
    end)
end
