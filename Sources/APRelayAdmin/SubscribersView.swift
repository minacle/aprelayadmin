import RetortTUI

struct SubscribersView: View {

    enum FocusedItem: Hashable {

        case pending

        case accepted

        case rejected
    }

    @Environment(GlobalState.self)
    private var globalState

    @FocusState
    private var focusedItem: FocusedItem? = .pending

    // MARK: View

    var body: some View {
        VStack {
            HStack {
                Text("Subscribers")
                Spacer()
            }
            Group {
                VStack {
                    RetortList(selection: $focusedItem) {
                        RetortListItem(id: .pending, role: .navigationLink, title: "Pending") {
                            PendingSubscribersView(globalState: globalState)
                        }
                        RetortListItem(id: .accepted, role: .navigationLink, title: "Accepted") {
                            AcceptedSubscribersView(globalState: globalState)
                        }
                        RetortListItem(id: .rejected, role: .navigationLink, title: "Rejected") {
                            RejectedSubscribersView(globalState: globalState)
                        }
                    }
                }
                Spacer()
            }
            HStack(spacing: 2) {
                keyHint(for: "↑", "↓", description: "move")
                keyHint(for: "↩", description: "select")
                keyHint(for: "⎋", description: "back")
                Spacer()
            }
        }
    }
}

struct PendingSubscribersView: View {

    @Bindable
    var globalState: GlobalState

    // MARK: View

    var body: some View {
        SubscriberListView(
            globalState: globalState,
            state: .pending,
            title: "Pending Subscribers",
            emptyMessage: "No pending subscribers."
        )
    }
}

struct AcceptedSubscribersView: View {

    @Bindable
    var globalState: GlobalState

    // MARK: View

    var body: some View {
        SubscriberListView(
            globalState: globalState,
            state: .accepted,
            title: "Accepted Subscribers",
            emptyMessage: "No accepted subscribers."
        )
    }
}

struct RejectedSubscribersView: View {

    @Bindable
    var globalState: GlobalState

    // MARK: View

    var body: some View {
        SubscriberListView(
            globalState: globalState,
            state: .rejected,
            title: "Rejected Subscribers",
            emptyMessage: "No rejected subscribers."
        )
    }
}

private struct SubscriberListView: View {

    @Bindable
    var globalState: GlobalState

    let state: AdminAPIClient.SubscriberState

    let title: String

    let emptyMessage: String

    // MARK: -

    enum FocusedItem: Hashable {

        case subscriber(Int)
    }

    enum Action: CaseIterable, Hashable {

        case accept

        case reject

        case remove

        var title: String {
            switch self {
            case .accept:
                return "Accept"
            case .reject:
                return "Reject"
            case .remove:
                return "Remove"
            }
        }
    }

    @FocusState
    private var focusedItem: FocusedItem?

    @State
    private var isRefreshing: Bool = false

    @State
    private var subscribers: [AdminAPIClient.Subscriber] = .init()

    @State
    private var errorMessage: String?

    @State
    private var editingItem: FocusedItem?

    @State
    private var editingItemHint: String = ""

    func refresh() {
        isRefreshing = true
        errorMessage = nil
        focusedItem = nil

        do {
            let client = AdminAPIClient(
                relayURL: globalState.relayURL,
                adminToken: globalState.adminToken
            )
            applyRefreshResult(.success(try client.listSubscriberDomains(state: state)))
        } catch {
            applyRefreshResult(.failure(error))
        }
    }

    private func applyRefreshResult(_ result: Result<[AdminAPIClient.Subscriber], any Error>) {
        switch result {
        case .success(let subscribers):
            self.subscribers = subscribers
            focusAfterRefresh()
        case .failure(let error):
            subscribers = []
            errorMessage = String(describing: error)
            focusedItem = nil
        }
        isRefreshing = false
    }

    // MARK: View

    var body: some View {
        VStack {
            HStack {
                Text(title)
                Spacer()
            }
            Group {
                if isRefreshing {
                    message("Refreshing...")
                }
                else if let errorMessage {
                    message(errorMessage)
                }
                else if subscribers.isEmpty {
                    message(emptyMessage)
                }
                else {
                    RetortList(selection: $focusedItem, editing: $editingItem) {
                        for index in subscribers.indices {
                            RetortListItem(id: .subscriber(index), role: .button, title: subscribers[index].domain)
                            .choices(
                                .constant(defaultAction),
                                from: availableActions,
                                name: \.title
                            ) {
                                perform($0, on: subscribers[index].domain)
                            }
                            .subtitle {
                                Text("")
                            }
                        }
                    }
                    .onEditingChange {
                        guard case .choice(_, _, let title) = $0
                        else {
                            editingItemHint = ""
                            return
                        }
                        editingItemHint = title.lowercased()
                    }
                }
                Spacer()
            }
            HStack(spacing: 2) {
                if isRefreshing {
                    keyHint(for: "⎋", description: "back")
                }
                else if errorMessage != nil {
                    keyHint(for: "r", description: "refresh")
                    keyHint(for: "⎋", description: "back")
                }
                else if subscribers.isEmpty {
                    keyHint(for: "r", description: "refresh")
                    keyHint(for: "⎋", description: "back")
                }
                else if editingItem != nil {
                    keyHint(for: "↩", description: editingItemHint)
                    keyHint(for: "⎋", description: "cancel")
                }
                else {
                    keyHint(for: "↑", "↓", description: "move")
                    keyHint(for: "↩", description: "action")
                    keyHint(for: "r", description: "refresh")
                    keyHint(for: "⎋", description: "back")
                }
                Spacer()
            }
        }
        .onGlobalKeyPress(characters: .init(charactersIn: "r")) {
            (_) in
            if editingItem == nil {
                refresh()
                return .handled
            }
            return .ignored
        }
        .onAppear {
            refresh()
        }
    }

    private var availableActions: [Action] {
        switch state {
        case .pending:
            return [.accept, .reject]
        case .accepted, .rejected:
            return [.remove]
        }
    }

    private var defaultAction: Action {
        switch state {
        case .pending:
            return .accept
        case .accepted, .rejected:
            return .remove
        }
    }

    private func perform(_ action: Action, on domain: String) -> RetortListCommitResult {
        do {
            let client = AdminAPIClient(
                relayURL: globalState.relayURL,
                adminToken: globalState.adminToken
            )
            switch action {
            case .accept:
                try client.acceptSubscriber(domain: domain)
            case .reject:
                try client.rejectSubscriber(domain: domain)
            case .remove:
                try client.deleteSubscriber(domain: domain)
            }
            refresh()
            return .accepted
        } catch {
            return .rejected(String(describing: error))
        }
    }

    private func focusAfterRefresh() {
        guard !subscribers.isEmpty else {
            focusedItem = nil
            return
        }

        let index = focusedSubscriberIndex()
        if let index, subscribers.indices.contains(index) {
            return
        }

        focusedItem = .subscriber(subscribers.indices.first!)
    }

    private func focusedSubscriberIndex() -> Int? {
        switch focusedItem {
        case .subscriber(let index):
            return index
        case nil:
            return nil
        }
    }

    private func message(_ text: String) -> some View {
        HStack {
            Text(text)
            Spacer()
        }
        .padding(.leading, 2)
    }
}
