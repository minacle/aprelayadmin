import RetortTUI

struct RootView: View {

    @Bindable
    var globalState: GlobalState

    // MARK: -

    enum FocusedItem: Hashable {

        case subscribers

        case blockedDomains

        case settings
    }

    @FocusState
    private var focusedItem: FocusedItem? = .subscribers

    // MARK: View

    var body: some View {
        VStack {
            HStack {
                Text("APRelayAdmin")
                Spacer()
            }
            Group {
                RetortList(selection: $focusedItem) {
                    RetortListItem(id: .subscribers, title: "Subscribers")
                    .onActivate {
                        globalState.currentView = .subscribers
                    }
                    RetortListItem(id: .blockedDomains, title: "Blocked Domains")
                    .onActivate {
                        globalState.currentView = .blockedDomains
                    }
                    RetortListItem(id: .settings, title: "Settings")
                    .onActivate {
                        globalState.currentView = .settings
                    }
                }
                Spacer()
            }
            HStack(spacing: 2) {
                keyHint(for: "↑", "↓", description: "move")
                keyHint(for: "↩", description: "select")
                keyHint(for: "⎋", description: "quit")
                Spacer()
            }
        }
    }
}
