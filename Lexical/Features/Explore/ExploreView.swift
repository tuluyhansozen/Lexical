import SwiftUI
import SwiftData
import LexicalCore

/// ExploreView combines the Morphology Matrix with vocabulary search
/// Per design spec: Matrix centered on last learned word with related words around it
struct ExploreView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VocabularyItem.lastReviewedAt, order: .reverse) private var vocabularyItems: [VocabularyItem]
    @Query private var roots: [MorphologicalRoot]
    
    @StateObject private var graph = ForceDirectedGraph()
    @State private var searchText: String = ""
    @State private var selectedNode: GraphNode?
    @State private var canvasSize: CGSize = .zero
    
    /// Last learned word (most recently reviewed)
    private var lastLearnedWord: VocabularyItem? {
        vocabularyItems.first { $0.lastReviewedAt != nil }
    }
    
    /// Filtered vocabulary for search
    private var filteredVocabulary: [VocabularyItem] {
        guard !searchText.isEmpty else { return [] }
        return vocabularyItems.filter { $0.lemma.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        ZStack {
            Color.adaptiveBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Search Results or Matrix
                if !searchText.isEmpty {
                    searchResultsView
                } else {
                    matrixView
                }
            }
        }
        .onAppear {
            buildGraphFromLastLearned()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Text("Explore")
                .font(.display(size: 28, weight: .bold))
                .foregroundStyle(Color.adaptiveText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Search Bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search vocabulary...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color.adaptiveSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Last learned indicator
            if let lastWord = lastLearnedWord {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(Color.sonPrimary)
                    Text("Last learned: **\(lastWord.lemma)**")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - Search Results
    
    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredVocabulary) { item in
                    SearchResultCard(item: item) {
                        // Center graph on this word
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
    
    // MARK: - Matrix View
    
    private var matrixView: some View {
        GeometryReader { geometry in
            ZStack {
                // Graph Canvas
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
                
                // Node Labels
                ForEach(graph.nodes) { node in
                    let position = graphPosition(for: node, in: geometry.size)
                    
                    Text(node.label)
                        .font(.caption2)
                        .fontWeight(node.isRoot ? .bold : .regular)
                        .foregroundStyle(node.isRoot ? Color.sonPrimary : .secondary)
                        .position(x: position.x, y: position.y + 24)
                }
                
                // Empty state
                if graph.nodes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "network")
                            .font(.system(size: 64))
                            .foregroundStyle(Color.sonPrimary.opacity(0.3))
                        
                        Text("Start learning to build your word matrix")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .onAppear {
                canvasSize = geometry.size
            }
        }
    }
    
    // MARK: - Graph Drawing
    
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
            
            context.stroke(
                path,
                with: .color(Color.gray.opacity(0.3)),
                lineWidth: 1
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
            
            context.fill(
                Path(ellipseIn: rect),
                with: .color(node.color)
            )
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
        // Find nearest node and update position
        let centerX = size.width / 2
        let centerY = size.height / 2
        let scale = min(size.width, size.height) / 3
        
        let normalizedPos = CGPoint(
            x: (location.x - centerX) / scale,
            y: (location.y - centerY) / scale
        )
        
        // Find closest node
        if let closest = graph.nodes.min(by: { nodeA, nodeB in
            let distA = hypot(nodeA.position.x - normalizedPos.x, nodeA.position.y - normalizedPos.y)
            let distB = hypot(nodeB.position.x - normalizedPos.x, nodeB.position.y - normalizedPos.y)
            return distA < distB
        }) {
            if let index = graph.nodes.firstIndex(where: { $0.id == closest.id }) {
                graph.nodes[index].position = normalizedPos
                graph.nodes[index].velocity = .zero
            }
        }
    }
    
    // MARK: - Graph Building
    
    private func buildGraphFromLastLearned() {
        // Build graph centered on last learned word
        var words: [(lemma: String, rootId: String?, color: Color?)] = []
        
        if let lastWord = lastLearnedWord {
            // Add the last learned word first (will be positioned at center)
            let color = colorForState(lastWord.learningState)
            let rootId = EtymologyService.resolveRoot(for: lastWord.lemma) ?? lastWord.root?.root
            words.append((lemma: lastWord.lemma, rootId: rootId, color: color))
            
            // Add related words (same root)
            if let rootId = rootId {
                let relatedWords = vocabularyItems.filter { item in
                    item.persistentModelID != lastWord.persistentModelID &&
                    (EtymologyService.resolveRoot(for: item.lemma) == rootId || item.root?.root == rootId)
                }
                
                for item in relatedWords.prefix(8) {
                    words.append((lemma: item.lemma, rootId: rootId, color: colorForState(item.learningState)))
                }
            }
            
            // Also add some recently reviewed words
            let recentWords = vocabularyItems.prefix(10).filter { item in
                !words.contains(where: { $0.lemma == item.lemma })
            }
            
            for item in recentWords.prefix(5) {
                let root = EtymologyService.resolveRoot(for: item.lemma) ?? item.root?.root
                words.append((lemma: item.lemma, rootId: root, color: colorForState(item.learningState)))
            }
        }
        
        // If empty, use sample data
        if words.isEmpty {
            graph.buildGraph(words: [
                (lemma: "inspect", rootId: "spect", color: .green),
                (lemma: "spectacle", rootId: "spect", color: .yellow),
                (lemma: "perspective", rootId: "spect", color: .blue),
                (lemma: "prospect", rootId: "spect", color: .blue),
                (lemma: "transfer", rootId: "fer", color: .green),
                (lemma: "refer", rootId: "fer", color: .yellow),
                (lemma: "prefer", rootId: "fer", color: .yellow),
                (lemma: "transport", rootId: "port", color: .green),
                (lemma: "import", rootId: "port", color: .blue),
                (lemma: "export", rootId: "port", color: .blue)
            ])
        } else {
            graph.buildGraph(words: words)
        }
        
        graph.runSimulation(iterations: 100)
        
        // Center on first node (last learned word)
        if let firstNode = graph.nodes.first {
            if let index = graph.nodes.firstIndex(where: { $0.id == firstNode.id }) {
                graph.nodes[index].position = .zero // Center position
            }
        }
    }
    
    private func centerGraphOnWord(_ lemma: String) {
        // Rebuild graph centered on this word
        if let item = vocabularyItems.first(where: { $0.lemma == lemma }) {
            // Temporarily set as "last reviewed" for graph building
            var words: [(lemma: String, rootId: String?, color: Color?)] = []
            
            let color = colorForState(item.learningState)
            let rootId = EtymologyService.resolveRoot(for: item.lemma) ?? item.root?.root
            words.append((lemma: item.lemma, rootId: rootId, color: color))
            
            // Add related words
            if let rootId = rootId {
                let related = vocabularyItems.filter { 
                    $0.persistentModelID != item.persistentModelID &&
                    (EtymologyService.resolveRoot(for: $0.lemma) == rootId || $0.root?.root == rootId)
                }
                for relatedItem in related.prefix(8) {
                    words.append((
                        lemma: relatedItem.lemma,
                        rootId: rootId,
                        color: colorForState(relatedItem.learningState)
                    ))
                }
            }
            
            graph.buildGraph(words: words)
            graph.runSimulation(iterations: 100)
            
            // Center the selected word
            if let index = graph.nodes.firstIndex(where: { $0.label == lemma }) {
                graph.nodes[index].position = .zero
            }
        }
    }
    
    private func colorForState(_ state: LearningState) -> Color {
        switch state {
        case .new: return .blue
        case .learning: return .yellow
        case .mastered: return .green
        }
    }
}

// MARK: - Search Result Card

struct SearchResultCard: View {
    let item: VocabularyItem
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // State indicator
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
        switch item.learningState {
        case .new: return .blue
        case .learning: return .yellow
        case .mastered: return .green
        }
    }
}

#Preview {
    ExploreView()
        .modelContainer(for: [VocabularyItem.self, MorphologicalRoot.self])
}
