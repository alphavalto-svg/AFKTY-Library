# Hub Icon Caching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In secure mode, cache any icon a hub passes in to disk on demand so it renders, instead of resolving blank forever.

**Architecture:** `imageCache` gains a demand-driven `request(id)` that serves from disk when it can and otherwise downloads in the background, reusing the existing PNG-magic guard, `rewrites` table and `onCached` rebinding. `image.assign` calls it whenever secure mode blanks an id. Three call sites that pre-resolve icons to `""` before `window:Create` can register them are fixed first, because without that fix nothing reaches rail, tab or banner icons.

**Tech Stack:** Luau (`--!strict`), Rojo project layout, TestEZ specs under `tests/`, lune task runner, selene + StyLua, wax bundler.

**Spec:** `docs/superpowers/specs/2026-07-30-hub-icon-caching-design.md`

## Global Constraints

- Every source file is `--!strict` and carries the existing MPL-2.0 header. Copy the header verbatim from a neighbouring file if you create one.
- Lint and format must pass: `selene src tests` and `stylua --check src tests`.
- Full suite must pass and coverage must stay at or above the `coverage-baseline.json` ratchet of **86.36%**. Baseline before this work: **228/228 passing, 87.41%**.
- Nothing may print to the console. Secure mode gags `log.warn`/`log.print`, and the threat model is a game-side `LogService.MessageOut` hook. Do not add `print`, `warn`, or `log.*` calls to any secure-mode path.
- Asset ids must never reach `ImageLabel.Image` in secure mode. An icon that cannot be cached renders `""`.
- Comments explain *why*, not *what*, matching the density of the surrounding code. Do not add narration comments.
- `image.rewrites` and `imageCache.rewrites` are the **same table** (aliased at `image.luau:16`). Writing through either is visible from both.

---

### Task 1: Fix pre-resolved icons so they can rebind

`window:Create` routes every property through `image.assign` (`window.luau:2015`), which is what registers a blank icon in `image.pending`. Three sites resolve first, so `assign` receives the string `""`, `idOf("")` returns nil, no pending entry is created, and `onCached` has nothing to rebind. Warm disk hides this; cold disk leaves the rail brand, every tab icon and the banner blank for the session.

This task is self-contained and shippable on its own.

**Files:**
- Modify: `src/components/rail.luau:169`, `src/components/rail.luau:389`
- Modify: `src/init.luau:85`
- Test: `tests/components/rail.spec.luau`

**Interfaces:**
- Consumes: `image.assign(instance, property, value)`, `image.pending`, `imageCache.onCached(id)` — all existing, unchanged.
- Produces: nothing new. Behavioural fix only.

- [ ] **Step 1: Write the failing test**

Append inside the existing `describe` block in `tests/components/rail.spec.luau`. Match the file's existing window-construction helper — read the top of the file first and use whatever it already calls to build `w`.

```lua
it("registers rail icons as pending so they rebind once cached", function()
    local image = helpers.requireUtility("image")
    local imageCache = helpers.requireUtility("imageCache")
    local variables = helpers.requireUtility("variables")

    local originalSecure = variables.secureMode
    variables.secureMode = true
    table.clear(image.rewrites)
    table.clear(image.pending)

    local w = makeWindow()
    local item = w:CreateRailItem({ icon = 9876543210, name = "Custom" })

    -- pre-resolving to "" before Create hands it to assign meant this was never recorded
    expect(image.pending[9876543210]).to.be.ok()
    expect(image.pending[9876543210][item.iconImage].Image).to.equal(true)

    image.rewrites[9876543210] = "rbxasset://cached/custom.png"
    imageCache.onCached(9876543210)
    expect(item.iconImage.Image).to.equal("rbxasset://cached/custom.png")

    variables.secureMode = originalSecure
    table.clear(image.rewrites)
    table.clear(image.pending)
    w:Unload()
end)
```

- [ ] **Step 2: Run the suite to verify it fails**

Run: `lune run scripts/run-tests.luau`
Expected: FAIL — `image.pending[9876543210]` is nil, because `rail.luau:389` already flattened the id to `""`.

- [ ] **Step 3: Pass the raw ids through**

`src/components/rail.luau:169` — the brand:

```lua
        Image = window.icon or constants.icons.afkty,
```

