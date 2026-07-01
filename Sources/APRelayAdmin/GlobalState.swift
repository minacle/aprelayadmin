import RetortTUI

#if canImport(Combine)
import Combine
#else
import OpenCombine
#endif

final class GlobalState: ObservableObject {

    enum ViewType {

        case root

        case subscribers

        case pendingSubscribers

        case acceptedSubscribers

        case rejectedSubscribers

        case blockedDomains

        case addBlockedDomain

        case settings
    }

    @Published
    var adminToken: String = ""

    @Published
    var currentView: ViewType = .root

    @Published
    var relayURL: String = ""
}
