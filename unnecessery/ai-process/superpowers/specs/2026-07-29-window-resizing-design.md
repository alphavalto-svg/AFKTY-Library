# Window resizing — design

**Date:** 2026-07-29
**Status:** approved, implementing

## Goal

Let the player resize the window by dragging a grip in its bottom-right corner. Every hub gets
this without asking; a hub that wants a fixed-size window opts out with one prop.

## Public surface

`resize` on `WindowProps`, defaulting to `true`:

```lua
AFKTY:CreateWindow({ name = "AFKTY Hub" })                 -- resizable
AFKTY:CreateWindow({ name = "AFKTY Hub", resize = false }) -- fixed
```

Lowercase to match the rest of the props (`name`, `subtitle`, `showIcon`). `Resize` is also
accepted, the way `properties.name or properties.Name` already works in the constructor.

Default-on is deliberate: behaviour belongs in the library, not in every consuming script. A
hub should not have to re-type a flag to get the obvious thing.

## Correction to the handoff

`HANDOFF.md` claimed `insetForRail` applies once and would go stale on resize, and listed
re-running it as required work. That is wrong. Everything it touches is either scale-sized or
left-anchored with a pure pixel offset:

| Element | Original | After inset |
|---|---|---|
| `tabList` | `UDim2.new(1, 0, 0, 38)` | `(1, -RAIL_WIDTH, 0, 38)` |
| `elements` | `UDim2.new(1, 0, 1, -106)` | `(1, -RAIL_WIDTH, 1, -106)` |
| `searchPill` | `UDim2.new(1, -35, 0, 35)` | `(1, -35-RAIL_WIDTH, 0, 35)` |
| `topContainer` | `Position (0, 25, 0.5, 0)` | `(0, 25+RAIL_WIDTH, 0.5, 0)` |

The `1` scale tracks the window width on its own and the inset is a constant pixel delta on
top, so it stays correct at any size. Re-running it would subtract `RAIL_WIDTH` again on every
resize and compound — it would introduce the bug, not fix one. **The rail needs no change.**

## Architecture

New `src/components/resize.luau`, constructed from `window.luau` alongside `Drag`, mirroring
`drag.luau`'s shape (`Resize.new(window, properties)`).

Rejected: folding into `drag.luau` (one file owning both moving and sizing, to share ~10 lines
of release boilerplate) and putting it in `window.luau` (already 2461 lines).

### `Window:_applySize(width, height)`

The single funnel. The grip drag, the persistence restore, and any future programmatic sizing
all go through it.

1. Clamp to `minWindowSize` (300×320) and `viewport - viewportMargin` (60), reusing the
   constants already in `window.luau`. No new constants.
2. Write `self.size`. This is the source of truth for the reveal target (`_firstShow`,
   `_quickRestore`, `ToggleMinimise`), the collapsed width, and the drag-bar hang offset — so
   all four show/hide paths inherit the new size for free.
3. Set `self.main.Size` directly. No tween: a resize tracks the cursor rather than lagging it.
4. Shift the centre by half the size delta. `main` is centre-anchored (`AnchorPoint (0.5, 0.5)`),
   so without this, dragging the corner right also grows the window leftward. This pins the
   top-left corner.
5. Resolve `Position` into absolute pixels (`scale * screen + offset`) and write it back as a
   pure offset. `main` starts out scale-centred but both drag paths already leave it in absolute
   offsets, so this keeps a resized window and a dragged one in the same coordinate space
   instead of branching on which happened first.
6. Apply the `keepOnScreen` clamp, so growing near a screen edge cannot push the window off.
7. Reposition the drag bar to the new bottom edge (`main.Position.Y + size.Y/2 + 15`),
   via `Window:_settleDragBar`.

### The grip

A 16×16 `TextButton` in the bottom-right **inside** `main`, above the content ZIndex, with the
same hover-tween treatment `drag.luau` gives its bar. Hidden while minimised or hidden.

### Input lifecycle

Copied from `drag.luau`'s hard-won shape:

- `InputBegan` on the grip arms it (`MouseButton1` or `Touch`)
- `RenderStepped` applies the new size each frame
- Release handled by **both** `InputEnded` and `WindowFocusReleased` — the second is what stops
  an alt-tab mid-grab leaving the resize armed
- Guarded by `window:_interactive()` so a grab during a reveal tween is dropped rather than
  fighting it
- Wired through `window:Connect` so teardown is automatic on `Unload`

### Not fighting the drag

The grip sits inside `main`; the drag bar hangs 15px below it. No overlap, and drag listens on
its own `dragInteract` button, so they are already separate inputs. `window._resizing` is set
anyway so the drag `RenderStepped` loop bails if both ever arm.

## Persistence

`windowWidth` / `windowHeight` join `persistenceSettings` alongside `keepOnScreen`. Restored
through `_applySize` so a rejoin on a smaller screen re-clamps instead of restoring an
oversized window. Type-checked on load like every other key, so a corrupt file cannot brick
`CreateWindow`.

## Testing

`tests/components/resize.spec.luau`, following `tests/components/rail.spec.luau`:

- the grip exists by default
- `resize = false` omits it
- clamps at the 300×320 floor
- clamps at the viewport ceiling
- top-left stays pinned as the window grows
- `self.size` is updated, so the show/hide paths see the new size
- the drag bar follows the new bottom edge
- persistence round-trip restores a saved size
- teardown leaves no connections

Harness note: `HANDOFF.md` claims `expect` has no `.never`. It does — `persistenceSettings.spec`
has used `.never.to.be.ok()` all along, and these specs use it too. Keep boolean conditions in
locals so stylua cannot wrap them across lines and break the coverage instrumenter; that trap
is real.

The bounds and the on-screen clamp are pure functions (`Window.clampSize`,
`Window.clampCentreOnScreen`) taking the viewport and screen rather than reading them, so both
are testable without a camera and neither adds an uncoverable branch.

## Out of scope

- Edge and other-corner handles. One unambiguous grip, clear of the drag bar and the rail.
- A public `Window:SetSize`. `_applySize` is internal; promoting it is a one-line change if a
  hub ever needs it.
- Per-axis resizing.