`src/components/rail.luau:389` — the rail item icon:

```lua
        Image = self.icon,
```

`src/init.luau:85` — delete the `banner.Image = image.resolve(...)` line. The banner is a bare `Instance.new`, not a `window:Create`, so it needs the assign explicitly. Add it immediately after `banner.Size` is set and before `banner.Parent = ui`:

```lua
    -- createBanner runs before image.preload, so on a cold disk this resolves blank; assign
    -- rather than resolve so it rebinds when the download lands instead of staying empty
    image.assign(banner, "Image", constants.icons.banner)
```

Check whether `image.resolve` is still referenced anywhere in `src/init.luau` after this. If it is not, leave the `image` require alone — `image.assign`, `image.preload` and `image.onBlock` all still use it.

- [ ] **Step 4: Run the suite to verify it passes**

Run: `lune run scripts/run-tests.luau`
Expected: PASS, 229/229, coverage at or above 86.36%.

- [ ] **Step 5: Lint, format, commit**

```bash
selene src tests
stylua src tests
git add src/components/rail.luau src/init.luau tests/components/rail.spec.luau
git commit -m "Let rail and banner icons rebind once their download lands"
```

---

### Task 2: Add `imageCache.request` and `imageCache.onFailed`

The core new machinery. Not yet wired to `image.assign` — that is Task 3, so this task can be reviewed on its own.

**Files:**
- Modify: `src/utility/imageCache.luau`
- Test: `tests/utility/imageCache.spec.luau`

**Interfaces:**
- Consumes: `assetResolver:getAssetContentFromId(id, forced)` and `assetResolver:getAssetContentFromUrl(url, cacheKey, forced)` from `variables.assetResolver`; `filesystem.isfile/writefile/ensureFolder`; `path.join`; the module-local `pngMagic` and `decodeThumbnailUrl`.
- Produces:
  - `imageCache.request(id: unknown) -> (string?, boolean)` — first value is a URI when one can be served synchronously, second is `true` when a download is in flight and the caller should register for a rebind.
  - `imageCache.onFailed: ((id: number) -> ())?` — fires once per id that exhausts both endpoints.
  - `imageCache.inFlight: { [number]: boolean }` and `imageCache.failed: { [number]: boolean }` — observable module state, public for the same reason `rewrites` is: specs reset them between cases.

- [ ] **Step 1: Write the failing tests**

Add to `tests/utility/imageCache.spec.luau`. Two changes to the existing `beforeEach`/`afterEach` first — add these lines alongside the existing `table.clear(imageCache.rewrites)` in **both** hooks:

```lua
            table.clear(imageCache.inFlight)
            table.clear(imageCache.failed)
```

and in `beforeEach` only, alongside the `originalOnCached` capture:

```lua
            originalOnFailed = imageCache.onFailed
            imageCache.onFailed = nil
```

with the matching restore in `afterEach`:

```lua
            imageCache.onFailed = originalOnFailed
```

Declare `local originalOnFailed` next to `originalOnCached` at the top of the describe block, and stub the id-based download in `beforeEach` next to the existing url stub:

```lua
            originalAssetResolver = {
                getAssetContentFromUrl = variables.assetResolver.getAssetContentFromUrl,
                getAssetContentFromId = variables.assetResolver.getAssetContentFromId,
            }
            variables.assetResolver.getAssetContentFromId = function(_, id)
                return "\137PNG\r\n\26\ndirect:" .. tostring(id)
            end
```

and restore it in `afterEach`:

```lua
            variables.assetResolver.getAssetContentFromId = originalAssetResolver.getAssetContentFromId
```

Then the new tests:

```lua
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

            expect(files[("AFKTY/Assets/9876543210.png")]).never.to.be.ok()
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
                return nil -- stays in flight for the length of preload
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
```

Note the last test relies on `preload` clearing `inFlight` only after each download finishes. With the stub returning nil synchronously, `preload`'s spawned thread completes before `request` is called, so this test as written would pass trivially. Make it real by having the url stub yield:

```lua
            variables.assetResolver.getAssetContentFromUrl = function()
                downloads += 1
                coroutine.yield() -- park the spawned thread so the id stays in flight
                return nil
            end
```

- [ ] **Step 2: Run the suite to verify the new tests fail**

