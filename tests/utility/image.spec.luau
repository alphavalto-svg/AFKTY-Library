local requireUtility = (_G :: any).__AFKTY_TEST_HELPERS.requireUtility

return function()
    local image = requireUtility("image")
    local imageCache = requireUtility("imageCache")
    local variables = requireUtility("variables")

    describe("utility.image", function()
        local originalAvatar

        beforeEach(function()
            variables.secureMode = false
            image.onBlock = nil
            image.onFailed = nil
            originalAvatar = imageCache.avatar
            table.clear(image.rewrites)
            table.clear(image.pending)
        end)

        afterEach(function()
            variables.secureMode = false
            image.onBlock = nil
            image.onFailed = nil
            imageCache.avatar = originalAvatar
            table.clear(image.rewrites)
            table.clear(image.pending)
        end)

        it("normalizes empty image values", function()
            expect(image.resolve(nil)).to.equal("")
            expect(image.resolve(0)).to.equal("")
            expect(image.resolve("")).to.equal("")
        end)

        it("converts numeric ids to rbxassetid URIs outside secure mode", function()
            expect(image.resolve(123)).to.equal("rbxassetid://123")
        end)

        it("passes Roblox asset and thumbnail URIs through outside secure mode", function()
            expect(image.resolve("rbxasset://textures/icon.png")).to.equal("rbxasset://textures/icon.png")
            expect(image.resolve("rbxthumb://type=AvatarHeadShot&id=1&w=48&h=48")).to.equal(
                "rbxthumb://type=AvatarHeadShot&id=1&w=48&h=48"
            )
            expect(image.resolve("rbxassetid://456")).to.equal("rbxassetid://456")
        end)

        it("uses cached rewrites before raw ids", function()
            image.rewrites[123] = "rbxasset://cached/icon.png"

            expect(image.resolve(123)).to.equal("rbxasset://cached/icon.png")

            image.rewrites[123] = nil
        end)

        it("returns avatar thumbnails directly outside secure mode", function()
            expect(image.avatar(99)).to.equal("rbxthumb://type=AvatarHeadShot&id=99&w=48&h=48")
        end)

        it("delegates avatar thumbnails to the secure cache in secure mode", function()
            local requestedUserId
            local requestedCallback
            variables.secureMode = true
            imageCache.avatar = function(userId, onReady)
                requestedUserId = userId
                requestedCallback = onReady
                return "cached-avatar"
            end

            local callback = function() end
            expect(image.avatar(42, callback)).to.equal("cached-avatar")
            expect(requestedUserId).to.equal(42)
            expect(requestedCallback).to.equal(callback)
        end)

        it("assigns non-image properties without resolving them", function()
            local instance: any = {}

            image.assign(instance, "Text", 123)

            expect(instance.Text).to.equal(123)
        end)

        it("tracks secure-mode image assignments until the asset is cached", function()
            variables.secureMode = true
            local instance: any = {
                Parent = {},
            }

            local originalRequest = imageCache.request
            imageCache.request = function()
                return nil, true
            end
            image.assign(instance, "Image", 321)
            imageCache.request = originalRequest

            expect(instance.Image).to.equal("")
            expect(image.pending[321][instance].Image).to.equal(true)

            image.rewrites[321] = "rbxasset://cached/icon.png"
            imageCache.onCached(321)

            expect(instance.Image).to.equal("rbxasset://cached/icon.png")
            expect(image.pending[321]).never.to.be.ok()
        end)

        it("rebinds every waiting property of an instance", function()
            variables.secureMode = true
            local instance: any = {
                Parent = {},
            }

            local originalRequest = imageCache.request
            imageCache.request = function()
                return nil, true
            end
            image.assign(instance, "Image", 321)
            image.assign(instance, "HoverImage", 321)
            imageCache.request = originalRequest

            image.rewrites[321] = "rbxasset://cached/icon.png"
            imageCache.onCached(321)

            expect(instance.Image).to.equal("rbxasset://cached/icon.png")
            expect(instance.HoverImage).to.equal("rbxasset://cached/icon.png")
        end)

        it("keeps re-assigning the same icon from stacking up", function()
            variables.secureMode = true
            local instance: any = {
                Parent = {},
            }

            -- hot paths like a minimise toggle re-assign the same icon all session
            local originalRequest = imageCache.request
            imageCache.request = function()
                return nil, true
            end
            for _ = 1, 50 do
                image.assign(instance, "Image", 321)
            end
            imageCache.request = originalRequest

            local waiting = 0
            for _ in image.pending[321] do
                waiting += 1
            end
            expect(waiting).to.equal(1)
        end)

        it("still tracks and rebinds an icon requested after preload settles", function()
            variables.secureMode = true
            local instance: any = {
                Parent = {},
            }

            local originalPreload = imageCache.preload
            imageCache.preload = function(onSettled)
                if onSettled then
                    onSettled(0)
                end
                return true, 0
            end
            image.preload()
            imageCache.preload = originalPreload

            -- a hub can add a tab minutes after the window opened; settle must not stop tracking
            local originalRequest = imageCache.request
            imageCache.request = function()
                return nil, true
            end
            image.assign(instance, "Image", 654)
            imageCache.request = originalRequest
            expect(image.pending[654]).to.be.ok()

            image.rewrites[654] = "rbxasset://cached/late.png"
            imageCache.onCached(654)
            expect(instance.Image).to.equal("rbxasset://cached/late.png")
        end)

        it("asks the cache for an uncached icon in secure mode", function()
            variables.secureMode = true
            local requested
            local originalRequest = imageCache.request
            imageCache.request = function(id)
                requested = id
                return nil, true
            end

            local instance: any = { Parent = {} }
            image.assign(instance, "Image", 321)

            imageCache.request = originalRequest
            expect(requested).to.equal(321)
            expect(image.pending[321][instance].Image).to.equal(true)
        end)

        it("uses a disk hit immediately instead of blanking for a frame", function()
            variables.secureMode = true
            local originalRequest = imageCache.request
            imageCache.request = function()
                return "rbxasset://cached/on-disk.png", false
            end

            local instance: any = { Parent = {} }
            image.assign(instance, "Image", 321)

            imageCache.request = originalRequest
            expect(instance.Image).to.equal("rbxasset://cached/on-disk.png")
            expect(image.pending[321]).never.to.be.ok()
        end)

        it("does not track an icon the cache says will never arrive", function()
            variables.secureMode = true
            local originalRequest = imageCache.request
            imageCache.request = function()
                return nil, false
            end

            local instance: any = { Parent = {} }
            image.assign(instance, "Image", 321)

            imageCache.request = originalRequest
            expect(instance.Image).to.equal("")
            -- tracking it would leak: nothing is coming
            expect(image.pending[321]).never.to.be.ok()
        end)

        it("drops the pending entry and forwards when a download fails for good", function()
            variables.secureMode = true
            local instance: any = { Parent = {} }
            local originalRequest = imageCache.request
            imageCache.request = function()
                return nil, true
            end
            image.assign(instance, "Image", 321)
            imageCache.request = originalRequest

            local reported
            image.onFailed = function(id)
                reported = id
            end
            imageCache.onFailed(321)
            image.onFailed = nil

            expect(reported).to.equal(321)
            expect(image.pending[321]).never.to.be.ok()
        end)

        it("leaves non-secure assignments alone", function()
            variables.secureMode = false
            local called = false
            local originalRequest = imageCache.request
            imageCache.request = function()
                called = true
                return nil, false
            end

            local instance: any = { Parent = {} }
            image.assign(instance, "Image", 321)

            imageCache.request = originalRequest
            expect(called).to.equal(false)
            expect(instance.Image).to.equal("rbxassetid://321")
        end)

        it("blocks secure-mode thumbnails and reports the blocked value", function()
            local blocked
            variables.secureMode = true
            image.onBlock = function(value)
                blocked = value
            end

            expect(image.resolve("rbxthumb://type=AvatarHeadShot&id=1&w=48&h=48")).to.equal("")
            expect(blocked).to.equal("rbxthumb://type=AvatarHeadShot&id=1&w=48&h=48")
        end)

        it("reports unsupported values through the block hook", function()
            local blocked
            image.onBlock = function(value)
                blocked = value
            end

            local unsupported = {}
            expect(image.resolve(unsupported)).to.equal("")
            expect(blocked).to.equal(unsupported)
        end)
    end)
end
