# Task Memory: task_10.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Package SwiftPM localization resources into the manually assembled `.build/Pi Agent.app` for debug and release builds without changing the app bundle path.

## Important Decisions
- Baseline gap captured before edits: `rtk ./Scripts/build-app.sh` produced `.build/Pi Agent.app`, but `Contents/Resources` contained only `AppIcon.icns` while SwiftPM emitted `.build/debug/PiAgentNative_PiAgentNativeCore.bundle`.
- `Scripts/build-app.sh` now discovers the resource bundle by asking SwiftPM for the actual binary output path with `--show-bin-path`, then selecting a `.bundle` containing `Info.plist`, English `Localizable.strings`, and pt-BR `Localizable.strings`.
- The script copies the entire SwiftPM-generated `.bundle` into app `Contents/Resources`, not raw source `.lproj` folders, and verifies packaged English/pt-BR strings before printing the app path.
- Generated app `Info.plist` now includes `CFBundleDevelopmentRegion = en` and `CFBundleLocalizations = [en, pt-BR]`.

## Learnings
- With `swift build --build-path`, SwiftPM may place products under an architecture-qualified directory such as `<build-root>/arm64-apple-macosx/debug`; `swift build --show-bin-path` is the robust way to locate debug/release products.
- SwiftPM lowercases the processed Brazilian Portuguese resource directory to `pt-br.lproj`; verification remains case-insensitive for locale folder names.

## Files / Surfaces
- Planned scope: `Scripts/build-app.sh`, build-script tests, README packaged-app docs, task memory/tracking files.
- Touched surfaces: `Scripts/build-app.sh`, `README.md`, `Tests/PiAgentNativeCoreTests/BuildAppScriptTests.swift`, current task memory, and current task subtask checkboxes.

## Errors / Corrections
- Initial integration-test attempt ran `swift build` from inside `swift test` against the default `.build` tree and blocked on SwiftPM build state; corrected by letting tests set `PI_AGENT_NATIVE_SWIFTPM_BUILD_ROOT` while keeping the assembled app path at `.build/Pi Agent.app`. External verification still exercises the default build path.
- First temp-build integration test assumed products lived directly under `<build-root>/<configuration>`; corrected script to use SwiftPM `--show-bin-path`.

## Ready for Next Run
- Functional verification passed on 2026-05-08: `rtk bash -n Scripts/build-app.sh`, focused `BuildAppScriptTests`, default `rtk ./Scripts/build-app.sh`, default `rtk ./Scripts/build-app.sh release`, full `rtk swift test`, coverage-enabled `rtk swift test --enable-code-coverage`, and `rtk git diff --check` all exited 0.
- The release app at `.build/Pi Agent.app` contains executable, `AppIcon.icns`, and `Contents/Resources/PiAgentNative_PiAgentNativeCore.bundle/{en.lproj,pt-br.lproj}/Localizable.strings`.
- Task tracking status was not marked completed because the project-wide source coverage report remains below the explicit 80% target: final `llvm-cov report` showed 33.46% line coverage.
