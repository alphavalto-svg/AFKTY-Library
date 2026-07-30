# AFKTY Library — session handoff

State as of **2026-07-30** — 265/265 specs, coverage 87.62% (ratchet 86.36%). The whole gate
was run and is green: `format-check`, `lint`, `typecheck`, specs.

**`hub-icon-caching` is pushed but NOT merged.** It is 10 commits ahead of `main` and carries the
rebuilt `dist/Library.lua`, so hub icons do not cache on `main` yet. It was verified live against
its own branch raw URL rather than `main`'s, deliberately, so nothing reached `main` unproven.

⚠️ **`dist/Library.lua` is one commit stale.** It was last built at `a2fe67d`; the theme commit
`4ec0c4a` touched `example.client.luau`, specs and docs only, so the bundle's behaviour is
unchanged — but rebuild before merging so the artifact matches `src/`.

Nothing else is unpushed.

Open this file and say *"pick up where we left off"*.

### What is NOT done

- **Not merged to `main`.** Nothing above reaches consumers until it lands.
- **Tasks 2–4 of the icon-caching plan were never independently reviewed** — the reviewer
  dispatches were interrupted. The ledger at `.superpowers/sdd/2026-07-30-hub-icon-caching/`
  records exactly what needs scrutiny. A whole-branch review is the only gate they have had.
- **No real rejoin test.** Warm disk was tested in-session with a fresh library instance over a
  populated cache; that proves reuse and no re-download, not that the files survive a restart.
- **Nobody has visually clicked through the UI.** Every check has been a probe reading properties
  back. `studio.tour.client.luau` has still never been run.

---

## Session of 2026-07-30 (latest) — hub icons cache themselves

Secure mode used to serve exactly ten icons: the built-ins, from a manifest fixed at module load
by iterating `constants.icons`. Anything a hub passed in had no entry in `imageCache.rewrites`, so
`image.resolve` returned `""` and that icon was blank for the session, permanently. The library's
own advice was *"cache them yourself and pass the result."* It now does it for you.

**`imageCache.request(id) -> (string?, boolean)`** is the new entry point. A disk hit on
`AFKTY/Assets/<id>.png` returns synchronously with no network; anything else spawns one background
download and returns `(nil, true)`, meaning *register for the rebind*. The second return value is
load bearing — without it `image.assign` cannot tell "a download is coming" from "this will never
arrive," and registering in the latter case leaks a pending entry nothing ever clears.

Two endpoints, in order: `assetResolver:getAssetContentFromId` (which is
`assetdelivery.roproxy.com`, the same call `fontManager` already uses for font faces), then
`thumbnails.roblox.com/v1/assets` as a fallback for when that third-party proxy is down. Both
bodies go through the same PNG-magic guard, so a proxy error page can never poison the cache.

**A separate bug, found while tracing this and fixed first.** `window:Create` routes every
property through `image.assign`, which is what registers a blank icon for later rebinding. But
`rail.luau:169`, `rail.luau:389` and `init.luau:85` called `image.resolve` *themselves* first,
flattening the id to `""` — `idOf("")` is nil, so nothing registered and nothing could rebind. A
warm disk hid it completely (preload resolves from disk synchronously before the rail builds); a
cold disk left the rail brand, every tab icon and the banner blank for the whole session. That
warm/cold asymmetry is what "the icons work sometimes" was.

The `settled` flag in `image.luau` is gone. It cleared `image.pending` wholesale when preload
finished, which is right when the only downloads are a fixed startup manifest and wrong once a hub
can add a tab minutes later. Entry lifetime is now per-id: `onCached` clears its own, `onFailed`
clears its own, and the weak-keyed inner table drops destroyed instances.

**Verified live** on a real client, secure mode on, against the branch bundle:

| Check | Result |
|---|---|
| Cold start, `AFKTY/Assets` deleted first | custom id `93364949241311` rendered as `rbxasset://0c6ee.../93364949241311.png`, 12 files on disk, **0** blank ImageLabels |
| Console at thread identity 2 (game-script identity) | readable, 17 lines, **0** AFKTY lines and **0** containing any of our 11 asset ids |
| CoreGui at identity 2 | not readable |
| Asset ids reachable in `PlayerGui` | **0** |
| Warm disk, no wait at all | served synchronously, 18 ms to build, **0** blanks |

