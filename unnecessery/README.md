# unnecessery/

Nothing in here is needed to build, ship, or run the AFKTY Library. It is kept only so the
history is not lost. Deleting this whole folder would not affect `dist/Library.lua`.

| Folder | What it is |
|---|---|
| `ai-process/` | Design specs, implementation plans, session handoff notes and the task ledger from when the library was built. Notes about the work, not the work. |
| `screenshots/` | Bug screenshots and a render used while debugging. |
| `executor-scripts/` | `executor.test.lua` (secure-mode smoke test) and `executor.tour.lua` (full walkthrough). One-off probes pasted into an executor by hand. |
| `studio-tour/` | `studio.tour.client.luau` — a scripted Studio walkthrough. Was wired into `default.project.json` as a disabled script; never run. |
| `asset-sources/` | The 1254px master for icon `85628806611332`. The shipped icon in `assets/` is the export. |

## If you want one of these back

The executor scripts and the Studio tour still reference the library by its public API, so
they work unchanged — copy them back out.

`studio-tour/studio.tour.client.luau` additionally needs its entry restored in
`default.project.json`:

```json
"Tour": {
  "$path": "studio.tour.client.luau",
  "$properties": { "Disabled": true }
}
```
