local helpers = (_G :: any).__AFKTY_TEST_HELPERS

return function()
    local runtime = helpers.requireUtility("runtime")

    -- Where a ScreenGui lives decides whether a game script can enumerate it, so this is the
    -- one piece of secure mode with real consequences if it silently stops working. gethui()
    -- hands back a container the game cannot walk; without it the ScreenGui itself has to be
    -- passed to the executor's protect call before it is parented, and the order matters.
    describe("gui protection", function()
        local originalResolve
        local originalHidden

        beforeEach(function()
            originalResolve = runtime.resolveProtect
            originalHidden = runtime.guiContainerHidden
        end)

        afterEach(function()
            runtime.resolveProtect = originalResolve
            runtime.guiContainerHidden = originalHidden
        end)

        it("protects the gui before parenting it when the container is not hidden", function()
            local protectedWith = nil
            local parentAtProtectTime = "unset"

            runtime.guiContainerHidden = false
            runtime.resolveProtect = function()
                return function(gui)
                    protectedWith = gui
                    -- the protect call has to happen while the gui is still unparented, or it
                    -- is briefly visible in CoreGui before being hidden
                    parentAtProtectTime = gui.Parent
                end
            end

            local gui = Instance.new("ScreenGui")
            runtime.parentGui(gui)

            expect(protectedWith).to.equal(gui)
            expect(parentAtProtectTime).to.equal(nil)
            expect(gui.Parent).to.equal(runtime.guiContainer)
        end)

        it("skips the protect call when gethui already hid the container", function()
            local called = false

            runtime.guiContainerHidden = true
            runtime.resolveProtect = function()
                called = true
                return function() end
            end

            local gui = Instance.new("ScreenGui")
            runtime.parentGui(gui)

            -- protecting a gui that is already out of reach is a no-op at best and throws on
            -- some executors, so it must not even be looked up
            expect(called).to.equal(false)
            expect(gui.Parent).to.equal(runtime.guiContainer)
        end)

        it("still parents when no protect function exists", function()
            runtime.guiContainerHidden = false
            runtime.resolveProtect = function()
                return nil
            end

            local gui = Instance.new("ScreenGui")
            runtime.parentGui(gui)

            expect(gui.Parent).to.equal(runtime.guiContainer)
        end)

        it("still parents when the protect call throws", function()
            runtime.guiContainerHidden = false
            runtime.resolveProtect = function()
                return function()
                    error("executor blew up")
                end
            end

            local gui = Instance.new("ScreenGui")
            runtime.parentGui(gui)

            -- a broken protect implementation must not take the whole UI down with it
            expect(gui.Parent).to.equal(runtime.guiContainer)
        end)

        it("resolves a protect function from the executor environment", function()
            -- the real lookup: syn.protect_gui first, then a bare protectgui
            local resolved = runtime.resolveProtect()
            -- the harness is not an executor, so there is nothing to find -- the contract is
            -- that this returns nil rather than throwing
            expect(resolved).never.to.be.ok()
        end)
    end)
end
