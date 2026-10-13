import Foundation
import XUtils
import Dependencies

public struct Packer: Sendable {
    public let buildSettings: BuildSettings
    public let plan: Plan

    @Dependency(\.productBuilder) private var productBuilder

    public init(buildSettings: BuildSettings, plan: Plan) {
        self.plan = plan
        self.buildSettings = buildSettings
    }

    public func pack() async throws -> URL {
        let artifacts = try await productBuilder.build(buildSettings, plan)
        return try await assemble(artifacts: artifacts)
    }

    /// Assembly consumes completed build artifacts and never compiles or signs.
    public func assemble(artifacts: BuildArtifacts) async throws -> URL {
        try ResourceDestination.validateRelativePath(plan.app.product)
        guard !plan.app.product.contains("/") else { throw StringError("Application name must not contain path separators") }
        let output = try TemporaryDirectory(name: "\(plan.app.product).app")
        let root = URL(fileURLWithPath: buildSettings.packagePath, isDirectory: true).standardizedFileURL
        let assembler = BundleAssembler(plan: plan, sourceDirectory: root)
        try assembler.assemble(artifacts: artifacts, at: output.url)
        let directory = root.appendingPathComponent("xtool", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(output.url.lastPathComponent)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try output.persist(at: destination)
        return destination
    }

    static func cfBundleSupportedPlatforms(for triple: String) -> [String] {
        let components = triple.split(separator: "-").map(String.init)
        guard let appleIndex = components.firstIndex(of: "apple"),
              components.indices.contains(appleIndex + 1) else {
            return ["iPhoneOS"]
        }

        let os = components[appleIndex + 1].prefix { !$0.isNumber }
        switch os {
        case "ios" where components.contains("simulator"):
            return ["iPhoneSimulator"]
        case "ios":
            return ["iPhoneOS"]
        case "macos", "macosx":
            return ["MacOSX"]
        default:
            return ["iPhoneOS"]
        }
    }
}
