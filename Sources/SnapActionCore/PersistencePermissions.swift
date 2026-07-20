import Foundation

enum PersistencePermissions {
    static func restrictDirectory(_ url: URL) throws {
        let resolvedURL = url.standardizedFileURL.resolvingSymlinksInPath()
        let temporaryRoot = FileManager.default.temporaryDirectory
            .standardizedFileURL
            .resolvingSymlinksInPath()
        guard resolvedURL != temporaryRoot else {
            return
        }
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: url.path
        )
    }

    static func restrictFile(_ url: URL) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }
}
