import Foundation
import Darwin

/// Ensures only a single instance of the app runs, using an advisory file lock.
final class SingleInstance {
    private var fileDescriptor: Int32 = -1

    func acquire() -> Bool {
        let fileManager = FileManager.default
        guard let base = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return true
        }

        let folderName = Bundle.main.bundleIdentifier ?? "OmniPilot"
        let directory = base.appendingPathComponent(folderName, isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let lockPath = directory.appendingPathComponent("instance.lock").path
        let descriptor = open(lockPath, O_CREAT | O_RDWR, 0o644)
        guard descriptor >= 0 else { return true }

        if flock(descriptor, LOCK_EX | LOCK_NB) != 0 {
            close(descriptor)
            return false
        }
        fileDescriptor = descriptor
        return true
    }
}
