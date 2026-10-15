import Foundation
import Darwin

/// Ensures only a single instance of the app runs, using an advisory file lock.
final class SingleInstance {
    private var fileDescriptor: Int32 = -1

    func acquire() -> Bool {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OmniPilot", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

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
