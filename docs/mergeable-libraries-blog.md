We didn't write a single new line of code. We just **moved** some of it into frameworks, like every modularization guide tells you to.

Then we archived the release build, and the app had gotten **bigger**.

<p align="center"><img src="https://media.giphy.com/media/WRQBXSCnEFJIuxktnw/giphy.gif" alt="Confused math lady" width="420" /></p>

This happened on a team I worked with, and it took us a week to crack. Here's the case file. I rebuilt the crime scene as a demo app, so every number below is real and reproducible.

> 🗂️ **CASE FILE: The App That Gained Weight**
>
> - **Victim:** `MyApp`, freshly modularized
> - **Symptom:** got bigger after we only *moved* code
> - **Suspects:** ~~Xcode~~ · ~~the CI cache~~ · ~~Mercury in retrograde~~ · `public`
> - **Fix:** one build setting, **22% smaller**, **0** frameworks loaded at launch

---

## 🔍 Exhibit A: 3 KB of Code in a 73 KB Box

![MyApp depends on SupportFeature, ProfileFeature and CoreKit. Both features depend on CoreKit. Every box is a separate dynamic framework.](https://raw.githubusercontent.com/Hitarthbhatt/mergeable-libraries-demo/main/docs/images/module-graph-v2.png align="center")

All three modules are plain dynamic frameworks, which is what Xcode gives you by default. Now look at `SupportFeature`: **about 3 KB of code shipped as a 73 KB binary.**

That's a USB cable shipped in a microwave box.

Every dynamic framework is split into four segments, and on arm64 each segment is padded to a 16 KB page, even when it's nearly empty. So each framework pays about **64 KB of packaging** before it holds any code. On top of that, `dyld` has to find, map, and bind every framework separately each time the app launches.

Using CocoaPods with `use_frameworks!`, or dynamic SPM products? Then every dependency is one more passport check at airport security on every cold launch. That's why "I added a few pods and my launch got slower" is such a popular Stack Overflow question.

<p align="center"><img src="https://media.giphy.com/media/QMHoU66sBXqqLqYvGO/giphy.gif" alt="This is fine" width="420" /></p>

Padding explains the tiny frameworks. It doesn't explain why `CoreKit` is 316 KB when it holds only 88 KB of code.

---

## 🧤 Exhibit B: The Fingerprints

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

<p align="center"><img src="https://media.giphy.com/media/qiFb2m5kSfyQrcXfFj/giphy.gif" alt="Scooby-Doo unmasking" width="420" /></p>

Here's the interrogation transcript:

> 🧑‍💻 **Me:** Nobody even calls `appOpen`. Why didn't you strip it?
>
> 🔗 **Linker:** It's `public`. Someone outside the framework *might* call it.
>
> 🧑‍💻 **Me:** Who?
>
> 🔗 **Linker:** …someone. I also kept its type metadata and added it to the export table. You're welcome.

Every `public` symbol costs you in three places:

- **Code the linker can't dead-strip** (`__TEXT`)
- **Type metadata** (`__const`)
- **An entry in the export table** (`__LINKEDIT`), which is the framework's phone book

To prove it, I built the same `CoreKit` (360 constants and 40 models) twice. The only change was the access level:

| CoreKit | public | internal |
|:---|---:|---:|
| Binary | 316 KB | **221 KB** |
| `__LINKEDIT` (phone book) | 112 KB | **48 KB** |
| Exported symbols | 3,518 | **36** |

Same code, **30% smaller**. The phone book was bigger than the town.

---

## 🪤 Exhibit C: The False Leads

We spent a week refactoring our way out of it:

```swift
public struct EventName { ... }                      // a struct
public enum EventName { ... }                        // no, an enum
public enum EventName: String { ... }                // enum cases!
public enum Constants { public enum Event { ... } }  // nest it
public enum ConstantsEventName { ... }               // flatten it
```

The size report after each one:

<p align="center"><img src="https://media.giphy.com/media/pV0lVLeA0JXjBiO5Cp/giphy.gif" alt="They're the same picture" width="320" /></p>

The shape of the type doesn't matter. The code is still `public`, and the framework is still paying its packaging tax. The real fix is fewer `public` declarations, but that's a quarter of cleanup work. We wanted a quicker win, so we asked a different question:

**What if the frameworks didn't have to stay separate in the build we ship?**

---

## 💡 The Breakthrough: Why Not Both?

Dynamic frameworks build fast but launch slow. Static libraries launch fast but build slow. Xcode 15's **mergeable libraries** looked at that trade-off and said:

<p align="center"><img src="https://media.giphy.com/media/3o85xIO33l7RlmLR4I/giphy.gif" alt="Why not both" width="360" /></p>

Here's the whole idea in one picture:

![Debug keeps each framework as a separate re-exported dylib. Release merges all of them into the MyApp executable, so dyld loads none of them at launch.](https://raw.githubusercontent.com/Hitarthbhatt/mergeable-libraries-demo/main/docs/images/debug-vs-release-v2.png align="center")

- 🛠️ **Debug:** nothing changes. The app re-exports each framework, so incremental builds stay fast.
- 🚀 **Release:** the linker merges every framework into the app binary and de-duplicates strings, selectors, and stubs along the way. The framework folders stay in the bundle for resources, but their binaries become empty shells.

---

## 🔧 The Fix: One Setting

Select your **app target** → **Build Settings** → search for **Create Merged Binary** → set it to **Automatic**.

```text
MERGED_BINARY_TYPE = automatic
```

That's it. No code changes, no new tools. `automatic` merges every direct framework dependency built in your project.

> ⚠️ **One gotcha:** only *direct* dependencies get merged. If `CoreKit` reaches your app only through `SupportFeature`, link it to the app target explicitly.

> 🎛️ **Want precise control?** Set `MERGED_BINARY_TYPE = manual` on the app and `MERGEABLE_LIBRARY = YES` on each framework you want merged.

---

## ⚖️ The Verdict

| MyApp.app (Release) | Before | After |
|:---|---:|---:|
| **Total size** | 560 KB | **436 KB (−22%)** |
| App executable | 73 KB | 305 KB |
| `CoreKit` executable | 316 KB | 33 KB |
| Frameworks `dyld` loads | 3 | **0** |
| Exported symbols | 3,518 | **1** |

The app executable grew because all the code moved into it. The framework binaries left behind are empty shells.

That took one build setting and zero code changes. The demo has three tiny frameworks. Real apps have dozens.

---

## 📜 The Fine Print

<p align="center"><img src="https://media.giphy.com/media/RN6OnheJ9ZEm4/giphy.gif" alt="With great power comes great responsibility" width="460" /></p>

- **Debug ≠ Release.** Merging happens only in Release builds, so test the build you actually ship.
- **Archives take longer.** Merging is extra linker work, so measure the impact on big apps.
- **Manual mode is easy to forget.** Put `MERGEABLE_LIBRARY = YES` in a shared `.xcconfig`.
- **Edge cases:**
  - `Bundle(for:)` on merged frameworks needs iOS 12 or later.
  - `dlopen` paths need to point at the merged binary.
  - Crash reports list the app as the image.

> ✅ **Worth it if** you have more than a handful of first-party frameworks and someone watches app size or launch time.
> ❌ **Skip it if** you have one or two frameworks, or you ship binary SDKs.

---

## ✅ Case Closed

Your homework:

1. Run `nm -gU YourFramework | wc -l`, and brace yourself.
2. Change one thing that doesn't need to be `public` back to `internal`.
3. Set `MERGED_BINARY_TYPE = automatic` on a branch and compare the archives.

👉 **[Grab the demo repo on GitHub](https://github.com/Hitarthbhatt/mergeable-libraries-demo)**: the measuring scripts behind every number in this post.

📺 **Linker deep dive:** [Meet mergeable libraries (WWDC23)](https://developer.apple.com/videos/play/wwdc2023/10268/)

I blamed Xcode, the CI cache, and the planets before I found the six-letter keyword I'd been typing on autopilot for years. Now I run `nm` before I blame anything.

<p align="center"><img src="https://media.giphy.com/media/l0K42u9hCg0x6XbLa/giphy.gif" alt="Mic drop" width="420" /></p>

*Send this to the teammate who just created their fifth framework this sprint.*
