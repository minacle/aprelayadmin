import Foundation
import RetortTUI

struct BlockedDomainsView: View {

    @Bindable
    var globalState: GlobalState

    // MARK: -

    enum FocusedItem: Hashable {

        case blockedDomain(Int)
    }

    enum Action: CaseIterable, Hashable {

        case unblock

        var title: String {
            switch self {
            case .unblock:
                return "Unblock"
            }
        }
    }

    @FocusState
    private var focusedItem: FocusedItem?

    @State
    private var isRefreshing: Bool = false

    @State
    private var blockedDomains: [AdminAPIClient.BlockedDomain] = .init()

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
            applyRefreshResult(.success(try client.listBlockedDomains()))
        } catch {
            applyRefreshResult(.failure(error))
        }
    }

    private func applyRefreshResult(_ result: Result<[AdminAPIClient.BlockedDomain], any Error>) {
        switch result {
        case .success(let blockedDomains):
            self.blockedDomains = blockedDomains
            focusAfterRefresh()
        case .failure(let error):
            blockedDomains = []
            errorMessage = String(describing: error)
            focusedItem = nil
        }
        isRefreshing = false
    }

    // MARK: View

    var body: some View {
        VStack {
            HStack {
                Text("Blocked Domains")
                Spacer()
            }
            Group {
                if isRefreshing {
                    message("Refreshing...")
                }
                else if let errorMessage {
                    message(errorMessage)
                }
                else if blockedDomains.isEmpty {
                    message("No blocked domains.")
                }
                else {
                    RetortList(selection: $focusedItem, editing: $editingItem) {
                        for index in blockedDomains.indices {
                            RetortListItem(id: .blockedDomain(index), title: blockedDomains[index].domain)
                            .choices(
                                .constant(.unblock),
                                from: Action.allCases,
                                name: \.title
                            ) {
                                perform($0, on: blockedDomains[index].domain)
                            }
                            .subtitle {
                                Text(blockedDomains[index].reason ?? "")
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
                    keyHint(for: "a", description: "add")
                    keyHint(for: "r", description: "refresh")
                    keyHint(for: "⎋", description: "back")
                }
                else if blockedDomains.isEmpty {
                    keyHint(for: "a", description: "add")
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
                    keyHint(for: "a", description: "add")
                    keyHint(for: "r", description: "refresh")
                    keyHint(for: "⎋", description: "back")
                }
                Spacer()
            }
        }
        .onGlobalKeyPress(characters: .init(charactersIn: "a")) {
            (_) in
            if editingItem == nil {
                globalState.currentView = .addBlockedDomain
                return .handled
            }
            return .ignored
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
        .onGlobalKeyPress(.escape) {
            globalState.currentView = .root
            return .handled
        }
    }

    private func perform(_ action: Action, on domain: String) -> RetortListCommitResult {
        do {
            let client = AdminAPIClient(
                relayURL: globalState.relayURL,
                adminToken: globalState.adminToken
            )
            switch action {
            case .unblock:
                try client.unblockDomain(domain: domain)
            }
            refresh()
            return .accepted
        } catch {
            return .rejected(String(describing: error))
        }
    }

    private func focusAfterRefresh() {
        guard !blockedDomains.isEmpty else {
            focusedItem = nil
            return
        }

        let index = focusedBlockedDomainIndex()
        if let index, blockedDomains.indices.contains(index) {
            return
        }

        focusedItem = .blockedDomain(blockedDomains.indices.first!)
    }

    private func focusedBlockedDomainIndex() -> Int? {
        switch focusedItem {
        case .blockedDomain(let index):
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

struct AddBlockedDomainView: View {

    @Bindable
    var globalState: GlobalState

    // MARK: -

    enum FocusedItem: Hashable {

        case domain

        case reason

        case block
    }

    @FocusState
    private var focusedItem: FocusedItem? = .domain

    @State
    private var editingItem: FocusedItem?

    @State
    private var domain: String = ""

    @State
    private var reason: String = ""

    @State
    private var errorMessage: String?

    // MARK: View

    var body: some View {
        VStack {
            HStack {
                Text("Add Blocked Domain")
                Spacer()
            }
            Group {
                if let errorMessage {
                    message(errorMessage)
                }
                RetortList(selection: $focusedItem, editing: $editingItem) {
                    RetortListItem(id: .domain, title: "Domain")
                    .editor($domain)
                    .leadingAccessory {
                        validityAccessory(isDomainValid)
                    }
                    RetortListItem(id: .reason, title: "Reason")
                    .editor($reason)
                    .leadingAccessory {
                        validityAccessory(isReasonValid)
                    }
                    RetortListItem(id: .block, title: "Block")
                    .onActivate {
                        block()
                    }
                }
                Spacer()
            }
            HStack(spacing: 2) {
                if editingItem == nil {
                    keyHint(for: "↑", "↓", description: "move")
                    keyHint(for: "↩", description: focusedItem != .block ? "edit" : "block")
                    keyHint(for: "⎋", description: "back")
                }
                else {
                    keyHint(for: "↩", description: "done")
                    keyHint(for: "⎋", description: "cancel")
                }
                Spacer()
            }
        }
        .onAppear {
            focusedItem = .domain
            domain = ""
            reason = ""
            errorMessage = nil
        }
        .onGlobalKeyPress(.escape) {
            globalState.currentView = .blockedDomains
            return .handled
        }
    }

    private func block() {
        let trimmedDomain = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDomain.isEmpty else {
            errorMessage = "Domain is required."
            focusedItem = .domain
            return
        }

        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let client = AdminAPIClient(
                relayURL: globalState.relayURL,
                adminToken: globalState.adminToken
            )
            try client.blockDomain(
                domain: trimmedDomain,
                reason: trimmedReason.isEmpty ? nil : trimmedReason
            )
            globalState.currentView = .blockedDomains
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private var isDomainValid: Bool? {
        !domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isReasonValid: Bool? {
        reason.isEmpty ? nil : !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func validityAccessory(_ isValid: Bool?) -> some View {
        let color: Color16 =
            switch isValid {
            case .none:
                .blue
            case .some(false):
                .red
            case .some(true):
                .green
            }
        return
            Text("●")
            .color(color)
    }

    private func message(_ text: String) -> some View {
        HStack {
            Text(text)
            Spacer()
        }
        .padding(.leading, 2)
    }
}
