import RetortTUI

struct SettingsView: View {

    @Bindable
    var globalState: GlobalState

    // MARK: -

    enum FocusedItem: Hashable {

        case adminToken

        case relayURL
    }

    @FocusState
    private var focusedItem: FocusedItem? = .adminToken

    @State
    private var editingItem: FocusedItem?

    // MARK: View

    var body: some View {
        VStack {
            HStack {
                Text("Settings")
                Spacer()
            }
            Group {
                RetortList(selection: $focusedItem, editing: $editingItem) {
                    RetortListItem(id: .adminToken, role: .button, title: "Admin Token")
                    .editor($globalState.adminToken)
                    RetortListItem(id: .relayURL, role: .button, title: "Relay URL")
                    .editor($globalState.relayURL)
                }
                Spacer()
            }
            HStack(spacing: 2) {
                if editingItem == nil {
                    keyHint(for: "↑", "↓", description: "move")
                    keyHint(for: "↩", description: "edit")
                    keyHint(for: "⎋", description: "back")
                }
                else {
                    keyHint(for: "↩", description: "done")
                    keyHint(for: "⎋", description: "cancel")
                }
                Spacer()
            }
        }
    }
}