Run: `lune run scripts/run-tests.luau`
Expected: FAIL — `attempt to call a nil value` on `imageCache.request`.

- [ ] **Step 3: Implement**

In `src/utility/imageCache.luau`:

Add the type export next to the existing ones:

```lua
export type OnFailedCallback = (id: number) -> ()
```

Add the asset thumbnail endpoint next to `thumbEndpoint`:

```lua
-- 420x420 is a re-render rather than the uploaded bytes, but it needs no proxy and keeps alpha
local assetThumbEndpoint =
    "https://thumbnails.roblox.com/v1/assets?assetIds=%d&size=420x420&format=Png&isCircular=false"
```

Add the two public tables and the hook next to `imageCache.rewrites`:

```lua
-- public for the same reason rewrites is: this is the module's observable state, and specs
-- reset it between cases
imageCache.inFlight = {} :: { [number]: boolean }
imageCache.failed = {} :: { [number]: boolean }
imageCache.onFailed = nil :: OnFailedCallback? -- image clears the pending entry and forwards to init
```

Split the write half out of `cacheFile` so the id path can reuse the guard. Replace the existing `cacheFile` with:

```lua
-- never write a non-png body (error page, redirect html) to disk; a poisoned cache file would
-- shadow the real asset on every later session
local function writeCached(filePath: string, body: string?): string?
    if not body or string.sub(body, 1, 8) ~= pngMagic then
        return nil
    end
    pcall(filesystem.ensureFolder, cacheRoot)
    pcall(filesystem.ensureFolder, cacheFolder)
    if not pcall(filesystem.writefile, filePath, body) then
        return nil
    end
    local ok, uri = pcall(getfenv().getcustomasset, filePath)
    return if ok and type(uri) == "string" then uri else nil
end

local function cacheFile(filePath: string, url: string): string?
    -- no custom assets or no file API means nothing can be cached at all
    if type(getfenv().getcustomasset) ~= "function" or typeof(filesystem.isfile) ~= "function" then
        return nil
    end
    if filesystem.isfile(filePath) then
        local ok, uri = pcall(getfenv().getcustomasset, filePath)
        return if ok and type(uri) == "string" then uri else nil
    end
    return writeCached(filePath, assetResolver:getAssetContentFromUrl(url, filePath, false))
end
```

Add the shared path helper above `avatarPath`, and use it in `preload` in place of the inline join so both paths cannot drift:

```lua
local function iconPath(id: number): string
    return path.join(cacheFolder, tostring(id) .. ".png")
end
```

Add the two-source fetch below `fetchAvatar`:

```lua
-- roproxy assetdelivery returns the exact uploaded bytes, and is the same call fontManager
-- already uses for font faces. The thumbnail endpoint is a re-render, but it does not depend on
-- the proxy being up, so it covers the case where roproxy is down or rate limiting.
local function fetchIcon(id: number, filePath: string): string?
    local direct = writeCached(filePath, assetResolver:getAssetContentFromId(id, false))
    if direct then
        return direct
    end

    local body = assetResolver:getAssetContentFromUrl(
        string.format(assetThumbEndpoint, id),
        "thumb:" .. tostring(id),
        false
    )
    local cdnUrl = if body then decodeThumbnailUrl(body) else nil
    if not cdnUrl then
        return nil
    end
    return writeCached(filePath, assetResolver:getAssetContentFromUrl(cdnUrl, filePath, false))
end
```

Add `request` below `preload`:

```lua
-- Cache an icon the built-in manifest does not cover. Returns a uri when one can be served right
-- now, plus whether a download is in flight: a caller that gets `true` should register for a
-- rebind through onCached, and one that gets `false` with no uri will never get this icon.
function imageCache.request(id: unknown): (string?, boolean)
    if type(id) ~= "number" then
        return nil, false
    end

    local existing = imageCache.rewrites[id]
    if existing then
        return existing, false
    end
    if imageCache.failed[id] then
        return nil, false
    end
    if imageCache.inFlight[id] then
        return nil, true
    end
    if type(getfenv().getcustomasset) ~= "function" or typeof(filesystem.isfile) ~= "function" then
        return nil, false
    end

    local filePath = iconPath(id)
    if filesystem.isfile(filePath) then
        local ok, uri = pcall(getfenv().getcustomasset, filePath)
        if ok and type(uri) == "string" then
            imageCache.rewrites[id] = uri
            return uri, false
        end
    end

    imageCache.inFlight[id] = true
    task.spawn(function()
        local uri = fetchIcon(id, filePath)
        imageCache.inFlight[id] = nil
        if uri then
            imageCache.rewrites[id] = uri
            if imageCache.onCached then
                pcall(imageCache.onCached, id)
            end
            return
        end
        imageCache.failed[id] = true
        if imageCache.onFailed then
            pcall(imageCache.onFailed, id)
        end
    end)
    return nil, true
end
```

