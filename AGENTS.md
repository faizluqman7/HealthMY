# AGENTS.md — HealthMY

## Project Overview

iOS health-tracking app built with **SwiftUI** + **SwiftData**. Tracks blood pressure, weight, height, pulse, sleep, glucose, and other vitals. Integrates with Apple HealthKit and a backend API for AI-powered health summaries. Zero external dependencies — only Apple frameworks (SwiftUI, SwiftData, HealthKit, Charts, Foundation).

- **Language:** Swift 5.0
- **Min deployment:** iOS 18.5
- **Bundle ID:** `Faiz-Luqman.HealthMY`
- **Architecture:** Views with inline logic (not strict MVVM). One experimental ViewModel exists (`EditHeightReadingViewModel`).

## Build / Test Commands

All commands use `xcodebuild`. No Makefile, no SPM `Package.swift`, no CocoaPods.

```bash
# Build (Debug, simulator)
xcodebuild -project HealthMY.xcodeproj -scheme HealthMY -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run all unit tests
xcodebuild -project HealthMY.xcodeproj -scheme HealthMY -destination 'platform=iOS Simulator,name=iPhone 16' test

# Run a single test class
xcodebuild -project HealthMY.xcodeproj -scheme HealthMY -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:HealthMYTests/APIServiceTests test

# Run a single test method
xcodebuild -project HealthMY.xcodeproj -scheme HealthMY -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:HealthMYTests/APIServiceTests/testEncodeWeightEntry test

# Run UI tests
xcodebuild -project HealthMY.xcodeproj -scheme HealthMY -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:HealthMYUITests test

# Clean build
xcodebuild -project HealthMY.xcodeproj -scheme HealthMY clean
```

**No linter or formatter is configured.** No SwiftLint, SwiftFormat, or CI/CD pipeline exists.

## Directory Structure

```
HealthMY/
├── HealthMY.xcodeproj/
├── HealthMY/                    # App source
│   ├── HealthMYApp.swift        # @main entry point
│   ├── View/                    # SwiftUI views (all UI lives here)
│   ├── Models/                  # SwiftData @Model classes
│   ├── services/                # APIService (singleton, networking)
│   └── utils/                   # HealthKitManager (singleton)
├── HealthMYTests/               # Unit tests (APIServiceTests)
└── HealthMYUITests/             # UI tests (boilerplate)
```

## Code Style Guidelines

### Imports

- One import per line. No blank lines between imports.
- No enforced ordering. General convention: `SwiftUI` first, then `SwiftData`, then others.
- Models import `SwiftData` then `Foundation`.

### Naming Conventions

| Category | Convention | Examples |
|---|---|---|
| Types | PascalCase, descriptive nouns | `BloodPressureReading`, `WeightInputView` |
| Variables | camelCase | `systolic`, `bpReadings`, `aiSummary` |
| Functions | camelCase, verb-first | `saveReading()`, `generateWellnessScore()` |
| Enums | PascalCase type, camelCase cases | `ReadingType.bloodPressure` |
| Booleans | `is`/`has` prefix preferred | `isActive`, `isSaving`, `isFocused` |
| API DTOs | `*Entry`, `*Input`, `*Advice` suffix | `BPEntry`, `HealthInput`, `HealthAdvice` |
| Abbreviations | Freely used in locals | `sys`, `dia`, `w`, `h`, `g`, `p` |
| British spelling | Used in some identifiers | `favourites`, `toggleFavourite()` |

### Formatting

- **No MARK comments** used in the codebase. Do not add them.
- **Multiple types per file** is acceptable (e.g., DTOs alongside service, helper views alongside parent).
- **Minimal inline comments** — short `//` style, no `///` doc comments.
- **Commented-out code** exists and is tolerated.

### SwiftUI Patterns

- **100% SwiftUI** — no UIKit anywhere.
- Uses `NavigationView` (not `NavigationStack`).
- Uses `.cornerRadius()` (not `.clipShape`).
- `TabView` for root navigation in `ContentView`.
- `.sheet()` for modal presentation.
- `.toolbar` with `ToolbarItem` for nav bar buttons.
- `#Preview` macro for previews.
- `@ViewBuilder` used sparingly.

### Property Wrappers

- `@State private var` — always `private`.
- `@Binding var` — for parent-child communication.
- `@Query` — SwiftData queries with sort descriptors.
- `@Environment(\.modelContext) private var modelContext`
- `@Environment(\.dismiss) private var dismiss`
- `@FocusState private var` — keyboard focus in input views.
- `@Bindable var` — SwiftData model editing in edit views.
- `@Observable` — on ViewModels (only one exists).
- `@Model` — on all SwiftData model classes.

### Access Control

- `@State`/`@Environment`/`@FocusState`: always `private`.
- Model properties: always internal (no modifier) — required by SwiftData.
- Helper functions in views: `private func`.
- Singletons: `static let shared` at internal access.
- `public`, `open`, `fileprivate`: never used.

### SwiftData Models

All models follow this rigid template:

```swift
@Model
class [Name]Reading {
    var id: UUID
    var [field]: [Type]
    var date: Date

    init([field]: [Type], date: Date = .now) {
        self.id = UUID()
        self.[field] = [field]
        self.date = date
    }
}
```

- Always `class` (SwiftData requirement). No `final`.
- `var id: UUID` — manually assigned in init.
- `var date: Date` — default `.now`.
- No relationships, no computed properties on models.

### Error Handling

- **`try?` is the dominant pattern** — errors silently swallowed for `modelContext.save()`, `fetch()`, encoding.
- **`guard-else-return`** for input validation and nil checks.
- **`Result<Success, Error>`** in `APIService` completion handlers.
- **`NSError`** for custom errors (e.g., `NSError(domain: "Encoding error", code: 400)`).
- **No custom error enums.** Do not introduce them unless asked.
- User-facing errors displayed via `@State private var errorMessage: String?`.

### Async / Networking

- **Completion handlers are the primary async pattern** — not async/await.
- `URLSession.shared.dataTask` for networking.
- `DispatchQueue.main.async` for UI updates from callbacks.
- `async/await` used only in `EditHeightReadingViewModel` (newest code).
- Combine is not used anywhere.
- Single backend endpoint: `POST https://healthmy-backend.vercel.app/health/summary`.
- DTOs (`BPEntry`, `WeightEntry`, etc.) defined in `APIService.swift` alongside the service.

### Testing

- Unit tests in `HealthMYTests/HealthMYTests.swift` — `APIServiceTests` class.
- Tests cover encoding/decoding of DTOs (`BPEntry`, `WeightEntry`, `HeightEntry`, `HealthAdvice`).
- One integration test (`testSendAllReadings_RealNetworkCall`) hits the live backend.
- UI tests are Xcode-generated boilerplate — no custom logic.
- Test functions use `throws` — no async test methods.

### Key Conventions Summary

1. Logic lives inline in views (not in ViewModels) — maintain this pattern.
2. No protocols defined, no generics (one exception: `ReadingSectionView<Reading, Content>`).
3. Singletons via `static let shared` — `APIService.shared`, `HealthKitManager.shared`.
4. No dependency injection.
5. File headers: either standard Xcode template or omitted — both acceptable.
6. HealthKit access is read-only (configured in entitlements).
7. `Info.plist` has `NSAllowsArbitraryLoads = true` for API connectivity.