Not verified: an actual client restart. Warm disk was tested in-session with a fresh library
instance over a populated cache, which proves reuse and no re-download but not that the files
survive a restart.

Design and plan: `docs/superpowers/specs/2026-07-30-hub-icon-caching-design.md`,
`docs/superpowers/plans/2026-07-30-hub-icon-caching.md`.

### Full adversarial audit, and the six things it found

Ran the whole public surface against a live client with `LogService.MessageOut` hooked at thread
identity 2 — a game LocalScript's identity — installed **before** the library loaded. ~100 API
calls, callbacks that `error()`, malformed props, duplicate flags, a throwing translator, path
traversal in a config name, six window lifecycles, three secure-mode configurations. It found six
real problems, all now fixed:

1. **`Statistic` disagreed with itself.** The constructor took a string; `Set` asserted on one. A
   hub seeding with `"0"` only found out on first update, and an assert raised outside a guarded
   callback lands on the console. Both ends coerce now, junk is ignored rather than thrown.
2. **The window name was written into the instance tree.** `window.luau` named the main Frame
   `self.name`, so the ScreenGui's random GUID was undone by the hub's product name sitting
   directly beneath it in plaintext. It is a GUID now too.
3. **`gethui()` was trusted to return somewhere hidden.** On the test client it returns
   `CoreGui.RobloxGui` — an ordinary child. Worse, treating it as hidden *also* skipped the
   protect call, so both mitigations were off at once. `runtime.luau` now checks what it got back.
4. **Re-running a hub script orphaned the previous window.** Three had accumulated in CoreGui from
   earlier runs. Retired via a per-load token in `getgenv`, so a second window opened deliberately
   in the same run still survives.
5. **A failed icon stayed blank all session.** The first endpoint is a third-party proxy, so a
   blip there is not the asset's fault. Retries after a 20 s cooldown, capped at 3 attempts.
6. **Elements had no `Destroy`.** A hub could drop a whole tab but not one control. `Tab:RemoveElement`
   plus a `Destroy` on every registered element.

Re-verified live after the fixes, cold cache, `AFKTY_SECURE` unset so the capability gate had to
turn itself on: **0 console lines**, 0 remote asset ids, 12 icons cached, 12 local `rbxasset://`
refs, and the only 2 blank images were the two deliberately dead ids (`1` and `-7`). Prior-run
window retired, same-run pair both alive, unload clean. 258/258 specs at 87.58%.

**Not fixed, because it is not ours:** the executor's own watermark
(`PlayerGui.Watermark.TextLabel/SessionID/AccountID`) sets `FontFace = rbxassetid://16658237174`
in **PlayerGui, where the game can read it**, and it is an asset the game does not use. By the
threat model this library is built against, that is an exposure — and nothing in this repo can
reach it.

### Parity check against upstream Rayfield Gen 2

Compared against Sirius's own Gen 2 docs (`docs.sirius.menu/llms.txt` indexes the pages), not
from memory. **We match on everything except themes:**

| Upstream | Ours |
|---|---|
| 8 element types (Button, ColorPicker, Dropdown, Input, Keybind, Slider, Stat, Toggle) | 8/8 |
| 21 Window methods | 21/21 |
| CreateWindow props, incl. `fallbackFont`, `customFolder`, `translations`, `translator` | all |
| Element props `name`/`description`/`icon`/`flag`/`forgetState`; handles `.value`, `Set(v, skip)`, `MoveTo`/`Top`/`Bottom`/`Up`/`Down` | all |
| Tab `Select`/`Deselect`/`Remove`; Section; Group `direction` | all |
| Notify + Toast props incl. `subtitleAbove`, `avatar`, `minWidth`, `position` | all |
| Saving incl. `window.Flags` (`window.luau:254`) | all |
| Keybind `hold` / `holdThreshold` / `onChanged` | all |
| **6 themes**: default, cobalt, ember, amethyst, frost, rose | **1**, by choice |

Note the Move* methods come from the `moveable(Class)` mixin (`utility/moveable.luau`), applied
at the bottom of each element module — grepping the component files for `MoveTo` finds only
Dropdown and looks like a gap. It isn't.

