# AFKTY Library — session handoff

State as of **2026-07-29** — 211/211 specs, coverage 86.89%, built but **not yet committed**.

Open this file and say *"pick up where we left off"*.

---

## Just landed: window resizing

Done. Design doc: `docs/superpowers/specs/2026-07-29-window-resizing-design.md`.

- `src/components/resize.luau` — a 16×16 grip in main's bottom-right, built alongside `Drag`.
  On by default; `CreateWindow({ resize = false })` opts out.
- `Window:_applySize(width, height)` in `window.luau` — the one funnel every size change goes
  through. Writes `self.size`, so all four show/hide paths inherit the new size for free.
- `Window.clampSize` / `Window.clampCentreOnScreen` — pure, take the viewport and screen as
  arguments so the bounds are testable without a camera.
- Size persists via `windowWidth` / `windowHeight` in `persistenceSettings`, saved on release
  (never per frame) and re-clamped on load.
- `tests/components/resize.spec.luau`, plus three cases in `persistenceSettings.spec.luau`.

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

## Traps that cost time today

| Trap | Detail |
|---|---|
| `LiveAnimation = true` in the default theme | Hangs the test harness during window construction — every spec builds a window and the drift loop never yields. Must stay `false`. |
| Piping a build through `head` | SIGPIPE kills it mid-run and it looks like it passed. Verify artifact **contents**, not timestamps. |
| Long boolean wrapped by stylua | A multi-line `if` whose condition starts on the next line breaks the coverage instrumenter (`Expected 'then'`). Put the condition in a local. |
| `Font.fromEnum` in a theme | The lune harness shims `Font`. Use `variables.brandFont(weight)`; the family comes from `constants.fontAsset`. |
| `expect(...).throw()` | Not implemented in this harness. Use `pcall` + `equal`. `.never` **is** implemented. |
| Four separate show/hide paths | `Hide`, `Show` (first-run reveal), `_quickRestore`, `ToggleMinimise`. Wiring only some caused two distinct bugs. Touch all four. |
| Coverage ratchet | `coverage-baseline.json` enforces no regression. Refresh it only when the line total legitimately shrank; if a new line is genuinely uncovered, write a test. |

---

## Licensing — do not "clean this up"

Upstream is **MPL-2.0**, so this fork is legitimate. The ~57 per-file
`Copyright (c) 2026 Corridon Capital` + MPL headers **must not be removed** — MPL §3.4
forbids it, and they are what keeps this a licensed fork rather than an infringing copy.

They never say "Rayfield", and minification strips comments, so the shipped
`dist/Library.lua` contains **zero** upstream identifiers. Everything else has been scrubbed.

---

## Known open items

- Resizing has passed its specs but has **not been driven by hand in Studio yet**
- Rail is ~12% of a 465px window vs ~6% in the reference design; narrowing to 44px would
  match
- `GUIGAG2.lua` in `HUB/` still loads Rayfield — one line to switch it to the AFKTY URL
- A GitHub Action to rebuild `dist/` on push, so it can't drift from `src/`
- Secure mode and config saving have never run in a real executor — only unit-tested