Finally, make `preload` share the in-flight set so a built-in icon assigned during startup is not downloaded twice. Inside the `else` branch of the preload loop, before `task.spawn`:

```lua
                imageCache.inFlight[id] = true
```

and inside the spawned function, immediately after `local cached = cacheFile(filePath, url)`:

```lua
                imageCache.inFlight[id] = nil
```

- [ ] **Step 4: Run the suite to verify it passes**

Run: `lune run scripts/run-tests.luau`
Expected: PASS, all green, coverage at or above 86.36%.

- [ ] **Step 5: Lint, format, commit**

```bash
selene src tests
stylua src tests
git add src/utility/imageCache.luau tests/utility/imageCache.spec.luau
git commit -m "Cache an arbitrary icon id on demand"
```

---

### Task 3: Trigger the request from `image.assign` and drop the `settled` flag

**Files:**
- Modify: `src/utility/image.luau`
- Test: `tests/utility/image.spec.luau`

**Interfaces:**
- Consumes: `imageCache.request(id) -> (string?, boolean)` and `imageCache.onFailed` from Task 2.
- Produces: `image.onFailed: ((id: number) -> ())?` — forwarded from `imageCache.onFailed` after the pending entry is cleared. `init.luau` consumes this in Task 4.

**Why `settled` goes:** `image.preload`'s settle callback does `settled = true; table.clear(image.pending)`. That is right when the only downloads are the fixed manifest fired at startup, and wrong here — a hub icon registered after settle would be cleared immediately, and `assign`'s `not settled` guard would stop it being recorded at all. Lifetime becomes per-id: `onCached` clears its own entry, `onFailed` clears its own, and the weak-keyed inner table drops destroyed instances. Every entry has exactly one owner that removes it.

- [ ] **Step 1: Write the failing tests**

In `tests/utility/image.spec.luau`, **replace** the test named `"stops tracking pending images once preload settles"` (lines 146-172) — it asserts the behaviour this task deletes. The replacement:

```lua
        it("still tracks and rebinds an icon requested after preload settles", function()
            variables.secureMode = true
            local instance: any = {
                Parent = {},
            }

            local originalPreload = imageCache.preload
            imageCache.preload = function(onSettled)
                onSettled(0)
                return true, 0
            end
            image.preload()
            imageCache.preload = originalPreload

            -- a hub can add a tab minutes after the window opened; settle must not stop tracking
            image.assign(instance, "Image", 654)
            expect(image.pending[654]).to.be.ok()

            image.rewrites[654] = "rbxasset://cached/late.png"
            imageCache.onCached(654)
            expect(instance.Image).to.equal("rbxasset://cached/late.png")
        end)
```

Also delete the `resetSettled` helper (lines 13-20) and its three call sites in `beforeEach`/`afterEach` — it exists only to reset the flag being removed.

Add these tests:

```lua
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
```

Add `image.onFailed = nil` to both the `beforeEach` and `afterEach` hooks alongside the existing `image.onBlock = nil`.

- [ ] **Step 2: Run the suite to verify the new tests fail**

Run: `lune run scripts/run-tests.luau`
Expected: FAIL — `imageCache.request` is not called by `assign`, and `imageCache.onFailed` is nil.

- [ ] **Step 3: Implement**

In `src/utility/image.luau`:

Delete the `settled` local (line 27) and its comment.

Add the hook next to `image.onBlock`:

```lua
image.onFailed = nil :: ((id: number) -> ())?
```

Replace `image.preload` with:

```lua
function image.preload(onSettled: PreloadCallback?): (boolean, number)
    return imageCache.preload(onSettled)
end
```

Replace `image.assign` with:

```lua
function image.assign(instance: Instance, property: string, value: unknown)
    local target = instance :: any
    if not imageProperties[property] then
        target[property] = value
        return
    end

    local resolved = image.resolve(value)
    -- in secure mode an un-cached icon resolves blank. ask the cache for it: a disk hit comes
    -- back right away, and anything else lands through onCached once the download finishes
    if variables.secureMode and resolved == "" then
        local id = idOf(value)
        if id then
            local uri, pending = imageCache.request(id)
            if uri then
                resolved = uri
            elseif pending then
                local waiting = image.pending[id]
                if not waiting then
                    waiting = setmetatable({}, { __mode = "k" }) :: any
                    image.pending[id] = waiting
                end
                local properties = waiting[instance]
                if not properties then
                    properties = {}
                    waiting[instance] = properties
                end
                properties[property] = true
            end
        end
    end

    target[property] = resolved
end
```

Add the failure handler below the existing `imageCache.onCached` assignment:

```lua
-- a download that exhausted both endpoints is never coming; stop waiting on it and let init
-- decide whether to say so
imageCache.onFailed = function(id: number)
    image.pending[id] = nil
    if image.onFailed then
        image.onFailed(id)
    end
end
```

- [ ] **Step 4: Run the suite to verify it passes**

Run: `lune run scripts/run-tests.luau`
Expected: PASS. `tests/integration/secureIcons.spec.luau` may now fail on the built-in-suppression test — that is expected and Task 4 fixes it. If it does fail, note it and continue; do not patch it here.

- [ ] **Step 5: Lint, format, commit**

```bash
selene src tests
stylua src tests
git add src/utility/image.luau tests/utility/image.spec.luau
git commit -m "Fetch an uncached icon instead of leaving it blank"
```

---

### Task 4: Rewire the failure notification in `init.luau`

`init.luau:148` currently tells the dev *"Custom icons are hidden in secure mode. Cache them yourself and pass the result."* That advice is now wrong — the library does it for them. A blank custom icon is no longer an expected state; it is a cache failure.

**Files:**
- Modify: `src/init.luau:135-169`
- Test: `tests/integration/secureIcons.spec.luau`

**Interfaces:**
- Consumes: `image.onFailed` from Task 3, and the existing `image.preload(onSettled)`.
- Produces: nothing new.

- [ ] **Step 1: Rewrite the integration spec**

Four of the five tests in `tests/integration/secureIcons.spec.luau` assert the `onBlock` wiring this task removes. Replace the whole `describe` body's tests (keep the `beforeEach`/`afterEach` scaffolding, swapping `originalOnBlock`/`image.onBlock` for `originalOnFailed`/`image.onFailed`):

```lua
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
```

- [ ] **Step 2: Run the suite to verify the new tests fail**

Run: `lune run scripts/run-tests.luau`
Expected: FAIL — `image.onFailed` is nil after `CreateWindow`, because `init.luau` still wires `onBlock`.

- [ ] **Step 3: Implement**

In `src/init.luau`, delete the entire `builtInIcon` table, the `warnedBlocked` flag and the `image.onBlock = function(value) ... end` assignment (lines 135-169). Replace the whole `if variables.secureMode then` body with a single shared one-shot reporter:

```lua
    if variables.secureMode then
        -- cache icons locally so secureMode doesnt leak asset ids. non-blocking: whats already on
        -- disk applies now, the rest download in the background and rebind once ready. an icon a
        -- hub passes in takes the same path on demand, so both failure sources report here.
        local warnedFailed = false
        local function reportFailure()
            if warnedFailed then
                return
            end
            warnedFailed = true
            notifyWhenReady(function()
                if not window or window.unloaded then
                    return
                end
                window:Notify({
                    title = locale.resolve("Secure mode"),
                    content = locale.resolve("Some icons couldn't be downloaded and won't appear."),
                    duration = 8,
                })
            end)
        end

        image.preload(function(failed)
            if failed > 0 then
                reportFailure()
            end
        end)
        image.onFailed = reportFailure
    end
```

**No locale change is needed.** `locale.resolve` (`locale.luau:68-91`) returns its argument unchanged when there is no translator and no table entry, and the three old strings appear only in `src/init.luau` — they were never registered in `locale.strings`. The new string behaves the same way.

- [ ] **Step 4: Run the suite to verify it passes**

