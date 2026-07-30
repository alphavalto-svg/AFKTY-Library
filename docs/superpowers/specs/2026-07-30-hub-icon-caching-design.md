# Hub icon caching in secure mode — design

**Date:** 2026-07-30
**Status:** approved, implementing

## Goal

In secure mode, an icon a hub passes in — `tab:CreateButton({ icon = 139478662436110 })` — renders
blank and stays blank. Make it render, by caching it to disk on demand the same way the library
already caches its own built-ins, with no work required from the hub.

## The gap today

`imageCache.preload` walks a manifest built once at module load from `constants.icons`:

```lua
for _, id in constants.icons do
    manifest[id] = assetBase .. tostring(id) .. ".png"
end
```

`assetBase` is this repo's own `assets/` folder on GitHub. Ten unique ids, fixed at build time.
Anything else has no `rewrites[id]`, so `image.resolve` takes the `variables.secureMode` branch and
returns `""` — permanently, because nothing will ever fetch it.

The rebinding machinery for the *built-ins* already exists and works: `image.assign` records blank
instances in `image.pending`, and `imageCache.onCached(id)` drops the real texture in when a
background download lands. Hub icons never enter that flow because nothing downloads them.

## Bug found while tracing this: pre-resolved icons can never rebind

Independent of the feature, and shipped today.

`window:Create` routes **every** property through `image.assign` (`window.luau:2015`), and
`image.assign` is what registers an instance in `image.pending`. Three call sites resolve *before*
handing the value over:

| Site | Code |
|---|---|
| `rail.luau:169` | `Image = image.resolve(window.icon or constants.icons.afkty)` |
| `rail.luau:389` | `Image = image.resolve(self.icon)` |
| `init.luau:85` | `banner.Image = image.resolve(constants.icons.banner)` |

`resolve()` returns `""` for anything uncached. `assign` then receives the string `""`, `idOf("")`
returns nil, no pending entry is created, and `onCached` has nothing to rebind. The icon is blank
for the rest of the session.

This is invisible on a warm disk: `preload` resolves from disk synchronously, so `rewrites[id]` is
already populated by the time the rail builds and `resolve` returns a real URI. On a **cold** disk
the downloads are still in flight, and the rail brand, every tab icon, and the banner go blank and
never recover. The banner is worse still — `createBanner()` runs at `init.luau:97`, *before*
`image.preload` at `init.luau:117`, so on a cold disk it is guaranteed blank.

That warm/cold asymmetry presents as "the icons work sometimes."

**Fix:** pass the raw id through and let `Create` resolve it.

```lua
-- rail.luau:169
Image = window.icon or constants.icons.afkty,
-- rail.luau:389
Image = self.icon,
```

The banner is a bare `Instance.new`, not a `window:Create`, so it needs the assign explicitly:

```lua
image.assign(banner, "Image", constants.icons.banner)
```

This fix is a prerequisite: without it, demand-driven caching still would not reach rail or tab
icons, which are the most visible ones.

## Architecture

### 1. `imageCache.request(id: number): string?`

New public entry point. Returns a URI when it can serve one synchronously, otherwise nil after
starting a background fetch.

```
request(id)
  rewrites[id] exists          -> return it
  id in failed set             -> return nil, do nothing
  AFKTY/Assets/<id>.png exists -> getcustomasset, store rewrite, return it   (no network)
  id already in flight         -> return nil                                 (dedupe)
  otherwise                    -> mark in flight, task.spawn(fetch), return nil
```

The disk fast path matters twice: it makes the second session instant, and it collapses with the
built-in manifest for free, since both use `AFKTY/Assets/<id>.png` and asset ids are unique.

The in-flight set is what keeps twenty buttons sharing one icon down to one download.

### 2. Fetch order

Two sources, tried in order, both funnelled through the existing `cacheFile` write path so the
PNG-magic guard applies to both and a bad body is never written to disk.

1. **`assetResolver:getAssetContentFromId(id)`** — `variables.assetResolver` is constructed with
   `RoProxyDownloadUrl`, so this is `https://assetdelivery.roproxy.com/v1/asset?id=<id>`. No
   authentication involved, and it is the same call `fontManager` already relies on in production
   to pull TTF faces. Returns the exact uploaded bytes at native resolution.
2. **`https://thumbnails.roblox.com/v1/assets?assetIds=<id>&size=420x420&format=Png&isCircular=false`**
   — decode to a CDN url, then download that. Verified end-to-end with alpha preserved
   (`colorType 4`). Response shape is identical to the avatar endpoint, so `decodeThumbnailUrl` is
   reused as-is.

The second exists because the first depends on a third-party proxy. If roproxy is down or rate
limits, icons should degrade to a re-rendered 420×420 copy rather than disappear. At the sizes
these render (16–24px) that copy is indistinguishable.

