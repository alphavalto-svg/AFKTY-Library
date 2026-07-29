# AFKTY Library — session handoff

State as of **2026-07-29** — 228/228 specs, coverage 87.41% (ratchet 86.36%). The whole gate
was run and is green: `format-check`, `lint`, `typecheck`, specs.

**`main` is at `e73a202`. The branch `secure-mode-gaps` (`f6cc8dd`) sits one commit ahead and
is not merged.** That commit carries the secure-mode fixes *and* the matching
`dist/Library.lua`, so until it lands on `main` the shipped bundle does not have them —
`HttpGet` fetches `main/dist/Library.lua`.

Open this file and say *"pick up where we left off"*.

---

## Session of 2026-07-29 (latest) — secure-mode gaps, executor test, row lighting

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
- `GUIGAG2.lua` in `HUB/` still loads Rayfield — one line to switch it to the AFKTY URL
- A GitHub Action to rebuild `dist/` on push, so it can't drift from `src/`. Now that the whole
  gate is green it can enforce `format-check` + `lint` + `typecheck` + specs too. **Note the
  reproducibility trap above** — an action that rebuilds and commits will churn the manifest on
  every run. Either make the bundler's module order stable first, or have the action rebuild and
  compare *everything but* that hunk rather than blindly committing.
- **Secure mode has never run in a real executor** — only unit-tested. It needs
  `getgenv().AFKTY_SECURE = true` before load, so Studio can never exercise it. Config saving
  is no longer on this list: it is confirmed working on the Studio simulation (see above),
  though real on-disk persistence is still executor-only.
  **`executor.test.lua` exists to close this** — it just has to be pasted into an executor and
  run. Nobody has done that yet, so the harness itself is also unverified.
- **`secure-mode-gaps` is unmerged.** It is one commit (`f6cc8dd`) ahead of `main` and carries
  the rebuilt `dist/Library.lua`, so the secure-mode fixes are not in the bundle consumers fetch
  until it lands on `main`. The full gate passes on the branch.
