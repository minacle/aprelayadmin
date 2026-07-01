import RetortTUI

@MainActor
func keyHint(for symbols: String..., description: String) -> some View {
    HStack(spacing: 1) {
        HStack {
            let texts =
                symbols.reduce(into: [AnyView]()) {
                    if !$0.isEmpty {
                        $0.append(.init(Text("/").dim()))
                    }
                    $0.append(.init(Text($1)))
                }
            ForEach(texts.indices) {
                texts[$0]
            }
        }
        Text(description)
        .dim()
    }
}
