import RetortTUI

struct RootView: View {

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
                    RetortListItem(id: .subscribers, role: .navigationLink, title: "Subscribers") {
                        SubscribersView()
                    }
                    RetortListItem(id: .blockedDomains, role: .navigationLink, title: "Blocked Domains") {
                        BlockedDomainsView()
                    }
                    RetortListItem(id: .settings, role: .navigationLink, title: "Settings") {
                        SettingsView()
                    }
                }
                Spacer()
            }
            RetortFlow(horizontalSpacing: 2) {
                keyHint(for: "↑", "↓", description: "move")
                keyHint(for: "↩", description: "select")
                keyHint(for: "⎋", description: "quit")
                Spacer()
            }
        }
    }
}
