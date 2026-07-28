# AFKTY Library — session handoff

State as of **2026-07-28, commit `344bc17`** — 182/182 specs, coverage 86.62%, published.

Open this file and say *"pick up where we left off"*.

---

## Next task: window resizing

Not started. The pieces it needs:

- Drag handles on the window edges and bottom-right corner that don't fight the existing
  `src/components/drag.luau` (which owns moving the window)
- Min/max size clamps, and keeping the window on screen
- **`insetForRail` must re-run on every resize.** It currently applies once when the rail is
  created; a resize would leave the rail inset stale and the content misaligned
- Persist the size through `SaveSettings` / `LoadSettings` so it survives a rejoin
- Specs, following `tests/components/rail.spec.luau`

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
| `expect(...).never` / `.throw()` | Not implemented in this harness. Use `pcall` + `equal`. |
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

- **Window resizing** (above)
- Rail is ~12% of a 465px window vs ~6% in the reference design; narrowing to 44px would
  match
- `GUIGAG2.lua` in `HUB/` still loads Rayfield — one line to switch it to the AFKTY URL
- A GitHub Action to rebuild `dist/` on push, so it can't drift from `src/`
- Secure mode and config saving have never run in a real executor — only unit-tested
