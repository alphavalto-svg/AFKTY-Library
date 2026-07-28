# AFKTY Library

A Roblox UI library for AFKTY Hub, loaded at runtime so a single source edit restyles
every consuming script.

```lua
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/alphavalto-svg/AFKTY-Library/main/dist/Library.lua"))()
```

## API

| Area | Methods |
|------|---------|
| Window | `CreateWindow`, `ChangeTheme`, `Hide`, `Show`, `ToggleMinimise`, `Unload` |
| Layout | `CreateTab`, `CreateGroup`, `CreateSection`, `CreateTag` |
| Elements | `CreateButton`, `CreateToggle`, `CreateSwitch`, `CreateSlider`, `CreateDropdown`, `CreateInput`, `CreateKeybind`, `CreateColorPicker`, `CreateStat` |
| Feedback | `Notify`, `Toast`, `Popup` |
| Persistence | `Save`, `Load`, `SaveSettings`, `LoadSettings`, `ListConfigs`, `DeleteConfig` |

## Themes

Built-ins: `default`, `amethyst`, `cobalt`, `ember`, `frost`, `rose`.

Themes are **partial override tables** — a theme only specifies what differs and inherits
corners, fonts, and toggle/field behaviour from `default`. Adding one means dropping a
file in `src/themes/`.

## Secure mode

Opt in *before* loading:

```lua
getgenv().AFKTY_SECURE = true
```

Reduces the library's detectable footprint:

- **Asset IDs** — icons are cached to disk and served via `getcustomasset`, so asset IDs
  aren't requested at runtime. An icon that fails to cache renders blank rather than
  falling back to a remote ID.
- **Console** — library logging is suppressed.
- **Instance tree** — the ScreenGui parents to `gethui()` rather than `CoreGui`. Always
  on, not gated behind secure mode.
- **Fonts** — a built-in fallback renders immediately while the brand font downloads
  off-thread, then swaps in.

Cached assets are served from this repo's `assets/` folder, so the repo must stay public
for secure mode to populate its cache.

## Build

Toolchain is managed by [Rokit](https://github.com/rojo-rbx/rokit) and pinned in
`rokit.toml`.

```sh
rokit install                                   # one time
make bundle                                     # -> build/bundled.luau
cp build/bundled.luau dist/Library.lua          # publish the artifact
make test                                       # 169 specs
make lint                                       # selene
rojo build default.project.json -o "AFKTY Library.rbxlx"   # Studio test place
```

`build/` is gitignored; **`dist/Library.lua` is committed on purpose** — it's what
`HttpGet` fetches, so a rebuild isn't live until it's committed and pushed.

## License

Mozilla Public License 2.0 — see [LICENSE](LICENSE).

MPL-2.0 is file-level copyleft. Files carrying a copyright header stay under MPL-2.0 and
**their headers must not be removed or altered**; new files may carry any license. The
distributed artifact is source form, which satisfies the source-availability requirement.
