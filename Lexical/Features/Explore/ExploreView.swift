import SwiftUI
import SwiftData
import LexicalCore

/// Explore combines deterministic daily morphology matrix with vocabulary search.
struct ExploreView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var roots: [MorphologicalRoot]
    @Query private var lexemes: [LexemeDefinition]
    @Query private var userStates: [UserWordState]

    @StateObject private var graph = ForceDirectedGraph()
    @State private var searchText: String = ""
    @State private var dailyRootLabel: String = "Daily Root"
    @State private var dailyRootMeaning: String = ""

    /// Filtered vocabulary for search.
    private var filteredVocabulary: [SearchResultItem] {
        guard !searchText.isEmpty else { return [] }
        let profile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        let stateByLemma = Dictionary(
            uniqueKeysWithValues: userStates
                .filter { $0.userId == profile.userId }
                .map { ($0.lemma, $0.status) }
        )

        return lexemes
            .filter { $0.lemma.localizedCaseInsensitiveContains(searchText) }
            .sorted { lhs, rhs in lhs.lemma < rhs.lemma }
            .prefix(80)
            .map { lexeme in
                SearchResultItem(
                    lemma: lexeme.lemma,
                    definition: lexeme.basicMeaning,
                    status: stateByLemma[lexeme.lemma] ?? .new
                )
            }
    }

    var body: some View {
        ZStack {
            Color.adaptiveBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView

                if !searchText.isEmpty {
                    searchResultsView
                } else {
                    matrixView
                }
            }
        }
        .onAppear {
            buildDailyMatrix()
        }
    }

    private var headerView: some View {
        VStack(spacing: 12) {
            Text("Explore")
                .font(.display(size: 28, weight: .bold))
                .foregroundStyle(Color.adaptiveText)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search vocabulary...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        buildDailyMatrix()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color.adaptiveSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundStyle(Color.sonPrimary)
                Text("Root: **\(dailyRootLabel)**")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !dailyRootMeaning.isEmpty {
                    Text("(\(dailyRootMeaning))")
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.8))
                }
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredVocabulary) { item in
                    SearchResultCard(item: item) {
                        searchText = ""
                        centerGraphOnWord(item.lemma)
                    }
                }

                if filteredVocabulary.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)

                        Text("No results for \"\(searchText)\"")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
    }

    private var matrixView: some View {
        GeometryReader { geometry in
            ZStack {
                Canvas { context, size in
                    drawEdges(context: context, in: size)
                    drawNodes(context: context, in: size)
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            handleDrag(at: value.location, in: geometry.size)
                        }
                )

                ForEach(graph.nodes) { node in
                    let position = graphPosition(for: node, in: geometry.size)

                    Text(node.label)
                        .font(.caption2)
                        .fontWeight(node.isRoot ? .bold : .regular)
                        .foregroundStyle(node.isRoot ? Color.sonPrimary : .secondary)
                        .position(x: position.x, y: position.y + 24)
                }

                if graph.nodes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "network")
                            .font(.system(size: 64))
                            .foregroundStyle(Color.sonPrimary.opacity(0.3))

                        Text("No morphology data available yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
    }

    private func drawEdges(context: GraphicsContext, in size: CGSize) {
        for edge in graph.edges {
            guard let sourceNode = graph.nodes.first(where: { $0.id == edge.sourceId }),
                  let targetNode = graph.nodes.first(where: { $0.id == edge.targetId }) else {
                continue
            }

            let sourcePos = graphPosition(for: sourceNode, in: size)
            let targetPos = graphPosition(for: targetNode, in: size)

            var path = Path()
            path.move(to: sourcePos)
            path.addLine(to: targetPos)

            let style = StrokeStyle(
                lineWidth: 1,
                lineCap: .round,
                lineJoin: .round,
                dash: edge.isFallback ? [5, 4] : []
            )

            context.stroke(
                path,
                with: .color(edge.isFallback ? Color.gray.opacity(0.22) : Color.gray.opacity(0.38)),
                style: style
            )
        }
    }

    private func drawNodes(context: GraphicsContext, in size: CGSize) {
        for node in graph.nodes {
            let position = graphPosition(for: node, in: size)
            let radius: CGFloat = node.isRoot ? 20 : 14
            let rect = CGRect(
                x: position.x - radius,
                y: position.y - radius,
                width: radius * 2,
                height: radius * 2
            )

            context.fill(Path(ellipseIn: rect), with: .color(node.color))
        }
    }

    private func graphPosition(for node: GraphNode, in size: CGSize) -> CGPoint {
        let centerX = size.width / 2
        let centerY = size.height / 2
        let scale = min(size.width, size.height) / 3

        return CGPoint(
            x: centerX + node.position.x * scale,
            y: centerY + node.position.y * scale
        )
    }

    private func handleDrag(at location: CGPoint, in size: CGSize) {
        let centerX = size.width / 2
        let centerY = size.height / 2
        let scale = min(size.width, size.height) / 3

        let normalizedPos = CGPoint(
            x: (location.x - centerX) / scale,
            y: (location.y - centerY) / scale
        )

        if let closest = graph.nodes.min(by: { nodeA, nodeB in
            let distA = hypot(nodeA.position.x - normalizedPos.x, nodeA.position.y - normalizedPos.y)
            let distB = hypot(nodeB.position.x - normalizedPos.x, nodeB.position.y - normalizedPos.y)
            return distA < distB
        }), let index = graph.nodes.firstIndex(where: { $0.id == closest.id }) {
            graph.nodes[index].position = normalizedPos
            graph.nodes[index].velocity = .zero
        }
    }

    private struct SatelliteSelection {
        let lemma: String
        let color: Color
        let isFallback: Bool
    }

    private func buildDailyMatrix(highlightedLemma: String? = nil) {
        let sortedRoots = roots.sorted { $0.rootId < $1.rootId }
        guard !sortedRoots.isEmpty else {
            graph.nodes = []
            graph.edges = []
            dailyRootLabel = "Daily Root"
            dailyRootMeaning = ""
            return
        }

        let profile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        let ignored = Set(profile.ignoredWords.map { $0.lowercased() })
        let proximalRange = LexicalCalibrationEngine().proximalRange(for: profile.lexicalRank)

        var lexemeBySeedId: [Int: LexemeDefinition] = [:]
        var lexemeByLemma: [String: LexemeDefinition] = [:]
        lexemeBySeedId.reserveCapacity(lexemes.count)
        lexemeByLemma.reserveCapacity(lexemes.count)
        for lexeme in lexemes {
            if let seedId = lexeme.seedId {
                lexemeBySeedId[seedId] = lexeme
            }
            lexemeByLemma[lexeme.lemma] = lexeme
        }

        let dayID = Int(floor(Date().timeIntervalSince1970 / 86_400))
        let rootIndex = ((dayID % sortedRoots.count) + sortedRoots.count) % sortedRoots.count

        let normalizedHighlight = highlightedLemma?.lowercased()
        let selectedRoot: MorphologicalRoot = {
            guard let normalizedHighlight,
                  let highlightLexeme = lexemeByLemma[normalizedHighlight],
                  let seedId = highlightLexeme.seedId else {
                return sortedRoots[rootIndex]
            }
            return sortedRoots.first(where: { $0.wordIds.contains(seedId) }) ?? sortedRoots[rootIndex]
        }()

        dailyRootLabel = selectedRoot.root.uppercased()
        dailyRootMeaning = selectedRoot.basicMeaning

        let activeStates = userStates.filter { $0.userId == profile.userId }
        var statusByLemma: [String: UserWordStatus] = [:]
        statusByLemma.reserveCapacity(activeStates.count)
        for state in activeStates {
            statusByLemma[state.lemma] = state.status
        }

        let centerLemma = normalizedHighlight ?? selectedRoot.root.lowercased()

        let directCandidates = selectedRoot.wordIds
            .compactMap { lexemeBySeedId[$0] }
            .filter { lexeme in
                lexeme.lemma != centerLemma && !ignored.contains(lexeme.lemma)
            }

        func score(_ lexeme: LexemeDefinition) -> (inRange: Bool, distance: Int, lemma: String) {
            let rank = lexeme.rank ?? profile.lexicalRank
            return (
                proximalRange.contains(rank),
                abs(rank - profile.lexicalRank),
                lexeme.lemma
            )
        }

        let sortedDirect = directCandidates.sorted { lhs, rhs in
            let lhsScore = score(lhs)
            let rhsScore = score(rhs)
            if lhsScore.inRange != rhsScore.inRange { return lhsScore.inRange && !rhsScore.inRange }
            if lhsScore.distance != rhsScore.distance { return lhsScore.distance < rhsScore.distance }
            return lhsScore.lemma < rhsScore.lemma
        }

        var selections: [SatelliteSelection] = sortedDirect.prefix(6).map { lexeme in
            SatelliteSelection(
                lemma: lexeme.lemma,
                color: colorFor(status: statusByLemma[lexeme.lemma]),
                isFallback: false
            )
        }

        var selectedSet = Set(selections.map(\.lemma))
        selectedSet.insert(centerLemma)

        if selections.count < 6 {
            let needed = 6 - selections.count
            let fallbackCandidates = lexemes
                .filter { lexeme in
                    !selectedSet.contains(lexeme.lemma) &&
                    !ignored.contains(lexeme.lemma)
                }
                .sorted { lhs, rhs in
                    let lhsScore = score(lhs)
                    let rhsScore = score(rhs)
                    if lhsScore.inRange != rhsScore.inRange { return lhsScore.inRange && !rhsScore.inRange }
                    if lhsScore.distance != rhsScore.distance { return lhsScore.distance < rhsScore.distance }
                    return lhsScore.lemma < rhsScore.lemma
                }
                .prefix(needed)

            for lexeme in fallbackCandidates {
                selections.append(
                    SatelliteSelection(
                        lemma: lexeme.lemma,
                        color: colorFor(status: statusByLemma[lexeme.lemma]),
                        isFallback: true
                    )
                )
            }
        }

        renderGraph(centerLemma: centerLemma, satellites: Array(selections.prefix(6)))
    }

    private func renderGraph(centerLemma: String, satellites: [SatelliteSelection]) {
        let rootID = "root:\(centerLemma)"

        var nodes: [GraphNode] = [
            GraphNode(
                id: rootID,
                label: centerLemma,
                isRoot: true,
                position: .zero,
                color: Color.sonPrimary
            )
        ]

        var edges: [GraphEdge] = []
        let radius: CGFloat = 0.65
        let count = max(1, satellites.count)

        for (index, satellite) in satellites.enumerated() {
            let angle = (CGFloat(index) / CGFloat(count)) * 2 * .pi - (.pi / 2)
            let position = CGPoint(
                x: cos(angle) * radius,
                y: sin(angle) * radius
            )

            let id = "lemma:\(satellite.lemma)"
            nodes.append(
                GraphNode(
                    id: id,
                    label: satellite.lemma,
                    isRoot: false,
                    position: position,
                    color: satellite.color
                )
            )
            edges.append(GraphEdge(sourceId: rootID, targetId: id, isFallback: satellite.isFallback))
        }

        graph.nodes = nodes
        graph.edges = edges
        graph.runSimulation(iterations: 60)

        if let rootIndex = graph.nodes.firstIndex(where: { $0.id == rootID }) {
            graph.nodes[rootIndex].position = .zero
            graph.nodes[rootIndex].velocity = .zero
        }
    }

    private func centerGraphOnWord(_ lemma: String) {
        buildDailyMatrix(highlightedLemma: lemma)
    }

    private func colorFor(status: UserWordStatus?) -> Color {
        guard let status else { return .blue.opacity(0.75) }
        switch status {
        case .new: return .blue
        case .learning: return .yellow
        case .known: return .green
        case .ignored: return .gray
        }
    }
}

struct SearchResultItem: Identifiable {
    let lemma: String
    let definition: String?
    let status: UserWordStatus

    var id: String { lemma }
}

struct SearchResultCard: View {
    let item: SearchResultItem
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Circle()
                    .fill(colorForState)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.lemma)
                        .font(.headline)
                        .foregroundStyle(Color.adaptiveText)

                    if let definition = item.definition {
                        Text(definition)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "network")
                    .foregroundStyle(Color.sonPrimary)
            }
            .padding(16)
            .background(Color.adaptiveSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var colorForState: Color {
        switch item.status {
        case .new: return .blue
        case .learning: return .yellow
        case .known: return .green
        case .ignored: return .gray
        }
    }
}

#Preview {
    ExploreView()
        .modelContainer(
            for: [
                MorphologicalRoot.self,
                LexemeDefinition.self,
                UserWordState.self,
                UserProfile.self
            ]
        )
}
