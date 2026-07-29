local helpers = (_G :: any).__AFKTY_TEST_HELPERS

return function()
    local Window = helpers.requireComponent("window")

    -- The hoverable rows rest unlit and light only under the cursor, so a page of elements
    -- reads as a quiet list. Surfaces that have no hover state keep a constant edge, because
    -- nothing else tells you where they end. These pin that split: it is a visual rule with
    -- nothing else enforcing it, and it silently reverts the moment someone reuses the wrong
    -- theme key.
    describe("element stroke rests hidden and lights on hover", function()
        local window

        local function makeWindow()
            window = Window.new({
                name = "Stroke Spec",
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

        it("rests the hoverable rows at the hidden value, not the panel value", function()
            local w = makeWindow()
            local tab = w:CreateTab({ name = "Rows", icon = 93364949241311 })

            local rows = {
                button = tab:CreateButton({ name = "Button" }),
                toggle = tab:CreateToggle({ name = "Toggle", flag = "StrokeToggle" }),
                slider = tab:CreateSlider({ name = "Slider", flag = "StrokeSlider", range = { 0, 10 } }),
                input = tab:CreateInput({ name = "Input", flag = "StrokeInput" }),
                keybind = tab:CreateKeybind({ name = "Keybind", flag = "StrokeKeybind" }),
                colorpicker = tab:CreateColorPicker({ name = "Colour", flag = "StrokeColor" }),
            }

            for name, element in rows do
                -- every one of these must opt into hover lighting, or it would rest hidden
                -- with nothing to bring it back
                expect(element.hoverLit).to.equal(true)
                expect(element.stroke).to.be.ok()
                if element.hoverLit ~= true then
                    error("row '" .. name .. "' rests hidden but never lights on hover")
                end
            end

            -- a minimal slider is track-only and has no title; the shared hover must tolerate
            -- that rather than erroring when the cursor crosses it
            local minimal = tab:CreateSlider({ name = "Minimal", minimal = true, forgetState = true })
            expect(minimal.hoverLit).to.equal(true)
            expect(minimal.title).never.to.be.ok()
        end)

        it("keeps a constant edge on surfaces that never light up", function()
            local w = makeWindow()
            local tab = w:CreateTab({ name = "Surfaces", icon = 93364949241311 })

            -- a stat tile is a read-out, not a control: no hover, so it keeps its outline
            local stat = tab:CreateStat({ name = "Revenue", value = 10 })
            expect(stat.hoverLit).never.to.be.ok()

            -- the dropdown is panel-styled rather than body-styled, so it is unaffected by
            -- the row resting value
            local dropdown = tab:CreateDropdown({
                name = "Choice",
                flag = "StrokeDropdown",
                options = { "One", "Two" },
                value = "One",
            })
            expect(dropdown.hoverLit).never.to.be.ok()
        end)

        it("resolves the two resting values from the theme", function()
            local w = makeWindow()

            -- the row value must actually be hidden, and the two must differ, or the whole
            -- rest/hover split collapses back to always-on edges
            expect(w.theme.ElementStrokeRestTransparency).to.equal(1)
            expect(w.theme.ElementStrokeTransparency).to.equal(0)
            expect(w.theme.ElementStrokeHoverTransparency).to.equal(0)
        end)

        it("falls back to the default resting value for a partial custom theme", function()
            -- a theme that only recolours must not lose the hidden resting edge
            window = Window.new({
                name = "Partial Theme",
                theme = { AccentColor = Color3.fromRGB(96, 160, 255) },
                configuration = { autoSave = false, autoLoad = false },
            })

            expect(window.theme.ElementStrokeRestTransparency).to.equal(1)
        end)
    end)
end
