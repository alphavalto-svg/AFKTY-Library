# AFKTY Library

A Roblox UI library for AFKTY Hub, loaded at runtime so a single source edit restyles
every consuming script.

```lua
local Library = loadstring(game:HttpGet("<raw url>"))()
```

## Origin and license

This is a fork of [Rayfield Gen 2](https://github.com/SiriusSoftwareLtd/rayfield-gen2) by
Corridon Capital, used under the **Mozilla Public License 2.0**.

MPL-2.0 is file-level copyleft. Every file inherited from upstream keeps its original
copyright header and stays under MPL-2.0 — **do not strip those headers.** New files
authored here may carry any license. The distributed artifact (`dist/Library.lua`) is
source form, which satisfies MPL's source-availability requirement automatically.

## API

Unchanged from Rayfield Gen 2, so existing scripts port by swapping the URL only.

| Area | Methods |
|------|---------|
| Window | `CreateWindow`, `ChangeTheme`, `Hide`, `Show`, `ToggleMinimise`, `Unload` |
| Layout | `CreateTab`, `CreateGroup`, `CreateSection`, `CreateTag` |
| Elements | `CreateButton`, `CreateToggle`, `CreateSwitch`, `CreateSlider`, `CreateDropdown`, `CreateInput`, `CreateKeybind`, `CreateColorPicker`, `CreateStat` |
| Feedback | `Notify`, `Toast`, `Popup` |
| Persistence | `Save`, `Load`, `SaveSettings`, `LoadSettings`, `ListConfigs`, `DeleteConfig` |

## Themes

Built-ins: `default`, `amethyst`, `cobalt`, `ember`, `frost`, `rose`.

Themes are **partial override tables** — a new theme only specifies what differs and
inherits corners, fonts, and toggle/field behaviour from `default`. Adding one means
dropping a file in `src/themes/`, which is the intended customization seam.

## Secure mode

Opt in *before* loading the library:

```lua
getgenv().AFKTY_SECURE = true
```

It reduces the library's detectable footprint:

- **Asset IDs** — icons are cached to disk and served via `getcustomasset`, so known
  asset IDs aren't requested at runtime. An icon that fails to cache renders blank
  rather than falling back to a remote ID.
- **Console** — all library logging is suppressed, so it never announces itself.
- **Instance tree** — the ScreenGui parents to `gethui()` rather than `CoreGui`.
  (This one is always on, not gated behind secure mode.)
- **Fonts** — a built-in fallback renders immediately while the brand font downloads
  off-thread, then swaps in.

Trade-off: if asset caching fails, icons silently disappear. The library surfaces an
on-screen notification instead of a console warning, since the console is muted.

## Build

Toolchain is managed by [Rokit](https://github.com/rojo-rbx/rokit) and pinned in
`rokit.toml`.

```sh
rokit install                                   # one time
make bundle                                     # -> build/bundled.luau
cp build/bundled.luau dist/Library.lua          # publish the artifact
make test                                       # 169 specs
```

`build/` is gitignored; **`dist/Library.lua` is committed on purpose** — it's what
`HttpGet` fetches.

## Known constraints

- **The loader needs a public repo.** `raw.githubusercontent.com` only serves
  unauthenticated requests from public repositories. While this repo is private,
  `HttpGet` against a raw URL returns 404. Building and testing work fine; only the
  live loader path is blocked.
- **Secure-mode icons still come from upstream.** `src/utility/imageCache.luau` points
  `assetBase` at Sirius's repo, because a private repo can't serve the asset PNGs.
  To cut that dependency, make this repo public and repoint `assetBase` at it.