**We are ahead of upstream on secure mode.** Their docs state plainly that in secure mode
"user-provided asset IDs render blank". Ours caches them on demand instead.

Beyond upstream: `CreateSwitch`, `CreateRailItem`, `CreateRailProfile`, search, resize,
`GetPath`, `SaveSettings`/`LoadSettings`, and element `Destroy()`.

### One theme, deliberately

`default` is the only palette and the library is built to need only that. Three places still
assumed otherwise and were corrected: `example.client.luau` asked for `"cobalt"` (silently
rendered as default, and secure mode gags the warning that would have said so); a workflow spec
asked for `"frost"`, so it read as a theme swap while exercising the fallback; the tutorial called
the README stale about a list the README no longer carries.

`tests/components/theming.spec.luau` pins what keeps this drop-in: an unknown name yields a
*complete* default rather than a half-styled window, lookup is case-insensitive, a partial table
inherits every key it omits, a named theme is a full switch that resets what a custom table set,
and a wrong-typed argument still builds.

**Adding a palette later needs no code change.** Drop `src/themes/<name>.luau` returning a partial
override table; the lookup at `window.luau:157` is a directory search and Rojo maps `src/` whole.

## Session of 2026-07-29 (latest) — the icon set moved onto owned uploads

**Every asset the library ships is now an AlphaValto upload.** Nine of the ten glyphs were still
upstream uploads inherited in `d5737be`, on an account this project cannot control — deleting or
moderating any one would have blanked that icon in every hub with no recourse. They were
reuploaded and swapped; the emblem was already ours.

The swap is `constants.icons` **plus** a rename of `assets/`, and both halves are load bearing:
`imageCache` builds its secure-mode download manifest by iterating the table, and the filename in
`assets/` is the cache key it writes to disk. A rename that drifted from the table would cache
under a name nothing ever looks up. The PNGs themselves are untouched — git recorded all nine as
pure renames.

Full detail, and the procedure for swapping an icon again, is in **`assets/README.md`**.

### Verify a new asset id before wiring it in

Learned here, worth repeating: a **pending or moderated** upload renders *blank rather than
erroring*, so it looks exactly like a code bug. Check three things —

- it resolves at all (`economy.roblox.com/v2/assets/<id>/details`)
- `AssetTypeId` is **1** (Image). A Decal id does not render in `ImageLabel.Image`
- thumbnail `state` is `Completed` (`thumbnails.roblox.com/v1/assets?assetIds=<id>`)

Do **not** try to judge an icon by its rendered thumbnail. The set is white-on-transparent and
composites to blank white on the thumbnail background — a known-good icon looks identical to a
broken one. A transient placeholder at one size also cleared at another, so a single lookup is not
evidence either way.

### Demo icons are consumer-side, and three stay upstream

The demos, `docs/TUTORIAL.md` and `rail.spec.luau` passed four ids that had just been replaced;
those 22 occurrences were repointed. Nothing in `dist/` changes — they are not the shipped set.

Three remain (`93364949241311` leaf, `84750991656135` sword, `85925158736685` chart, all uploaded
by `shlexr`). **Left deliberately** — see `assets/README.md`. They resolve and render; if they
ever vanish, three demo tabs lose an icon and the library is unaffected.

---

## Session of 2026-07-29 (earlier) — secure-mode gaps, executor test, row lighting

### `secure-mode-gaps` branch — two gaps against upstream Rayfield

1. **GUI parenting had one fallback where upstream has three.** `runtime.luau` tried `gethui()`
   and dropped straight to raw `CoreGui`, so on an executor without `gethui` the ScreenGui sat
   somewhere `CoreGui:GetChildren()` enumerates — the most detectable thing a UI library can do.
   Added `runtime.resolveProtect` (`syn.protect_gui`, then a bare `protectgui`) and a
   `RobloxGui` fallback beneath it.

   Protection applies to the **ScreenGui itself**, not a container, so all three ScreenGui sites
   (window, popup, banner) now go through `runtime.parentGui`, which protects *then* parents.
   `guiContainerHidden` records whether `gethui` already put us out of reach, because protecting
   twice is a no-op at best and throws on some executors.

