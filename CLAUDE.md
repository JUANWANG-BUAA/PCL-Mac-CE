# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

PCL.Mac is an unofficial macOS derivative of [Plain Craft Launcher](https://github.com/Meloong-Git/PCL) (a Minecraft launcher), completely rewritten in SwiftUI. It supports macOS 12.0+ (Universal: Intel + Apple Silicon).

## Build and test

```bash
# Build the project
xcodebuild -project PCL.Mac.xcodeproj -scheme PCL.Mac build

# Run all tests
xcodebuild test -project PCL.Mac.xcodeproj -scheme PCL.Mac

# Run a single test class
xcodebuild test -project PCL.Mac.xcodeproj -scheme PCL.Mac \
  -only-testing:PCL.Mac.Tests/<ClassName>

# Run a single test method
xcodebuild test -project PCL.Mac.xcodeproj -scheme PCL.Mac \
  -only-testing:PCL.Mac.Tests/<ClassName>/<testMethod>
```

Tests set the environment variable `PCL_MAC_TESTING=1` (configured in `Configs/PCL.Mac.xctestplan`). Tests run in parallel (`parallelizable: true`).

Xcode build configs in `Configs/`: `Base.xcconfig` → `Debug.xcconfig` / `Release.xcconfig`. Debug sets `DEBUG_MODE = YES`.

## Architecture

### Two-module structure

| Module | Role |
|---|---|
| **PCL.Mac** | App/UI layer: SwiftUI views, view models, UI managers, routing |
| **PCL.Mac.Core** | Core logic: models, services, Minecraft/Java management, task framework, utilities. No UI dependencies. |

PCL.Mac imports `Core` (PCL.Mac.Core). PCL.Mac.Core imports `SwiftScaffolding` for global logging functions.

### Directory layout (PCL.Mac — UI module)

- `App/` — App entry point (`@main`), `AppDelegate`, `AppWindow` (NSWindow subclass), `AppRouter` (navigation), `LauncherConfig` (persisted settings), `Secrets`
- `Views/` — SwiftUI views organized by feature: `Download/`, `Launch/` (with `InstanceList/`, `InstanceSettings/`), `Settings/`, `More/`, `Tasks/`
- `ViewModels/` — `ObservableObject` view models, including `Instance/` subdirectory
- `Models/` — UI-layer data models (`ListItem`, `UpdateModel`, `MessageBoxModel`, etc.)
- `Managers/` — Singleton managers: `MinecraftLaunchManager`, `TaskManager`, `HintManager`, `MessageBoxManager`, `UpdateManager`, `EasterEggManager`, `FileDropHandler`
- `Components/` — Reusable SwiftUI components prefixed with `My` (`MyCard`, `MyButton`, `MyText`, `MyList`, `MyLoading`, `MyTag`, etc.)
- `Extensions/` — SwiftUI `EnvironmentValues` keys, `Color` extensions, localization extensions
- `Services/` — `UpdateService` (UI-layer service)
- `Task/` — `MinecraftLaunchTask` (game launch orchestration)

### Directory layout (PCL.Mac.Core — Core module)

- `Minecraft/` — Core Minecraft logic: `MinecraftRepository` (`.minecraft` directory), `MinecraftVersion`, `MinecraftInstance`, launch subsystem (`MinecraftLauncher`, `LaunchOptions`, `LaunchPrecheck`, `LogManager`)
- `Models/` — Data models organized by domain: `Account/`, `Minecraft/`, `Modrinth/`, `CurseForge/`, `Modpack/`
- `Services/` — API clients (`ModrinthAPIClient`, `CurseForgeAPIClient`, `CLAPIClient`), auth (`MicrosoftAuthService`, `YggdrasilService`), instance loading, resource parsing, Java search, modpack import
- `Managers/` — `InstanceManager` (multi-repository instance orchestration), `JavaManager`
- `Task/` — Task framework: `MyTask<Model>` with `SubTask` (ordinal-based concurrent execution), plus concrete tasks (`MinecraftInstallTask`, `JavaInstallTask`, `ModpackImportTask`)
- `Utils/` — `Requests` (HTTP client), `URLConstants`, `Architecture`, `FileUtils`, `NativesMapper`, `JarUtils`, etc.
- `Extensions/` — `JSONDecoder.shared` / `JSONEncoder.shared` (ISO8601 dates), `Optional.unwrap()`, `Error.isCancellationError`, `String+SHA1`

### Navigation

`AppRouter` (singleton `ObservableObject`) manages navigation via `AppRoute` enum with a path stack. Root routes: `launch`, `download`, `settings`, `more`. Sub-pages are pushed onto the path. `AppRouterView` switches on the current route to render the appropriate page. `AppSidebarView` switches on the route to render the matching sidebar.

`Sidebar` is a protocol (`protocol Sidebar: View { var width: CGFloat { get } }`) — each section implements its own sidebar. The sidebar's width animates on route changes via a white-dominant design.

### Task framework

`MyTask<Model>` runs `SubTask` instances grouped by `ordinal`. Sub-tasks within the same ordinal execute concurrently; ordinal groups execute sequentially. `TaskManager` wraps execution with UI feedback (hints, error messages). `SubTask` provides progress and state (`waiting → executing → finished/failed`).

### Key patterns

- **Concurrency**: `SWIFT_STRICT_CONCURRENCY = targeted` is enabled (see `Configs/Base.xcconfig`, roadmap: targeted → complete → Swift 6). Conventions: ViewModel/Manager `ObservableObject` classes are `@MainActor`; don't wrap `await MainActor.run { … }` inside their methods (already on main). Core value types exposed to App must be `Sendable`. Use `@preconcurrency import Core` / `@preconcurrency import SwiftScaffolding` at boundaries until the Sendable audit completes. `MyTask` model carriers are `@unchecked Sendable` by design (shared mutable state across subtasks) — see docs-book ADR-003.
- **Naming**: never use backtick-escaped type names — use `Style` (`MyButton.Style`) / `Kind` (`HintModel.Kind`) suffixes for associated enums.
- **Global logging**: `log()`, `err()`, `warn()`, `debug()` are global functions defined in `PCL.Mac.Core/Minecraft/Launch/LogManager.swift`. They write to rotating log files (`Log1.log` through `Log5.log`) in `~/Library/Application Support/PCL.Mac/Logs/`.
- **Remote URL registry**: ALL remote endpoints live in `PCL.Mac.Core/Utils/APIEndpoints.swift` (program-requested APIs) and `PCL.Mac.Core/Utils/WebLinks.swift` (browser-opened links). Never inline `https://…` literals in services or views; add or reference a constant there instead. Dead endpoints are removed from code; their history is recorded in `docs-book` ADRs and the risk register.
- **UI design tokens**: `PCL.Mac/Extensions/DesignTokens.swift` defines `Spacing`, `Radius`, `ShadowToken`, `Font.pcl(_:)`/`Font.cardTitle`, and semantic colors (`.danger`). The `My*` components are the token consumption boundary — prefer tokens over raw values in new UI code. The brand palette `Color.color1-8` / `colorGray1-8` (from PCL2-CE, issue #13) is the primitive layer; do not rename it.
- **UI hints**: `hint()` global function (defined in `PCL.Mac/Managers/HintManager.swift`) shows a floating toast notification.
- **Shared JSON coders**: `JSONDecoder.shared` / `JSONEncoder.shared` (ISO8601 dates, pretty-printed/sorted-key encoding). Always use these.
- **Secrets**: Loaded from `Resources/Secrets.properties` or environment variables prefixed `PCLMAC_`. Currently only `CURSE_FORGE_API_KEY`.
- **LauncherConfig**: JSON-based persistence at `~/Library/Application Support/PCL.Mac/config.json`. Codable with backup on load failure.
- **`Optional.unwrap()`**: Throws `SimpleError` on nil — preferred over force-unwrap for better error messages.
- **Chinese-first codebase**: Comments, user-facing strings, and commit messages are in Chinese.

### Review guidelines (from `.github/copilot-instructions.md`)

- Write review comments in Simplified Chinese (简体中文)
- Call out incorrect usage or misspelled words
- `public` members in `internal`/`private` classes are acceptable
