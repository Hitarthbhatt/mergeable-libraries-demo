import ProjectDescription

// MERGE_MODE picks how the frameworks are linked into MyApp:
//   none      -> plain dynamic frameworks (baseline)
//   automatic -> Xcode merges every direct dynamic dependency in Release
//   manual    -> only targets marked MERGEABLE_LIBRARY=YES get merged
let mergeMode = Environment.mergeMode.getString(default: "none")

let bundlePrefix = "com.yourname"
let deploymentTargets: DeploymentTargets = .iOS("16.0")

func appSettings() -> SettingsDictionary {
    switch mergeMode {
    case "automatic": return ["MERGED_BINARY_TYPE": "automatic"]
    case "manual": return ["MERGED_BINARY_TYPE": "manual"]
    default: return [:]
    }
}

func frameworkSettings() -> SettingsDictionary {
    mergeMode == "manual" ? ["MERGEABLE_LIBRARY": "YES"] : [:]
}

func framework(_ name: String, dependencies: [TargetDependency] = []) -> Target {
    .target(
        name: name,
        destinations: .iOS,
        product: .framework,
        bundleId: "\(bundlePrefix).\(name)",
        deploymentTargets: deploymentTargets,
        sources: ["Modules/\(name)/Sources/**"],
        dependencies: dependencies,
        settings: .settings(base: frameworkSettings())
    )
}

let project = Project(
    name: "MyApp",
    targets: [
        .target(
            name: "MyApp",
            destinations: .iOS,
            product: .app,
            bundleId: "\(bundlePrefix).MyApp",
            deploymentTargets: deploymentTargets,
            infoPlist: .extendingDefault(with: ["UILaunchScreen": [:]]),
            sources: ["App/Sources/**"],
            dependencies: [
                .target(name: "SupportFeature"),
                .target(name: "ProfileFeature"),
                .target(name: "CoreKit"),
            ],
            settings: .settings(base: appSettings())
        ),
        framework("CoreKit"),
        framework("SupportFeature", dependencies: [.target(name: "CoreKit")]),
        framework("ProfileFeature", dependencies: [.target(name: "CoreKit")]),
    ]
)