2. **`image.onBlock` was declared and called but never assigned.** An icon secure mode couldn't
   serve came back as `""` with nothing said about it — the only symptom was missing artwork.
   It now raises **one** notification however many icons are affected.

   Built-in icons are deliberately exempt: the library's own chrome resolves blank too until its
   download lands, so reporting those would fire on every cold start and tell the dev to cache
   icons that were about to appear on their own.

   **Superseded on 2026-07-30.** `init.luau` no longer wires `onBlock` at all, and the built-in
   exemption is gone with it — hub icons and built-ins now take the same on-demand path, so a
   blank icon means a download failed rather than an id the cache was never going to serve. The
   one-shot notification is now fed by `image.onFailed` and preload's `onSettled` together.
   `image.onBlock` itself remains in `image.luau` as an optional hook; specs use it.

New specs: `tests/utility/guiProtection.spec.luau`, `tests/integration/secureIcons.spec.luau`
(+14 specs, 214 → 228).

### `executor.test.lua` — the two things Studio structurally cannot reach

Secure mode (needs `getgenv`) and on-disk persistence surviving a rejoin (needs `writefile`).
Paste into an executor and run; flip `SECURE` at the top of the file **before** load, since
`runtime.luau` reads `getgenv().AFKTY_SECURE` once at module load.

The checks observe what secure mode actually *does* rather than echoing the flag the script just
set: whether the executor has the globals caching needs, whether `AFKTY/Assets` filled with
`.png` files, and whether a deliberately bogus theme name produces the library warning or is
gagged. It also draws a rail profile, because avatars cache through a different path
(`avatar_<userId>.png`) that never runs without one on screen.

### Element rows light only under the cursor

Every hoverable row carried a fully opaque stroke at rest, so a page read as a grid of outlined
boxes with hover barely distinguishable. Added **`ElementStrokeRestTransparency`** rather than
repurposing `ElementStrokeTransparency` — that key is shared with `StyleElementPanel`, and
flipping it would also have stripped the edge off dropdown panels, popup cards and stat tiles,
which have no hover state and need a constant edge to read as surfaces at all.

`_revealCommon` serves both rows and stat tiles, so it resolves per element through a `hoverLit`
flag that `_wireElementHover` sets. Set `ElementStrokeRestTransparency = 0` in a theme to get the
old always-on edges back.

---

## Session of 2026-07-29 (later) — API tour, types, CI gate

### The full CI gate passes for the first time

`format-check`, `lint`, `typecheck` and the specs are all green together. `typecheck` used to
fail on one pre-existing error and nobody had noticed, because the gate is never run whole.
**Run `luau-lsp analyze` before claiming a change is clean** — the specs passing is not the
same as the gate passing.

### `studio.tour.client.luau` — exhaustive API demo

A second Studio demo that touches every public function once, each control labelled with the
call it makes and printing a `[TOUR]` line naming the method that ran. Three rail categories
(Elements / Layout / Window), twelve tabs. Destructive calls are quarantined on a Teardown
tab, `Unload` behind a confirm popup.

Wired into the place as `StarterPlayerScripts.Tour` with **`Disabled = true`**, so it does not
fight `Client`. To run it: tick `Disabled` on `Client`, untick it on `Tour`. Rojo accepts
`$path` and `$properties` on the same node — verified, no `.meta.json` needed.

### `types.luau` had drifted behind the source

It was missing the entire rail API — the exact API `docs/TUTORIAL.md` teaches — so a typed
consumer got analysis errors on the documented path. Added `RailItemProps`,
`RailProfileProps`, `RailItem` (`Select` / `SetActive` / `SetUserId` / `Destroy`),
`TabProps.category`, `Tab:Select/Deselect/Remove`, `Dropdown:Refresh/Add/Remove`, and
`Window:CreateRailItem/CreateRailProfile/GetPath/SaveSettings/LoadSettings/Get/Set`.
Re-exported the new types from `init.luau`.

`RailItemProps.icon` is typed **required**, not optional, because `rail.new` asserts on it.

### `rail.luau` typecheck fix

`local rail = {}` was left to inference. `_lastCategory` is only ever assigned inside the
search and settings callbacks, and Luau seals the literal before it sees them, so reading it
back reported the key as missing. Annotated `{ [string]: any }`.

