local helpers = (_G :: any).__AFKTY_TEST_HELPERS

return function()
    local AFKTY = helpers.requireAFKTY()
    local image = helpers.requireUtility("image")
    local variables = helpers.requireUtility("variables")

    -- Secure mode blanks any icon it cannot serve from the on-disk cache, which is every asset
    -- id a hub passes in beyond the library's own built-ins. That used to happen with no signal
    -- at all, so the only symptom was missing artwork and no way to know why.
    describe("secure mode blocked icons", function()
        local window
        local originalSecureMode
        local originalPreload
        local originalOnBlock
        local originalLoadFont

        beforeEach(function()
            originalSecureMode = variables.secureMode
            originalPreload = image.preload
            originalOnBlock = image.onBlock
            originalLoadFont = variables.fontManager.loadFont

            -- settle immediately with nothing failed, so the only notification that can appear
            -- is the blocked-icon one this spec is about
            image.preload = function(onSettled)
                if onSettled then
                    onSettled(0)
                end
            end
            variables.fontManager.loadFont = function(_, _asset, weight)
                return Font.new("font://secure", weight, Enum.FontStyle.Normal)
            end
        end)

        afterEach(function()
            if window and not window.unloaded then
                window:Unload()
            end
            window = nil
            variables.secureMode = originalSecureMode
            image.preload = originalPreload
            image.onBlock = originalOnBlock
            variables.fontManager.loadFont = originalLoadFont
        end)

        it("wires a block handler while secure mode is on", function()
            variables.secureMode = true
            image.onBlock = nil

            window = AFKTY:CreateWindow({
                name = "Secure Icons",
                configuration = { autoSave = false, autoLoad = false },
            })

            expect(image.onBlock).to.be.ok()
        end)

        it("leaves the handler alone outside secure mode", function()
            variables.secureMode = false
            image.onBlock = nil

            window = AFKTY:CreateWindow({
                name = "Normal Icons",
                configuration = { autoSave = false, autoLoad = false },
            })

            -- nothing is blocked outside secure mode, so there is nothing to report
            expect(image.onBlock).never.to.be.ok()
        end)

        it("stays quiet about the library's own icons, which appear once cached", function()
            -- construction resolves the chrome icons before anything has cached, so these run
            -- through onBlock on every cold start. Reporting them would tell the dev to cache
            -- icons that are about to appear on their own.
            local WindowClass = helpers.requireComponent("window")
            local originalNotify = WindowClass.Notify
            local notified = 0
            WindowClass.Notify = function()
                notified += 1
            end

            variables.secureMode = true
            image.onBlock = nil

            window = AFKTY:CreateWindow({
                name = "Secure Icons",
                configuration = { autoSave = false, autoLoad = false },
            })

            local constants = helpers.requireUtility("constants")
            image.onBlock(constants.icons.close)
            image.onBlock(constants.icons.settings)
            image.onBlock("rbxassetid://" .. tostring(constants.icons.search))

            WindowClass.Notify = originalNotify
            expect(notified).to.equal(0)
        end)

        it("notifies once however many custom icons are blocked", function()
            local WindowClass = helpers.requireComponent("window")
            local originalNotify = WindowClass.Notify
            local notified = 0
            WindowClass.Notify = function()
                notified += 1
            end

            variables.secureMode = true
            image.onBlock = nil

            window = AFKTY:CreateWindow({
                name = "Secure Icons",
                configuration = { autoSave = false, autoLoad = false },
            })

            -- a page full of custom icons must not become a stack of identical toasts
            image.onBlock(9876543210)
            image.onBlock(1234509876)
            image.onBlock("rbxassetid://5555555555")

            WindowClass.Notify = originalNotify
            expect(notified).to.equal(1)
        end)

        it("blanks an uncached icon rather than leaking the asset id", function()
            variables.secureMode = true

            -- the whole point: in secure mode an id the cache never served must not come back
            -- out as rbxassetid://, or it goes over the wire and is exactly what a game looks for
            local resolved = image.resolve(9876543210)
            expect(resolved).to.equal("")
        end)
    end)
end
