We didn't write a single new line of code. We just **moved** some of it into frameworks, like every modularization guide tells you to.

Then we archived the release build, and the app had gotten **bigger**.

![Confused math lady](https://media.giphy.com/media/WRQBXSCnEFJIuxktnw/giphy.gif)

This happened on a team I worked with, and it took us a week to crack. Here's the case file. I rebuilt the crime scene as a demo app, so every number below is real and reproducible.

> 🗂️ **CASE FILE: The App That Gained Weight**
>
> - **Victim:** `MyApp`, freshly modularized
> - **Symptom:** got bigger after we only *moved* code
> - **Suspects:** ~~Xcode~~ · ~~the CI cache~~ · ~~Mercury in retrograde~~ · `public`
> - **Fix:** two build settings, **22% smaller**

---

## Exhibit A: 3 KB of Code in a 73 KB Box

The crime scene:

![MyApp depends on SupportFeature, ProfileFeature and CoreKit; both features depend on CoreKit](https://raw.githubusercontent.com/Hitarthbhatt/mergeable-libraries-demo/main/docs/images/module-graph.png)

All three modules are plain dynamic frameworks, which is what Xcode gives you by default. Here's what they weighed in the Release archive:

| Framework | Code inside | Size on disk |
|---|---|---|
| `SupportFeature` | ~3 KB | **73 KB** |
| `CoreKit` | 88 KB | **316 KB** |

That's a USB cable shipped in a microwave box.

Every dynamic framework is split into four segments, and on arm64 each segment is padded to a 16 KB page, even if it's nearly empty. So each framework pays about **64 KB of packaging** before it holds any code. On top of that, `dyld` has to find, map, and bind every framework separately each time the app launches.

![This is fine](https://media.giphy.com/media/QMHoU66sBXqqLqYvGO/giphy.gif)

Padding explains the tiny frameworks. It doesn't explain why `CoreKit` is 316 KB when it holds only 88 KB of code.

---

## Exhibit B: The Fingerprints

When you move code out of the app target, the compiler greets you with this error, about four hundred times:

```text
'EventName' is inaccessible due to 'internal' protection level
```

So you do what everyone does:

```swift
public struct EventName {
    public static let appOpen = "App Open"
}
```

![Scooby-Doo unmasking](https://media.giphy.com/media/qiFb2m5kSfyQrcXfFj/giphy.gif)

Here's the interrogation transcript:

> **Me:** Nobody even calls `appOpen`. Why didn't you strip it?
>
> **Linker:** It's `public`. Someone outside the framework *might* call it.
>
> **Me:** Who?
>
> **Linker:** …someone. I also kept its type metadata and added it to the export table. You're welcome.

Every `public` symbol costs you in three places:

- **Code the linker can't dead-strip** (`__TEXT`)
- **Type metadata** (`__const`)
- **An entry in the export table** (`__LINKEDIT`), which is the framework's phone book

To prove it, I built the same `CoreKit` (360 constants and 40 models) twice. The only change was the access level:

| `CoreKit` | `public` | `internal` |
|---|---|---|
| Binary | 316 KB | **221 KB** |
| `__LINKEDIT` (phone book) | 112 KB | **48 KB** |
| Exported symbols | 3,518 | **36** |

Same code, **30% smaller**. The phone book was bigger than the town.

---

## Exhibit C: The False Leads

We spent a week refactoring our way out of it:

```swift
public struct EventName { ... }                      // a struct
public enum EventName { ... }                        // no, an enum
public enum EventName: String { ... }                // enum cases!
public enum Constants { public enum Event { ... } }  // nest it
public enum ConstantsEventName { ... }               // flatten it
```

The size report after each one:

![They're the same picture](https://media.giphy.com/media/pV0lVLeA0JXjBiO5Cp/giphy.gif)

The shape of the type doesn't matter. The code is still `public`, and the framework is still paying its packaging tax. The real fix is fewer `public` declarations, but that's a quarter of cleanup work. We wanted a quicker win, so we asked a different question:

**What if the frameworks didn't have to stay separate in the build we ship?**

---

## The Breakthrough: Why Not Both?

Dynamic frameworks build fast and launch slow. Static libraries launch fast and build slow. Xcode 15's **mergeable libraries** looked at that trade-off and said:

![Why not both](https://media.giphy.com/media/3o85xIO33l7RlmLR4I/giphy.gif)

![Debug keeps frameworks dynamic and re-exported; Release merges them into the app binary](https://raw.githubusercontent.com/Hitarthbhatt/mergeable-libraries-demo/main/docs/images/debug-vs-release.png)

**Debug** works the same as before. The app re-exports each framework, so incremental builds stay fast.

**Release** is where the merging happens. The linker merges every framework into the app binary and de-duplicates strings, selectors, and stubs along the way. The framework folders stay in the bundle for resources, but their binaries become empty shells.

---

## The Fix: Two Settings

```text
// App target: the easy way
MERGED_BINARY_TYPE = automatic

// Or, for precise control
MERGED_BINARY_TYPE = manual    // on the app target
MERGEABLE_LIBRARY = YES        // on each framework to merge
```

`automatic` merges every direct framework dependency built in your project. There's one gotcha: **only direct dependencies get merged.** If `CoreKit` reaches the app only through `SupportFeature`, link it to the app target explicitly.

---

## The Verdict

| `MyApp.app` (Release) | Before | After |
|---|---|---|
| **Total size** | **560 KB** | **436 KB (−22%)** |
| App executable | 73 KB | 305 KB (the code moved in) |
| `CoreKit` executable | 316 KB | 33 KB (empty shell) |
| Frameworks `dyld` loads | 3 | **0** |
| Exported symbols | 3,518 | **1** |

That took two build settings and zero code changes. The demo has three tiny frameworks. Real apps have dozens.

---

## The Fine Print

![With great power comes great responsibility](https://media.giphy.com/media/RN6OnheJ9ZEm4/giphy.gif)

- **Debug ≠ Release.** Merging happens only in Release builds, so test the build you actually ship.
- **Archives take longer.** Merging is extra linker work, so measure the impact on big apps.
- **Manual mode is easy to forget.** Put `MERGEABLE_LIBRARY = YES` in a shared `.xcconfig`.
- **Edge cases:**
  - `Bundle(for:)` on merged frameworks needs iOS 12 or later.
  - `dlopen` paths need to point at the merged binary.
  - Crash reports list the app as the image.

**Worth it if** you have more than a handful of first-party frameworks and someone watches app size or launch time. **Skip it if** you have one or two frameworks, or you ship binary SDKs.

---

## Case Closed

Your homework:

1. Run `nm -gU YourFramework | wc -l`, and brace yourself.
2. Change one thing that doesn't need to be `public` back to `internal`.
3. Set `MERGED_BINARY_TYPE = automatic` on a branch and compare the archives.

The full demo with the measuring scripts is at **[github.com/Hitarthbhatt/mergeable-libraries-demo](https://github.com/Hitarthbhatt/mergeable-libraries-demo)**. For the linker deep dive, watch [Meet mergeable libraries (WWDC23)](https://developer.apple.com/videos/play/wwdc2023/10268/).

I blamed Xcode, the CI cache, and the planets before I found the six-letter keyword I'd been typing on autopilot for years. Now I run `nm` before I blame anything.

![Mic drop](https://media.giphy.com/media/l0K42u9hCg0x6XbLa/giphy.gif)

*Send this to the teammate who just created their fifth framework this sprint.*
