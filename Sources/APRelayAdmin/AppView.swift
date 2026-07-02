import Foundation
import RetortTUI

struct AppView: View {

    @Environment(\.terminate)
    private var terminate

    @Bindable
    private var globalState = GlobalState()

    // MARK: View

    var body: some View {
        Group {
            switch globalState.currentView {
            case .root:
                RootView(globalState: globalState)
            case .subscribers:
                SubscribersView(globalState: globalState)
            case .pendingSubscribers:
                PendingSubscribersView(globalState: globalState)
            case .acceptedSubscribers:
                AcceptedSubscribersView(globalState: globalState)
            case .rejectedSubscribers:
                RejectedSubscribersView(globalState: globalState)
            case .blockedDomains:
                BlockedDomainsView(globalState: globalState)
            case .addBlockedDomain:
                AddBlockedDomainView(globalState: globalState)
            case .settings:
                SettingsView(globalState: globalState)
            }
        }
        .onAppear {
            globalState.adminToken = ProcessInfo.processInfo.environment["ADMIN_TOKEN", default: ""]
            globalState.relayURL = ProcessInfo.processInfo.environment["RELAY_URL", default: ""]
        }
        .onGlobalKeyPress(.escape) {
            terminate()
            return .handled
        }
    }
}