On success: `rewrites[id] = uri`, then `pcall(imageCache.onCached, id)`.
On failure of both: add to the failed set, drop the id's pending entry, then
`pcall(imageCache.onFailed, id)`. No retry this session.

### 3. `image.assign` triggers the request

In secure mode, when an id has no rewrite, `assign` currently only records the pending instance. It
now also calls `imageCache.request(id)`. Nothing else changes about the registration.

### 4. Drop the `settled` flag

`image.preload`'s settle callback currently does:

```lua
settled = true
table.clear(image.pending)
```

That is correct for a world where the only downloads are the fixed manifest fired at startup. It is
wrong here: a hub icon registered after preload settles would be cleared immediately, or never
recorded at all because `assign` checks `not settled`.

Lifetime becomes per-id instead of global:

- `onCached(id)` already clears `image.pending[id]` after rebinding.
- A terminal fetch failure clears `image.pending[id]` too.
- The per-id table stays weak-keyed (`__mode = "k"`), so destroyed instances are collected.

Every entry therefore has exactly one owner that removes it, and the map cannot grow without bound.
The `settled` local and both its guards are deleted.

### 5. `image.onBlock` messaging

`init.luau:148` currently tells the dev *"Custom icons are hidden in secure mode. Cache them
yourself and pass the result."* That advice becomes wrong — the library now does it for them.

A blank custom icon is no longer an expected state, it is a cache failure. Concretely:

- The `image.onBlock` assignment at `init.luau:148` is **removed**, along with the `builtInIcon`
  suppression table at `init.luau:142` and the `warnedBlocked` flag. Built-ins and hub icons now
  take the same path, so there is nothing left to distinguish between.
- `image.onBlock` itself stays in `image.luau` as an optional hook (specs use it to assert that a
  value was blocked). Left nil, `blocked()` just returns `""` as it does today.
- A new `imageCache.onFailed: ((id: number) -> ())?` hook fires from the terminal-failure path.
  `preload`'s existing `onSettled(failed)` cannot carry this: it fires once, at startup, and a hub
  icon can fail minutes later.
- `init.luau` wires `onFailed` and the existing `onSettled` to one shared, one-shot notify, so a
  cold start that fails and a late hub icon that fails produce a single message between them rather
  than one each. New wording says the download failed; it no longer tells the dev to cache icons
  themselves.

## Data flow

```
hub calls tab:CreateButton({ icon = 139478662436110 })
  -> window:Create("ImageLabel", { Image = 139478662436110 })
     -> image.assign(instance, "Image", 139478662436110)
        -> image.resolve  -> "" (secure, no rewrite)
        -> image.pending[139478662436110][instance] = { Image = true }
        -> imageCache.request(139478662436110)
           -> not on disk, not in flight -> spawn:
              roproxy assetdelivery -> body -> PNG magic ok -> writefile -> getcustomasset
              -> rewrites[id] = uri
              -> onCached(id) -> instance.Image = uri
```

## Error handling

| Case | Behaviour |
|---|---|
| No `getcustomasset` / no `isfile` | `request` returns nil immediately. Secure mode is not default-on in that environment anyway (`runtime.luau`). |
| Body is not a PNG | Not written. Falls through to the thumbnail endpoint, then to failure. |
| Both endpoints fail | Id marked failed, pending entry dropped, one on-screen notification per session. Icon stays blank. |
| Instance destroyed before the download lands | Weak-keyed map drops it; `onCached` skips anything without a `Parent`. |
| `onCached` throws | Already wrapped in `pcall` at the `imageCache` call site. |

Nothing goes to the console. Secure mode gags `log.warn`/`log.print`, and the whole point of the
threat model is that a game-side `LogService.MessageOut` hook sees nothing.

## Testing

Unit specs against the existing filesystem and network stubs:

- disk hit returns a URI without touching the network
- concurrent requests for one id produce exactly one download
- a non-PNG body is never written to disk
- the thumbnail endpoint is only hit after assetdelivery fails
- `onCached` rebinds a registered pending instance
- a failed id is not retried on a later `request`
- an icon requested *after* preload settles still caches and rebinds (the `settled` regression)
- `rail` and the banner register pending entries for their icons (the pre-resolve regression)

Coverage must stay at or above the `coverage-baseline.json` ratchet (86.36%).

Live executor run: delete `AFKTY/Assets`, run `executor.tour.lua` with secure mode on, confirm the
demo icons and tab icons appear, the folder fills with `<id>.png`, and a game-side
`LogService.MessageOut` hook plus `GetLogHistory()` still show zero library output and zero asset
ids.

## Out of scope

- No download queue or concurrency cap. The in-flight set collapses duplicates and the number of
  distinct icons in a hub is small.
- No retry beyond the two endpoints.
- No cache eviction or size limit for `AFKTY/Assets`.
- No speculative preloading of hub icons before they are asked for.
- The dead font branch in `init.luau` stays as-is; unrelated.
