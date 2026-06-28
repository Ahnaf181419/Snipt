# snipt — shadcn/ui Migration Plan

**Date:** June 28, 2026  
**Package:** `shadcn_ui` 0.55.0 (mariuti, MIT) + `lucide_icons_flutter`  
**Strategy:** Full swap to `ShadApp.router`, incremental screen-by-screen  
**Dynamic color:** Dropped (pure shadcn neutrals)  
**Icons:** Material Icons → lucide line icons  

---

## Why `shadcn_ui` over `shadcn_flutter`

- MIT license vs BSD-3
- 61.8k weekly downloads vs 10.3k (6x more adopted)
- 0.55.0 (mature API) vs 0.0.52 (pre-1.0, breaking-change risk)
- Name match: user asked for "shadcn ui"
- Missing Skeleton component is fine — we ship a custom `SkeletonClipTile`

---

## Architecture notes (verified from source)

`ShadApp.router` builds `WidgetsApp.router` wrapped in `AnimatedTheme`, so:
- `Theme.of(context)` resolves correctly (maps shadcn colorScheme → Material ColorScheme)
- `Scaffold`, `AppBar` work (they only need `Theme` in scope)
- `ScaffoldMessenger` is **not** auto-provided — bridged via `builder:` wrapper

Theme access: `ShadTheme.of(context)` returns `ShadThemeData`.
Color scheme: `ShadZincColorScheme.light()` / `.dark()` (shadcn's default neutral).

---

## Component mapping

| Material | shadcn_ui |
|---|---|
| `MaterialApp.router` | `ShadApp.router` |
| `Card` | `ShadCard` |
| `FilledButton.icon` | `ShadButton(child:, leading:)` |
| `OutlinedButton` | `ShadButton.raw(variant: outline)` |
| `TextButton` | `ShadButton.raw(variant: ghost)` |
| `TextField` | `ShadInput` |
| `SwitchListTile` | `ShadSwitch` + Row |
| `DropdownButton` | `ShadSelect<T>` |
| `PopupMenuButton` | `ShadContextMenu` |
| `showModalBottomSheet` | `showShadSheet` |
| `SnackBar` | `ShadSonner` (toast) |
| `Icons.*` | `LucideIcons.*` |

---

## Phase breakdown

| # | Phase | Status |
|---|---|---|
| 1 | Deps: add shadcn_ui + lucide, drop dynamic_color | done |
| 2 | Root swap: `ShadApp.router` + `ShadThemeData` | done |
| 3 | Atoms: EmptyState, ProGate rewrite | done |
| 4 | Settings screen | done |
| 5 | History screen | done |
| 6 | Detail screen | done |
| 7 | Onboarding screen | done |
| 8 | Icon sweep (Material → lucide) | done |
| 9 | Verify analyze + test + build | done |