Run: `lune run scripts/run-tests.luau`
Expected: PASS, all green, coverage at or above 86.36%.

- [ ] **Step 5: Lint, format, commit**

```bash
selene src tests
stylua src tests
git add src/init.luau tests/integration/secureIcons.spec.luau
git commit -m "Report an icon that failed to download, not one that was blocked"
```

---

### Task 5: Rebuild the bundle and verify on a live client

`dist/Library.lua` is committed on purpose — it is what the executor loads over HTTP. None of the above reaches a real client until it is rebuilt.

**Files:**
- Modify: `dist/Library.lua` (generated — never hand-edit)
- Modify: `HANDOFF.md`

- [ ] **Step 1: Build with the full gate**

Run: `lune run build -- --all`
Expected: lint passes, specs pass, bundle written to `dist/Library.lua`, size over 100 KB.

The wax bundler reorders its module manifest on every build, so the diff will be noisy even where nothing changed. That is expected and not a reason to investigate.

- [ ] **Step 2: Commit the bundle**

```bash
git add dist/Library.lua
git commit -m "Rebuild the bundle with on-demand icon caching"
```

- [ ] **Step 3: Push, so the executor can fetch it**

```bash
git push origin main
```

`executor.test.lua` and `executor.tour.lua` load from
`https://raw.githubusercontent.com/alphavalto-svg/AFKTY-Library/main/dist/Library.lua`, so an
unpushed commit changes nothing on the client.

- [ ] **Step 4: Verify cold-start caching on a live client**

Requires a connected client. With the roblox-executor MCP:

1. Delete the cache so this is a genuine cold start:
   `if isfolder("AFKTY/Assets") then delfolder("AFKTY/Assets") end`
2. Run `executor.tour.lua` with secure mode on.
3. Confirm on screen: the rail brand, every tab icon and the three demo icons all render. None blank.
4. Confirm the folder filled: `#listfiles("AFKTY/Assets")` is greater than the ten built-ins.
5. Confirm no leak — run at thread identity 2, the identity a game LocalScript has:
   - `LogService:GetLogHistory()` contains no AFKTY output and no asset ids.
   - No `ImageLabel` reachable from the game has an `rbxassetid://` pointing at one of our ids.
6. Rejoin and run again. The icons must appear immediately from disk, with no downloads.

Record the actual output. Do not mark this step done on the strength of the code being correct — the whole point of the task is that it was never observed working.

- [ ] **Step 5: Update the handoff and commit**

Add a session entry to `HANDOFF.md` covering what shipped, and remove the hub-custom-icon limitation from the known-issues list if it is recorded there.

```bash
git add HANDOFF.md
git commit -m "Record the icon caching work in the handoff"
git push origin main
```

---

## Self-Review

**Spec coverage:**

| Spec section | Task |
|---|---|
| Pre-resolve bug (rail ×2, banner) | Task 1 |
| `imageCache.request` + disk fast path + dedupe | Task 2 |
| Two-endpoint fetch order, PNG guard | Task 2 |
| `imageCache.onFailed` | Task 2 (hook), Task 3 (routing), Task 4 (consumer) |
| `image.assign` triggers the request | Task 3 |
| Drop the `settled` flag | Task 3 |
| `image.onBlock` wiring removed, new wording | Task 4 |
| Test list from the spec | Tasks 1-4, all eight cases covered |
| Live executor verification | Task 5 |

**Gap found and filled:** the spec did not mention `tests/integration/secureIcons.spec.luau`, which is built entirely around `image.onBlock` and loses four of five tests when that wiring goes. Task 4 rewrites it.

**Deviation from the spec, deliberate:** the spec describes `request(id)` returning `string?`. It returns `(string?, boolean)`. Without the second value `image.assign` cannot tell "a download is coming, register for the rebind" from "this will never arrive" — and registering in the latter case leaks a pending entry that nothing ever clears, in exactly the configuration the spec's own error-handling table calls out (`AFKTY_SECURE = true` with no `getcustomasset`).

**Type consistency:** `request`, `onFailed`, `inFlight`, `failed`, `iconPath`, `writeCached`, `fetchIcon` are spelled identically across Tasks 2, 3 and 4. `image.onFailed` (the forwarded hook) is distinct from `imageCache.onFailed` (the raw one) and each task says which it means.
