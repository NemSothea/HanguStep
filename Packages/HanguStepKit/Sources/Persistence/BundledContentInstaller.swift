import Domain
import Foundation

/// Launch step: brings the content store up to the bundled library version and
/// reports what is installed. Runs off the main actor.
public enum BundledContentInstaller {
    public static func installIfNeeded(controller: PersistenceController, bundle: Bundle? = nil) async throws -> ContentInfo {
        let store = CoreDataContentStore(controller: controller)
        // Warm launch: the store already holds this version, so the 4+ MB library
        // is not decoded. The summary is regenerated with the content and checked in CI.
        if let summary = bundle.map(BundledContent.summary(from:)) ?? BundledContent.summary(),
           let installed = try await store.installedContentVersion(),
           installed >= summary.version {
            return summary
        }
        let library = try bundle.map(BundledContent.load(from:)) ?? BundledContent.load()
        _ = try await store.apply(library.package)
        return library.info
    }
}
