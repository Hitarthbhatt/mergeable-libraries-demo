# mergeable-libraries-demo

A tiny modular iOS app that shows two things with real numbers:

1. **Why `public` makes your modules fat.** The same code, built once with `public` and once with `internal`.
2. **What Xcode's mergeable libraries do to your app.** The same app, archived as plain dynamic frameworks vs merged.

Companion code for the blog post *My iOS App Got 22% Smaller With One Xcode Setting*

## Prerequisites

- Xcode 15 or newer (mergeable libraries landed in Xcode 15)
- [Tuist](https://tuist.dev) 4.x (`mise install tuist` or `brew install tuist`)
- Python 3 (only to regenerate `CoreKit`)

## Run it

```bash
git clone https://github.com/Hitarthbhatt/mergeable-libraries-demo.git
cd mergeable-libraries-demo

tuist generate                    # creates MyApp.xcworkspace (plain dynamic frameworks)
./scripts/measure.sh              # archives Release in none / automatic / manual merge modes
./scripts/public_vs_internal.sh   # builds CoreKit with public vs internal access
```

No signing is needed. Everything is archived with `CODE_SIGNING_ALLOWED=NO` for a generic iOS device.

To open the project in a specific merge mode:

```bash
TUIST_MERGE_MODE=automatic tuist generate   # MERGED_BINARY_TYPE = automatic on MyApp
TUIST_MERGE_MODE=manual tuist generate      # MERGED_BINARY_TYPE = manual + MERGEABLE_LIBRARY = YES on frameworks
```

## Project structure

```
mergeable-libraries-demo/
├── Project.swift                  # Tuist manifest, reads TUIST_MERGE_MODE
├── App/Sources/MyApp.swift        # SwiftUI app with two tabs
├── Modules/
│   ├── CoreKit/                   # shared code: 360 analytics constants + 40 models (generated)
│   ├── SupportFeature/            # depends on CoreKit
│   └── ProfileFeature/            # depends on CoreKit
└── scripts/
    ├── generate_corekit.py        # regenerates CoreKit with public or internal access
    ├── measure.sh                 # archives + reports sizes per merge mode
    └── public_vs_internal.sh      # the access-level experiment
```

```
MyApp ──► SupportFeature ──► CoreKit
  │   └─► ProfileFeature ──►───┘
  └─────────────────────────► CoreKit
```

## Results (Xcode 27.2, Release, arm64, unsigned)

### `public` vs `internal` (CoreKit alone, same code)

| CoreKit binary            | public  | internal |
|---------------------------|---------|----------|
| Binary on disk            | 316 KB  | 221 KB   |
| `__text` (code)           | 88 KB   | 71 KB    |
| `__const` (all segments)  | 39 KB   | 33 KB    |
| `__LINKEDIT` segment      | 112 KB  | 48 KB    |
| Exported symbols          | 3,518   | 36       |

### Dynamic frameworks vs mergeable libraries (whole app)

| Archived `MyApp.app`      | Dynamic (none) | Merged (automatic) |
|---------------------------|----------------|--------------------|
| `.app` total              | 560 KB         | 436 KB             |
| `MyApp` executable        | 73 KB          | 305 KB             |
| `CoreKit` executable      | 316 KB         | 33 KB (empty shell)|
| `SupportFeature` exec     | 73 KB          | 33 KB (empty shell)|
| `ProfileFeature` exec     | 72 KB          | 33 KB (empty shell)|
| Frameworks dyld loads     | 3              | 0                  |
| Exported symbols          | 3,518 (CoreKit)| 1 (MyApp)          |

Manual mode gives the same result as automatic here, because every framework is a direct dependency of the app.

Your numbers will move a bit with the Xcode version. The shape will not.

## License

MIT
