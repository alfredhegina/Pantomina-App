import Foundation

enum AppEnvironment: String, CaseIterable {
    case preprod
    case production

    static var current: AppEnvironment {
        #if PREPROD
        return .preprod
        #else
        return .production
        #endif
    }

    var appDisplayName: String {
        switch self {
        case .preprod: return "Pantomina Beta"
        case .production: return "Pantomina"
        }
    }

    var isAnalyticsEnabled: Bool { true }

    var showDeveloperTools: Bool {
        self == .preprod
    }

    var isProduction: Bool { self == .production }
    var isPreprod: Bool { self == .preprod }
}

enum AppVersion {
    static var marketing: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}

enum PersonId: String, CaseIterable, Sendable {
    case fern
    case stark

    var role: PersonRole {
        switch self {
        case .fern: return .payer
        case .stark: return .contributor
        }
    }

    var colorToken: PersonColor {
        switch self {
        case .fern: return .sage
        case .stark: return .terra
        }
    }
}

enum PersonRole: String, Sendable {
    case payer
    case contributor
}

enum PersonColor: String, Sendable {
    case sage
    case terra
}
