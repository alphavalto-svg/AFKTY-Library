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

| Name(s) | Asset id | Size | Where it appears | Origin |
|---|---|---|---|---|
| `close` | 83277910885129 | 20×20 | topbar, rightmost | forked |
| `minimise` | 108115485663409 | 20×20 | topbar | forked |
| `maximise` | 88738500661569 | 20×20 | topbar, while minimised | forked |
| `settings` | 129180860773723 | 20×20 | rail bottom stack | forked |
| `search` | 100604009889706 | 20×20 | rail bottom stack, dropdown search | forked |
| `chevron` | 88479147175134 | 16×16 | dropdown header | forked |
| `check` | 125626312718314 | 16×16 | selected dropdown option | forked |
| `dot`, `colorpicker` | 91452555903853 | 16×16 | unselected option; "Invisible" mark | forked |
| `config` | 125823673784681 | 24×24 | saved-configurations picker | forked |
| `banner`, `afkty` | 85628806611332 | 256×256 | build-time emblem, rail brand mark | **AFKTY** |

"forked" = inherited from upstream in `d5737be`, so those nine ids are uploads on an account
this project does not control. The emblem is AFKTY's own upload (`ea55806`, resized in
`bb86fcd`; the 1254px original is in `source/`).

## Reuploading the nine inherited icons

Worth doing for **ownership**, not for stealth. If any of those uploads is deleted or
moderated, every icon in the hub breaks in normal mode and there is nothing this project can do
about it. That is the actual exposure.

It changes nothing about detectability in secure mode: there the ids are never requested at all,
because the PNGs in this folder are cached to disk and served from there. Normal mode does render
`rbxassetid://<id>`, but the ScreenGui lives behind `gethui()` (always on, not gated on secure
mode), so a game script cannot walk the tree to read those properties back.

### Steps

1. Upload each `<id>.png` in this folder to Roblox as a Decal / Image. Keep the pixel dimensions
   above — they are the sizes the layout was built against.
2. Wait for moderation. A pending id renders blank.
3. Rename the file here to the **new** id. The filename *is* the cache key, so the two must agree.
4. Point `constants.icons` at the new ids. That table is the single source of truth: `imageCache`
   builds its download manifest by iterating it, so a new id caches automatically with no other
   change.
5. Rebuild and republish, or the shipped bundle keeps the old ids:

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