---

## Session of 2026-07-29 (earlier) — what landed

All four changes below were checked by hand in Studio and signed off ("yes now its good").
Design doc for the resizing work: `docs/superpowers/specs/2026-07-29-window-resizing-design.md`.

### 1. Window resizing

- `src/components/resize.luau` — a 16×16 grip in main's bottom-right corner. On by default;
  `CreateWindow({ resize = false })` opts out. Sizes by cursor *delta*, not absolute position,
  so grabbing it never snaps the corner to the pointer.
- `Window:_applySize(width, height)` — the one funnel every size change goes through. Writes
  `self.size`, so `Hide`, `Show`, `_quickRestore` and `ToggleMinimise` all inherit the new size
  without knowing resizing exists. Pins the top-left by shifting the centre half the delta.
- `Window.clampSize` / `Window.clampCentreOnScreen` — **pure**, take the viewport and screen as
  arguments rather than reading them, so the bounds are testable without a camera. Min 300×320,
  max viewport − 60.
- Size persists via `windowWidth` / `windowHeight` in `persistenceSettings`, saved on release
  (never per frame) and re-clamped on load.
- `tests/components/resize.spec.luau`, plus three cases in `persistenceSettings.spec.luau`.

### 2. Drag bar removed

`src/components/drag.luau` is **deleted**, along with all 10 call sites. The window moves by the
topbar (`_bindTopbarDrag`), which rejects presses over the tabs and action icons. `zIndex.drag`
is gone from `constants`; the grip uses the new `zIndex.resizeGrip = 200`.

### 3. Glow softened

It was tiring to look at. Three knobs, all easy to nudge further:

| Knob | Was | Now | Drives |
|---|---|---|---|
| `GLOW_IDLE` (`window.luau`) | 0.72 | **0.88** | the 48px halo around the window |
| `EDGE_IDLE` (`window.luau`) | 0.5 | **0.68** | the window's lit outer stroke |
| `AccentGlow` (`themes/default`) | 0.15 | **0.45** | toggle indicators, rail selection, slider fills |

### 4. Minimise is fixed, and keeps the emblem

- `minimisedSize = UDim2.fromOffset(300, 66)` — the collapsed bar no longer tracks the resized
  width. `_applySize` leaves the bar alone while minimised; only what it *restores to* changes.
- Making the bar narrow exposed a latent bug: `insetForRail` shifts the title right by the full
  `RAIL_WIDTH` permanently, so at 300px the title landed under the action icons.
  `Rail.setShown` now slides `topContainer` between two homes — `_titleBaseX + RAIL_WIDTH`
  expanded, `COLLAPSED_TITLE_X` (52) collapsed. Idempotent, so repeated show/hide can't walk it.
- `Rail.setShown(window, shown, info, keepBrand)` — minimise passes `keepBrand = true` so the
  emblem stays and the bar still reads as the product. `Hide` does not, because the collapsed
  pill draws its own face.

### 5. Docs

`docs/TUTORIAL.md` — a full walkthrough for writing a hub against the library. Every signature
verified against the demos or the source.

**Two claims in the old version of this file were wrong — corrected below.**

### `insetForRail` does NOT need to re-run on resize

The previous handoff listed this as required work. It isn't, and doing it would *introduce* a
bug: everything `insetForRail` touches is scale-sized or left-anchored with a pure pixel
offset, so the inset stays correct at any width. Re-running it would subtract `RAIL_WIDTH`
again each time and compound.

| Element | Original | After inset |
|---|---|---|
| `tabList` | `UDim2.new(1, 0, 0, 38)` | `(1, -RAIL_WIDTH, 0, 38)` |
| `elements` | `UDim2.new(1, 0, 1, -106)` | `(1, -RAIL_WIDTH, 1, -106)` |
| `searchPill` | `UDim2.new(1, -35, 0, 35)` | `(1, -35-RAIL_WIDTH, 0, 35)` |
| `topContainer` | `Position (0, 25, 0.5, 0)` | `(0, 25+RAIL_WIDTH, 0.5, 0)` |

### `expect(...).never` DOES exist

The traps table below used to say it doesn't. `persistenceSettings.spec.luau` has been using
`.never.to.be.ok()` since before this session. (`.throw()` is still absent — use `pcall`.)

