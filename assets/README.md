# Assets

Every icon the library ships, as the PNG it was uploaded from. One file per id in
`src/utility/constants.luau`, named `<assetId>.png`.

These are **not** decoration for the repo — secure mode downloads them at runtime from
`https://raw.githubusercontent.com/alphavalto-svg/AFKTY-Library/main/assets/`
(`src/utility/imageCache.luau:33`), writes them to `AFKTY/Assets/<id>.png`, and serves them
through `getcustomasset`. **The repo has to stay public or secure mode cannot populate its
cache.**

## The set

12 names in `constants.icons` resolve to 10 unique ids: `dot` and `colorpicker` share one
glyph, and `banner` and `afkty` share the emblem.

| Name(s) | Asset id | Size | Where it appears |
|---|---|---|---|
| `close` | 90172788330629 | 20×20 | topbar, rightmost |
| `minimise` | 136031305763694 | 20×20 | topbar |
| `maximise` | 134279979385460 | 20×20 | topbar, while minimised |
| `settings` | 123873302071776 | 20×20 | rail bottom stack |
| `search` | 102529133382626 | 20×20 | rail bottom stack, dropdown search |
| `chevron` | 104706369326409 | 16×16 | dropdown header |
| `check` | 95316442098951 | 16×16 | selected dropdown option |
| `dot`, `colorpicker` | 95965547856004 | 16×16 | unselected option; "Invisible" mark |
| `config` | 139478662436110 | 24×24 | saved-configurations picker |
| `banner`, `afkty` | 85628806611332 | 256×256 | build-time emblem, rail brand mark |

**Every id above is an AlphaValto upload.** The nine glyphs were reuploaded and swapped in
`2026-07-29`, replacing the ids inherited from upstream in `d5737be`; the emblem has been AFKTY's
own since `ea55806` (resized in `bb86fcd`, 1254px original in `source/`). The library no longer
requests any asset it does not own.

Each upload is named after the id it replaced, so the old-to-new mapping stays recoverable from
the Roblox side without consulting this file.

## Why ownership, not stealth

The reason the swap was worth doing: an upload this project does not control can be deleted or
moderated at any time, and every icon in the hub would break in normal mode with no recourse.
That is the real exposure, and it is now closed.

It was never a detectability fix. In secure mode the ids are never requested at all — the PNGs in
this folder are cached to disk and served from there. Normal mode does render `rbxassetid://<id>`,
but reading those properties back means reaching the ScreenGui first, and it is kept out of reach
whether or not secure mode is on — `gethui()` where the executor has it, otherwise the protect
call and then `RobloxGui` (`src/utility/runtime.luau:58`).

## Swapping an icon

1. Upload the replacement to Roblox as an **Image** (`AssetTypeId` 1 — that is what
   `ImageLabel.Image` takes). Keep the pixel dimensions above; they are what the layout was built
   against.
2. Wait for moderation. A pending or blocked id renders **blank rather than erroring**, so confirm
   the thumbnail state reads `Completed` before wiring it in:

   ```sh
   curl -s "https://thumbnails.roblox.com/v1/assets?assetIds=<id>&size=150x150&format=Png"
   ```

3. Rename the file here to the **new** id. The filename *is* the cache key, so the two must agree
   or secure mode caches under a name it will never look up.
4. Point `constants.icons` at the new id. That table is the single source of truth: `imageCache`
   builds its download manifest by iterating it, so a new id caches automatically with no other
   change.
5. Rebuild and republish, or the shipped bundle keeps the old id:

   ```sh
   lune run build
   ```

6. Commit **both** `assets/` and `dist/Library.lua`, and push. `dist/Library.lua` is what
   `HttpGet` fetches, so nothing is live until it is on `main`.

### Checking it worked

- Every id in `constants.icons` has a file here, and no file is orphaned.
- In Studio, the window builds with no blank icons.
- In an executor with secure mode on, `AFKTY/Assets/` fills with the new `.png` filenames —
  `executor.test.lua` has a button that counts them.

## Icons a hub passes in

Anything a consuming script supplies (`CreateTab({ icon = ... })` and friends) is **not** in this
set and is not cached. In secure mode those resolve blank, and the library raises one notification
saying so. A hub that wants its own artwork in secure mode has to cache it itself and pass the
resulting `getcustomasset` string.

**The demos are consumers, and their art is still upstream.** `example.client.luau`,
`studio.client.luau`, `studio.tour.client.luau` and `docs/TUTORIAL.md` pass assorted ids as
illustrative icons — some that used to be in this set, plus others (`93364949241311`,
`84750991656135`, `85925158736685`) that never were. They were left alone in the swap: they are
stand-ins for "whatever a hub supplies", they still render, and repointing only the overlapping
subset would remove nothing while looking like it had. Making the demos fully self-owned means
uploading that art too, and is a separate job.
