# Repository Guidelines

## Project Structure & Module Organization

- `PCLMacCE/` contains the SwiftUI app: `Views/`, `ViewModels/`, `Managers/`, `Components/`, `App/`, `Services/`, and `Theme/`.
- `PCLMacCE.Core/` holds UI-independent Minecraft, Java, networking, model, task, and utility code.
- `PCLMacCE.Tests/` contains the Swift Testing suite. New tests belong near their domain; use `*Tests.swift` names (some older files use `*Test.swift`).
- `Configs/` stores build settings and the test plan; `Resources/` stores localization, assets, and license notices; `Packaging/` contains DMG resources; `docs-book/` contains architecture, risk, decision, and release documentation.

## Build, Test, and Development Commands

Develop on macOS 14.5+ with Xcode 16+. The app targets macOS 12.0; the test target requires macOS 14.0+.

```bash
xcodebuild -project PCLMacCE.xcodeproj -scheme PCLMacCE build
xcodebuild test -project PCLMacCE.xcodeproj -scheme PCLMacCE
xcodebuild test -project PCLMacCE.xcodeproj -scheme PCLMacCE \
  -only-testing:PCLMacCE.Tests/ResourceSearchTests
swiftlint lint --config .swiftlint.yml --strict
```

The test plan sets `PCL_MAC_TESTING=1` and isolates app data under `~/Library/Application Support/PCLMacCE/TestHome`. The path-filtered PR workflow excludes tests and docs, and runs lint plus a Debug build. Run tests manually; release CI selects only offline cases.

## Coding Style & Naming Conventions

Use four-space indentation, UpperCamelCase types, and lowerCamelCase methods and properties. Keep comments, user-facing text, documentation, and commit messages in Simplified Chinese. Use `@MainActor` for app ViewModels and Managers, and make Core value types exposed to the app `Sendable`. Centralize request URLs in `PCLMacCE.Core/Utils/APIEndpoints.swift` or `WebLinks.swift`, UI values in `PCLMacCE/Extensions/DesignTokens.swift`, logging through `log()`, `err()`, `warn()`, or `debug()`, and JSON through shared coders. Avoid force unwraps and `print`.

## Testing Guidelines

Write behavior-focused Swift Testing cases with `@Test`. Prefer deterministic offline Core tests; keep network-dependent tests explicit and do not require live credentials for the offline suite. Run the full suite before submitting changes.

## Commit & Pull Request Guidelines

Branch from `dev`. Use one change per commit with a Chinese summary, such as `feat: 资源搜索支持筛选` or `fix: 修复实例配置读取`; accepted types include `feat`, `fix`, `docs`, `refactor`, `chore`, and `test`. Explain behavior changes in the commit body. Follow `.github/PULL_REQUEST_TEMPLATE.md`, link relevant issues, include UI screenshots, and describe migration steps for data or configuration changes.

## Security, Licensing & Releases

Never commit API keys, tokens, certificates, or local secrets. Preserve the root `LICENSE`, `PCLMacCE.Core/LICENSE`, and notices in `Resources/licenses/`. Read `docs-book/src/run/release-playbook.md` before packaging: release automation requires signing and notarization credentials, creates a draft, and its offline tests do not replace real-device installation and launch checks.