### Config saving DOES work in Studio

`studio.client.luau` used to claim `Save()` returns false in Studio, and had a button labelled
"expect false in Studio". Both were wrong. `utility/filesystem.luau:57` simulates the disk
with instances under `ReplicatedStorage.Filesystem` whenever `RunService:IsStudio()` — files
are `StringValue`s, folders are `Folder`s. `Save()` returns **true** and you can open that
folder to read the JSON. The simulation dies with the session, so only a real executor
persists across joins.

Verified by running `Save` / `Save(named)` / `Load` / `SaveSettings` / `ListConfigs` /
`DeleteConfig` under the harness with only `JSONEncode` stubbed (see the trap below) — the
filesystem path itself is genuine there, because the harness reports `IsStudio() == true`.

---

## Build

Always through the script — it is the only path that publishes `dist/Library.lua`, which is
what `HttpGet` fetches. `make` is not installed on this machine.

```sh
lune run build                # bundle -> dist/Library.lua
lune run build -- --place     # also build the Studio place
lune run build -- --all       # lint + specs gate, then bundle + place
```

`dist/Library.lua` is committed on purpose. **A rebuild is not live until pushed.**

Testing is done in Roblox Studio via `AFKTY Library.rbxlx` (rebuilt by `--place`).
`studio.client.luau` is the demo harness — it is a *consumer* of the library and must hold
no logic the library should own.

---

## Navigation model — settled, don't redesign

Left rail = **main category**. Top tab strip = **that category's subcategories**.

```lua
local farming = Window:CreateRailItem({ icon = 123, name = "Farming" })
local combat  = Window:CreateRailItem({ icon = 456, name = "Combat" })

Window:CreateTab({ name = "Seeds",  category = farming })
Window:CreateTab({ name = "Aimbot", category = combat })
```

- A tab with no `category` stays visible under every category, so `CreateTab` is unchanged
  for hubs that never use a rail
- The library selects the first category itself; `item:Select()` moves the selection and
  clears its siblings
- The emblem is a **brand mark**, not a button, and can never take the selection
- Search and settings are adopted from the topbar into the rail's bottom stack above the
  avatar; the topbar keeps only minimise and close
- Selecting search or settings clears the category highlight and remembers which category
  to return to

---

## Traps — each of these cost real time; read before touching anything

| Trap | Detail |
|---|---|
| `LiveAnimation = true` in the default theme | Hangs the test harness during window construction — every spec builds a window and the drift loop never yields. Must stay `false`. |
| Piping a build through `head` | SIGPIPE kills it mid-run and it looks like it passed. Verify artifact **contents**, not timestamps. |
| Long boolean wrapped by stylua | A multi-line `if` whose condition starts on the next line breaks the coverage instrumenter (`Expected 'then'`). Put the condition in a local. |
| `Font.fromEnum` in a theme | The lune harness shims `Font`. Use `variables.brandFont(weight)`; the family comes from `constants.fontAsset`. |
| `expect(...).throw()` | Not implemented in this harness. Use `pcall` + `equal`. `.never` **is** implemented. |
| Four separate show/hide paths | `Hide`, `Show` (first-run reveal), `_quickRestore`, `ToggleMinimise`. Wiring only some caused two distinct bugs. Touch all four. |
| Coverage ratchet | `coverage-baseline.json` enforces no regression. Refresh it only when the line total legitimately shrank; if a new line is genuinely uncovered, write a test. |
| Hardcoding the Studio exe path | `Versions\version-*` changes on every Roblox update and the old folder is deleted. Glob for the folder that actually contains `RobloxStudioBeta.exe`. |
| Studio holding a stale place | Rojo rebuilding `AFKTY Library.rbxlx` does not reload an open Studio. Studio ignores a programmatic close, so restarting means `Stop-Process -Force`, deleting `AFKTY Library.rbxlx.lock`, then relaunching. |
| PowerShell here-strings in the Bash tool | `@'...'@` is not bash. A commit message containing `0.72 -> 0.88` was read as a redirect and created empty files named `0.88,`. Use a `<<'MSG'` heredoc. |
| **The harness has no `JSONEncode`** | `scripts/run-tests.luau:1015` errors on `HttpService:JSONEncode`/`JSONDecode` by design. So `Window:Save()` returns **false under lune** for a reason that has nothing to do with the code under test. Specs that need it stub it themselves. A spec written to prove saving works will fail and look like a real bug. |
| `luau-lsp` cannot see the library from a consumer script | `require(ReplicatedStorage.AFKTY)` resolves as `any` in the root `.client.luau` demos, so `analyze` happily accepts `Window:MethodThatDoesNotExist()`. A clean analyze on those files proves basic Luau validity and nothing about API correctness. Exercise the API under the lune harness instead. |
| Editing `src/` without rebuilding `dist/` | `dist/Library.lua` is committed and is what `HttpGet` fetches. Any `src/` change — including type-only ones — leaves it stale until `lune run build`. |
| **The bundle is not reproducible** | Rebuilding from unchanged `src/` still produces a diff: the wax module manifest near the end of `dist/Library.lua` assigns numeric ids in a non-stable order, so ~13 lines churn every build. A `git diff` on `dist/` is therefore **not** evidence that `src/` changed. Check the hunk — if it is the one manifest hunk and the line count matches, nothing real moved. |

