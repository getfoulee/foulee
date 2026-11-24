import ProjectDescription

// The frameworks every app and extension links (issue #725): one module,
// compiled once per platform, instead of the same files listed in each target.
// Out of `Project.swift` so the manifest stays under SwiftLint's file length as
// the modules multiply.

/// A shared framework for the iPhone and the watch, and the Mac when its tests
/// run there.
///
/// - Parameter name: the module, whose sources are `<name>/Sources/**`.
/// - Parameter bundleSuffix: appended to `bundleIdBase`. The watch's copy takes
///   `<suffix>.watch`: the iPhone app embeds the framework, and so does the
///   watch app it carries, and App Store Connect rejects two bundles with one
///   identifier under one iOS app (ITMS-90685).
public func sharedFramework(
    name: String,
    bundleSuffix: String,
    onMac: Bool = false,
    resources: ResourceFileElements? = nil,
    dependencies: [TargetDependency] = [],
    settings extra: SettingsDictionary = [:]
) -> Target {
    let base: SettingsDictionary = [
        // Linked by the widgets and the Live Activity.
        "APPLICATION_EXTENSION_API_ONLY": "YES",
        "PRODUCT_BUNDLE_IDENTIFIER[sdk=watchos*]": "\(bundleIdBase).\(bundleSuffix).watch",
        "PRODUCT_BUNDLE_IDENTIFIER[sdk=watchsimulator*]": "\(bundleIdBase).\(bundleSuffix).watch",
        // Signed when the apps embed it (Code Sign On Copy), with their
        // identity. Signing it on its own needs a development certificate in
        // the keychain, which a framework cannot get from cloud signing: the
        // release archive failed on it.
        "CODE_SIGNING_ALLOWED[sdk=iphoneos*]": "NO",
        "CODE_SIGNING_ALLOWED[sdk=watchos*]": "NO"
    ]
    return .target(
        name: name,
        destinations: onMac ? [.iPhone, .appleWatch, .mac] : [.iPhone, .appleWatch],
        product: .framework,
        bundleId: "\(bundleIdBase).\(bundleSuffix)",
        deploymentTargets: onMac
            ? .multiplatform(iOS: "26.0", macOS: "15.0", watchOS: "26.0")
            : .multiplatform(iOS: "26.0", watchOS: "26.0"),
        sources: ["\(name)/Sources/**"],
        resources: resources,
        dependencies: dependencies,
        settings: .settings(base: base.merging(extra) { $1 })
    )
}
