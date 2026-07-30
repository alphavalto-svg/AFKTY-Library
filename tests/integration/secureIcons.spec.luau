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
        local originalOnFailed
        local originalLoadFont

        beforeEach(function()
            originalSecureMode = variables.secureMode
            originalPreload = image.preload
            originalOnFailed = image.onFailed
            originalLoadFont = variables.fontManager.loadFont

            -- settle immediately with nothing failed, so the only notification that can appear
            -- is the download-failure one this spec is about
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
            image.onFailed = originalOnFailed
            variables.fontManager.loadFont = originalLoadFont
        end)

        it("wires a failure handler while secure mode is on", function()
            variables.secureMode = true
            image.onFailed = nil

            window = AFKTY:CreateWindow({
                name = "Secure Icons",
                configuration = { autoSave = false, autoLoad = false },
            })

            expect(image.onFailed).to.be.ok()
        end)

        it("leaves the handler alone outside secure mode", function()
            variables.secureMode = false
            image.onFailed = nil

            window = AFKTY:CreateWindow({
                name = "Normal Icons",
                configuration = { autoSave = false, autoLoad = false },
            })

            -- nothing is cached outside secure mode, so nothing can fail to cache
            expect(image.onFailed).never.to.be.ok()
        end)

        it("notifies once however many icons fail to cache", function()
            local WindowClass = helpers.requireComponent("window")
            local originalNotify = WindowClass.Notify
            local notified = 0
            WindowClass.Notify = function()
                notified += 1
            end

            variables.secureMode = true
            image.onFailed = nil

            window = AFKTY:CreateWindow({
                name = "Secure Icons",
                configuration = { autoSave = false, autoLoad = false },
            })

            -- a page full of icons behind a dead proxy must not become a stack of toasts
            image.onFailed(9876543210)
            image.onFailed(1234509876)
            image.onFailed(5555555555)

            WindowClass.Notify = originalNotify
            expect(notified).to.equal(1)
        end)

        it("does not notify twice when preload and a late icon both fail", function()
            local WindowClass = helpers.requireComponent("window")
            local originalNotify = WindowClass.Notify
            local notified = 0
            WindowClass.Notify = function()
                notified += 1
            end

            variables.secureMode = true
            image.onFailed = nil
            -- a cold start that could not reach github, then a hub icon that fails later
            image.preload = function(onSettled)
                if onSettled then
                    onSettled(3)
                end
            end

            window = AFKTY:CreateWindow({
                name = "Secure Icons",
                configuration = { autoSave = false, autoLoad = false },
            })
            image.onFailed(9876543210)

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