---

## Licensing — do not "clean this up"

Upstream is **MPL-2.0**, so this fork is legitimate. The ~57 per-file
`Copyright (c) 2026 Corridon Capital` + MPL headers **must not be removed** — MPL §3.4
forbids it, and they are what keeps this a licensed fork rather than an infringing copy.

They never say "Rayfield", and minification strips comments, so the shipped
`dist/Library.lua` contains **zero** upstream identifiers. Everything else has been scrubbed.

---

## Known open items

- **`studio.tour.client.luau` has never been run.** Every call it makes was executed under the
  lune harness with assertions, so the API usage is sound, but nobody has clicked through it in
  Studio. Layout and interaction are unverified.
- The emblem on the minimise bar sits at y 12–40 in a 66px bar, ~7px above true centre. Never
  eyeballed closely. `EDGE_PADDING` in `rail.luau` is the knob; the title gap is
  `COLLAPSED_TITLE_X`.
- Only `default` exists in `src/themes/`. The README used to advertise five more
  (`amethyst`, `cobalt`, `ember`, `frost`, `rose`) — corrected 2026-07-29. Note
  `example.client.luau` still passes `theme = "cobalt"`, which warns and falls back.
- Rail is ~12% of a 465px window vs ~6% in the reference design; narrowing to 44px would
  match
- ~~`GUIGAG2.lua` in `HUB/` still loads Rayfield~~ — **wrong, checked 2026-07-29.** It loads no
  library at all: it is the hand-built v1 hub that draws its own UI from scratch (the one the
  theme comments credit for the tighter corner radii). Nothing to switch. `AFKTY-Quick.lua` is
  the script that consumes this library, and it already points at the AFKTY URL.
- A GitHub Action to rebuild `dist/` on push, so it can't drift from `src/`. Now that the whole
  gate is green it can enforce `format-check` + `lint` + `typecheck` + specs too. **Note the
  reproducibility trap above** — an action that rebuilds and commits will churn the manifest on
  every run. Either make the bundler's module order stable first, or have the action rebuild and
  compare *everything but* that hunk rather than blindly committing.
- **`hub-icon-caching` is unmerged.** Six commits ahead of `main`, carrying the rebuilt
  `dist/Library.lua`, so hub icon caching is not in the bundle consumers fetch until it lands on
  `main`. The full gate passes on the branch and it was verified live against the branch URL.
  Tasks 2, 3 and 4 of that plan were never independently reviewed — the review dispatches were
  interrupted — so a whole-branch review is the only gate they have had. Worth doing before merge.
- **Nobody has clicked through the UI.** `studio.tour.client.luau` still has not been run, and the
  `Show log` popup in `executor.test.lua` has never been opened. Everything verified so far was
  read back through probes, not looked at.
- Dead font branch in `init.luau` — cosmetic; secure mode renders the BuilderSans fallback because
  `constants.fontAsset` is an `rbxasset://` path rather than a numeric id `fontManager` can
  resolve. Both faces are built in, so nothing leaks either way.
