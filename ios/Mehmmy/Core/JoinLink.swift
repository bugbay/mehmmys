import Foundation

// https://mehmmys.app/join/{code} invite links (universal links)
enum JoinLink {
    static let hosts: Set<String> = ["mehmmys.app", "www.mehmmys.app"]

    static func code(from url: URL) -> String? {
        guard let host = url.host?.lowercased(), hosts.contains(host) else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2, parts[0] == "join" else { return nil }
        let code = parts[1].uppercased()
        guard (4...12).contains(code.count), code.allSatisfy({ $0.isLetter || $0.isNumber }) else { return nil }
        return code
    }
}

extension AppState {
    // remembers the code; RootView offers to join once the user is signed in with a profile
    func handle(url: URL) {
        if let code = JoinLink.code(from: url) { pendingJoinCode = code }
    }
}
