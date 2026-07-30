local requireUtility = (_G :: any).__AFKTY_TEST_HELPERS.requireUtility

return function()
    local imageCache = requireUtility("imageCache")
    local filesystem = requireUtility("filesystem")
    local variables = requireUtility("variables")
    local constants = requireUtility("constants")

    describe("utility.imageCache", function()
        local originalFilesystem
        local originalGetCustomAsset
        local originalAssetResolver
        local originalJsonDecode
        local originalWait
        local originalOnCached
        local originalOnFailed
        local files

        beforeEach(function()
            files = {}
            table.clear(imageCache.rewrites)
            table.clear(imageCache.inFlight)
            table.clear(imageCache.failed)
            originalOnCached = imageCache.onCached
            imageCache.onCached = nil
            originalOnFailed = imageCache.onFailed
            imageCache.onFailed = nil

            originalFilesystem = {
                ensureFolder = filesystem.ensureFolder,
                isfile = filesystem.isfile,
                writefile = filesystem.writefile,
            }
            originalGetCustomAsset = getfenv().getcustomasset
            originalAssetResolver = {
                getAssetContentFromUrl = variables.assetResolver.getAssetContentFromUrl,
                getAssetContentFromId = variables.assetResolver.getAssetContentFromId,
            }
            originalJsonDecode = variables.httpService.JSONDecode
            originalWait = task.wait

            filesystem.ensureFolder = function(path)
                files[path] = files[path] or true
            end
            filesystem.isfile = function(path)
                return type(files[path]) == "string"
            end
            filesystem.writefile = function(path, content)
                files[path] = content
            end
            variables.assetResolver.getAssetContentFromUrl = function(_, url)
                -- real icon/avatar bodies are pngs; cacheFile checks the magic before writing
                return "\137PNG\r\n\26\nbody:" .. tostring(url)
            end
            variables.assetResolver.getAssetContentFromId = function(_, id)
                return "\137PNG\r\n\26\ndirect:" .. tostring(id)
            end
            variables.httpService.JSONDecode = function()
                return {
                    data = {
                        {
                            state = "Completed",
                            imageUrl = "https://cdn.example/avatar.png",
                        },
                    },
                }
            end
            task.wait = function() end
        end)

        afterEach(function()
            table.clear(imageCache.rewrites)
            table.clear(imageCache.inFlight)
            table.clear(imageCache.failed)
            imageCache.onCached = originalOnCached
            imageCache.onFailed = originalOnFailed
            filesystem.ensureFolder = originalFilesystem.ensureFolder
            filesystem.isfile = originalFilesystem.isfile
            filesystem.writefile = originalFilesystem.writefile
            getfenv().getcustomasset = originalGetCustomAsset
            variables.assetResolver.getAssetContentFromUrl = originalAssetResolver.getAssetContentFromUrl
            variables.assetResolver.getAssetContentFromId = originalAssetResolver.getAssetContentFromId
            variables.httpService.JSONDecode = originalJsonDecode
            task.wait = originalWait
        end)

        it("returns all failures when custom assets are unavailable", function()
            getfenv().getcustomasset = nil
            local settled

            local ok, missing = imageCache.preload(function(failed)
                settled = failed
            end)

            expect(ok).to.equal(false)
            expect(missing).to.equal(settled)
        end)

        it("uses existing cached manifest icons", function()
            getfenv().getcustomasset = function(path)
                return "asset://" .. path
            end
            filesystem.isfile = function()
                return true
            end
            local settled

            local ok, missing = imageCache.preload(function(failed)
                settled = failed
            end)

            expect(ok).to.equal(true)
            expect(missing).to.equal(0)
            expect(settled).to.equal(0)
            expect(imageCache.rewrites[constants.icons.close]).to.be.ok()
        end)

        it("downloads missing manifest icons and reports settled failures", function()
            getfenv().getcustomasset = function(path)
                return "asset://" .. path
            end
            local cachedIds = {}
            imageCache.onCached = function(id)
                cachedIds[id] = true
            end
            local settled

            local ok, missing = imageCache.preload(function(failed)
                settled = failed
            end)

            expect(ok).to.equal(false)
            expect(missing).to.be.ok()
            expect(settled).to.equal(0)
            expect(cachedIds[constants.icons.close]).to.equal(true)
            expect(imageCache.rewrites[constants.icons.close]).to.be.ok()
        end)

        it("still settles when the cached callback throws", function()
            getfenv().getcustomasset = function(path)
                return "asset://" .. path
            end
            imageCache.onCached = function()
                error("callback blew up")
            end
            local settled

            local ok, missing = imageCache.preload(function(failed)
                settled = failed
            end)

            -- a throw used to strand the pending counter, so settle never fired
            expect(ok).to.equal(false)
            expect(missing).to.be.ok()
            expect(settled).to.equal(0)
        end)

        it("returns all failures when no file API exists", function()
            getfenv().getcustomasset = function(path)
                return "asset://" .. path
            end
            filesystem.isfile = nil
            local settled

            local ok, missing = imageCache.preload(function(failed)
                settled = failed
            end)

            expect(ok).to.equal(false)
            expect(missing).to.equal(settled)
        end)

        it("returns nothing for avatars when no file API exists", function()
            filesystem.isfile = nil

            expect(imageCache.avatar(42)).to.equal("")
        end)

        it("returns cached avatars from disk", function()
            getfenv().getcustomasset = function(path)
                return "asset://" .. path
            end
            filesystem.isfile = function(path)
                return path:match("avatar_42%.png$") ~= nil
            end

            expect(imageCache.avatar(42)).to.be.ok()
            expect(imageCache.avatar("42")).to.equal("")
        end)

        it("fetches avatars in the background and calls the ready callback", function()
            getfenv().getcustomasset = function(path)
                return "asset://" .. path
            end
            local readyUri

            expect(imageCache.avatar(99, function(uri)
                readyUri = uri
            end)).to.equal("")

            expect(readyUri).to.be.ok()
        end)

        it("rejects non-png bodies instead of writing them to disk", function()
            getfenv().getcustomasset = function(path)
                return "asset://" .. path
            end
            variables.assetResolver.getAssetContentFromUrl = function()
                return "<html>error page</html>"
            end
            local settled

            local ok, missing = imageCache.preload(function(failed)
                settled = failed
            end)

            expect(ok).to.equal(false)
            expect(settled).to.equal(missing)
            expect(imageCache.rewrites[constants.icons.close]).never.to.be.ok()
        end)

        it("retries past a pending thumbnail response", function()
            getfenv().getcustomasset = function(path)
                return "asset://" .. path
            end
            local decodes = 0
            variables.httpService.JSONDecode = function()
                decodes += 1
                return {
                    data = {
                        {
                            state = if decodes == 1 then "Pending" else "Completed",
                            imageUrl = "https://cdn.example/avatar.png",
                        },
                    },
                }
            end
            local readyUri

            expect(imageCache.avatar(77, function(uri)
                readyUri = uri
            end)).to.equal("")

            expect(readyUri).to.be.ok()
            expect(decodes).to.equal(2)
        end)

        it("leaves avatars unresolved when thumbnail polling never completes", function()
            getfenv().getcustomasset = function(path)
                return "asset://" .. path
            end
            variables.httpService.JSONDecode = function()
                return {
                    data = {
                        {
                            state = "Pending",
                        },
                    },
                }
            end
            local readyUri = "not-called"

            expect(imageCache.avatar(100, function(uri)
                readyUri = uri
            end)).to.equal("")
            expect(readyUri).to.equal("not-called")
        end)

        it("serves a requested icon from disk without touching the network", function()
            getfenv().getcustomasset = function(path)
                return "asset://" .. path
            end
            filesystem.isfile = function()
                return true
            end
            local downloads = 0
            variables.assetResolver.getAssetContentFromId = function()
                downloads += 1
                return nil
            end

            local uri, pending = imageCache.request(9876543210)

            expect(uri).to.be.ok()
            expect(pending).to.equal(false)
            expect(downloads).to.equal(0)
            expect(imageCache.rewrites[9876543210]).to.equal(uri)
        end)

        it("downloads a requested icon and reports it through onCached", function()
            getfenv().getcustomasset = function(path)
                return "asset://" .. path
            end
            local cached
            imageCache.onCached = function(id)
                cached = id
            end

            local uri, pending = imageCache.request(9876543210)

            -- task.spawn resumes immediately, so the download has already run by here
            expect(uri).never.to.be.ok()
            expect(pending).to.equal(true)
            expect(cached).to.equal(9876543210)
            expect(imageCache.rewrites[9876543210]).to.be.ok()
        end)

        it("collapses concurrent requests for one id into a single download", function()
            getfenv().getcustomasset = function(path)
                return "asset://" .. path
            end
            local downloads = 0
            -- never resolves, so the id stays in flight across all three calls
            variables.assetResolver.getAssetContentFromId = function()
                downloads += 1
                return nil
            end
            variables.assetResolver.getAssetContentFromUrl = function()
                return nil
            end

            imageCache.request(9876543210)
            imageCache.request(9876543210)
            imageCache.request(9876543210)

            expect(downloads).to.equal(1)
        end)

        it("falls back to the thumbnail endpoint when assetdelivery gives a non-png", function()
            getfenv().getcustomasset = function(path)
                return "asset://" .. path
            end
            variables.assetResolver.getAssetContentFromId = function()
                return "<html>roproxy is down</html>"
            end
            local urls = {}
            variables.assetResolver.getAssetContentFromUrl = function(_, url)
                table.insert(urls, url)
                return "\137PNG\r\n\26\nbody:" .. tostring(url)
            end

            local _, pending = imageCache.request(9876543210)

            expect(pending).to.equal(true)
            expect(imageCache.rewrites[9876543210]).to.be.ok()
            -- the thumbnail lookup, then the cdn url it decoded to
            expect(#urls).to.equal(2)
            expect(string.find(urls[1], "thumbnails.roblox.com", 1, true)).to.be.ok()
        end)

        it("never writes a non-png body to disk", function()
            getfenv().getcustomasset = function(path)
                return "asset://" .. path
            end
            variables.assetResolver.getAssetContentFromId = function()
                return "<html>error page</html>"
            end
            variables.assetResolver.getAssetContentFromUrl = function()
                return "<html>error page</html>"
            end

            imageCache.request(9876543210)

            expect(files["AFKTY/Assets/9876543210.png"]).never.to.be.ok()
            expect(imageCache.rewrites[9876543210]).never.to.be.ok()
        end)

        it("reports a terminal failure once and never retries that id", function()
            getfenv().getcustomasset = function(path)
                return "asset://" .. path
            end
            local attempts = 0
            variables.assetResolver.getAssetContentFromId = function()
                attempts += 1
                return nil
            end
            variables.assetResolver.getAssetContentFromUrl = function()
                return nil
            end
            local failures = 0
            imageCache.onFailed = function()
                failures += 1
            end

            imageCache.request(9876543210)
            imageCache.request(9876543210)

            expect(attempts).to.equal(1)
            expect(failures).to.equal(1)
            local uri, pending = imageCache.request(9876543210)
            expect(uri).never.to.be.ok()
            expect(pending).to.equal(false)
        end)

        it("does not ask the caller to wait when it cannot cache at all", function()
            getfenv().getcustomasset = nil

            local uri, pending = imageCache.request(9876543210)

            -- registering a pending rebind here would leak: nothing will ever land
            expect(uri).never.to.be.ok()
            expect(pending).to.equal(false)
        end)

        it("keeps preload and request from downloading the same icon twice", function()
            getfenv().getcustomasset = function(path)
                return "asset://" .. path
            end
            local downloads = 0
            variables.assetResolver.getAssetContentFromUrl = function()
                downloads += 1
                coroutine.yield() -- park the spawned thread so the id stays in flight
                return nil
            end
            variables.assetResolver.getAssetContentFromId = function()
                downloads += 1
                return nil
            end

            imageCache.preload()
            local before = downloads
            imageCache.request(constants.icons.close)

            expect(downloads).to.equal(before)
        end)
    end)
end
