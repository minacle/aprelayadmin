import Observation
import RetortTUI

@Observable
final class GlobalState {

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

    var adminToken: String = ""

    var currentView: ViewType = .root

    var relayURL: String = ""
}
