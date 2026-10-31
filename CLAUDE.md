# Kraftli Timers – Claude Instructions

Native iOS fitness app for high-intensity, minimalistic workouts.

## Project Goal
Learning project: educational value matters as much as working code. Explain SwiftUI concepts when introducing new patterns.

## Documentation

| Document | Contents |
|----------|----------|
| [docs/scope.md](docs/scope.md) | Release overview; index of use cases and ADRs with status |
| [docs/use-cases/](docs/use-cases/) | Use case specifications (UC-NNNN), the normative requirements |
| [docs/use-cases/ui-spec.md](docs/use-cases/ui-spec.md) | Interaction design: screens, gestures, copy |
| [docs/backlog.md](docs/backlog.md) | Future features (requires promotion) |
| [docs/architecture.md](docs/architecture.md) | Data models, patterns, components |
| [docs/adr/](docs/adr/) | Architecture Decision Records (ADR-NNNN, MADR format) |
| [docs/plans/](docs/plans/) | Implementation plans for larger changes |

## Rules
- **Only implement use cases with status `approved` or later** – backlog items require explicit
  promotion, which means specifying them as a use case
- New or changed behavior → `/adlc:use-case` (revise an existing UC rather than creating a duplicate)
- Significant, hard-to-reverse structural decisions → `/adlc:adr` (in `docs/adr/`)
- Keep use cases interaction-agnostic; screens and gestures go into `docs/use-cases/ui-spec.md`
- When a change realizes a use case or ADR, update its status (and `docs/scope.md`)
- Discuss new feature ideas before adding them to documentation
- Plan before coding: summarize approach, list assumptions and options
- Check docs: `python3 -I ~/.claude/plugins/cache/adlc-marketplace/adlc/*/scripts/check-docs.py .`

## Project Structure
- `Features/` - Feature modules with co-located Model+View
- `Models/` - SwiftData persistence models only
- `Services/` - Protocols + implementations: `protocol` → `Default…` (production) → `Silent…`
  (previews/tests); inject `now`/scheduling seams for timing logic
- Code shared with the Watch lives in the iOS folders and joins the Watch target via membership
  exceptions; guard platform differences with `#if os()`

## Design Philosophy
- Native SwiftUI components (Button, List, NavigationStack)
- iOS 26 design elements where they enhance minimalism
- Avoid glass effects – clarity over visual effects
- Dark background + minimal UI = keep it simple

## Workflow
- Branch for each feature: `feature/name` or `fix/name`
- Present options with tradeoffs when multiple approaches exist

## Git Safety
- Always inspect stash contents before dropping (`git stash show -p`)
- Xcode modifies `project.pbxproj` unexpectedly; don't assume uncommitted changes are insignificant

## Commands
- Build: `xcodebuild -scheme "Kraftli Timers" -destination "platform=iOS Simulator,name=iPhone 17 Pro" build`
- Run tests: `xcodebuild -scheme "Kraftli Timers" -destination "platform=iOS Simulator,name=iPhone 17 Pro" test`
- Run in simulator: Xcode
- Builds can be run freely without asking.
- **MANDATORY: Always ask the user before running the full test suite.** Running simulators draws heavy power on Apple Silicon — parallel sim workloads can trigger a protective shutdown. Never run all tests without explicit permission.

## Xcode Project
- Xcode automatically adds new files to the target whose folder they belong to. No manual step needed for single-target files.
- Only manual intervention is needed when a file must belong to multiple targets (e.g., shared code between iPhone and Watch).

## XcodeBuildMCP
- When using XcodeBuildMCP tools, use `projectPath` (not `workspacePath`) since this is a `.xcodeproj`, not a `.xcworkspace`.
- Use `xcodebuild` (via the Commands above) for compile checks and running tests. Only use XcodeBuildMCP build/run tools when you need to verify something in the running app (gestures, visuals, UI interaction).
