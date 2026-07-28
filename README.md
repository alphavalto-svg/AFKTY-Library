# AFKTY Library

A reusable Roblox UI library for AFKTY Hub, loaded at runtime so a single source edit
restyles every consuming script.

```lua
local Library = loadstring(game:HttpGet("<raw url>"))()
```

> **Status:** early setup. No implementation yet — see Roadmap.

## Design

- **Rayfield-style API** with a custom Dark Emerald theme.
- **Executor-agnostic.** Capabilities are feature-detected from globals rather than
  targeting one executor, so the library also runs in Roblox Studio.
- **Multi-file source, single-file output.** `src/` is bundled by `build.js` into one
  `dist/Library.lua`, which is what consumers fetch.
- **Theme registry** built on a single primitive, `Library:Create(class, props, themeMap)`.
- **Flags are objects** exposing `:Set()`, not raw values.

## Roadmap

| Phase | Scope |
|-------|-------|
| 1 | Core engine + security |
| 2 | Window + dual navigation |
| 3 | Elements |
| 4 | Notifications |
| 5 | JSON config saving |

## Note on the loader

`raw.githubusercontent.com` serves content to unauthenticated requests only from public
repositories. While this repo is private, `HttpGet` against a raw URL will fail — the
loader path can only be tested end-to-end once the repo is made public.
