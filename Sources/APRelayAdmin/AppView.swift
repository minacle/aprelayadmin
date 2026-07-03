import Foundation
import RetortTUI

struct AppView: View {

    @Environment(\.terminate)
    private var terminate

    @Bindable
    private var globalState = GlobalState()

    // MARK: View

    var body: some View {
        NavigationStack {
            RootView(globalState: globalState)
            .onGlobalKeyPress(.escape) {
                terminate()
                return .handled
            }
        }
        .onAppear {
            globalState.adminToken = ProcessInfo.processInfo.environment["ADMIN_TOKEN", default: ""]
            globalState.relayURL = ProcessInfo.processInfo.environment["RELAY_URL", default: ""]
        }
    }
}
