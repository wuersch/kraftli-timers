# Kraftli Timers – Claude Instructions

Native iOS fitness app for high-intensity, minimalistic workouts.

## Tech Stack
- iOS 26+ | Swift 6.2 | SwiftUI | SwiftData

## Project Goal
Learning project: educational value matters as much as working code. Explain SwiftUI concepts when introducing new patterns.

## Documentation

| Document | Contents |
|----------|----------|
| [SPEC/scope.md](SPEC/scope.md) | Current release features, details, and UI spec |
| [SPEC/backlog.md](SPEC/backlog.md) | Future features (requires promotion) |
| [ARCHITECTURE/architecture.md](ARCHITECTURE/architecture.md) | Data models, patterns, components |
| [ARCHITECTURE/decisions/](ARCHITECTURE/decisions/) | Architecture Decision Records |

## Rules
- **Only implement from scope.md** – backlog items require explicit promotion
- Discuss new feature ideas before adding them to documentation
- Plan before coding: summarize approach, list assumptions and options
- Document significant architectural decisions as ADRs

## Project Structure
- `App/` - Entry point and root navigation
- `Features/` - Feature modules with co-located Model+View
- `Models/` - SwiftData persistence models only
- `Services/` - Protocols + implementations
- `Components/` - Reusable UI components
- `Modifiers/` - SwiftUI view modifiers
- `Extensions/` - Type extensions

## Design Philosophy
- Native SwiftUI components (Button, List, NavigationStack)
- iOS 26 design elements where they enhance minimalism
- Avoid glass effects – clarity over visual effects
- Dark background + minimal UI = keep it simple

## Workflow
1. Plan before coding: summarize approach, list assumptions and options
2. Ask questions if requirements unclear
3. Discuss new feature ideas before adding to scope
4. Implement in small, testable steps
5. Branch for each feature: `feature/name` or `fix/name`
6. Present options with tradeoffs when multiple approaches exist

## Git Safety
- Always inspect stash contents before dropping (`git stash show -p`)
- Xcode modifies `project.pbxproj` unexpectedly; don't assume uncommitted changes are insignificant

## Commands
- Build: `xcodebuild -scheme "Kraftli Timers" -destination "platform=iOS Simulator,name=iPhone 17 Pro" build`
- Run tests: `xcodebuild -scheme "Kraftli Timers" -destination "platform=iOS Simulator,name=iPhone 17 Pro" test`
- Run in simulator: Xcode
- **MANDATORY: Always ask the user before running tests or builds.** Running simulators draws heavy power on Apple Silicon — parallel sim workloads can trigger a protective shutdown. Never run tests or builds without explicit permission.

## Xcode Project
- Xcode automatically adds new files to the target whose folder they belong to. No manual step needed for single-target files.
- Only manual intervention is needed when a file must belong to multiple targets (e.g., shared code between iPhone and Watch).

## XcodeBuildMCP
- When using XcodeBuildMCP tools, use `projectPath` (not `workspacePath`) since this is a `.xcodeproj`, not a `.xcworkspace`.
- Use `xcodebuild` (via the Commands above) for compile checks and running tests. Only use XcodeBuildMCP build/run tools when you need to verify something in the running app (gestures, visuals, UI interaction).
