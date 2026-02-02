import SwiftUI
import SwiftData
import LexicalCore

/// ExploreView combines the Morphology Matrix with vocabulary search
/// Per design spec: Matrix centered on last learned word with related words around it
struct ExploreView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VocabularyItem.lastReviewedAt, order: .reverse) private var vocabularyItems: [VocabularyItem]

    
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
    
    // MARK: - Graph Building
    
    private func buildGraphFromLastLearned() {
        var words: [(lemma: String, rootId: String?, color: Color?)] = []
        
        if let lastWord = lastLearnedWord {
            let color = colorForState(lastWord.learningState)
            // Use lemma itself as the 'group' identifier since concepts cluster around it
            let groupId = lastWord.lemma
            
            words.append((lemma: lastWord.lemma, rootId: groupId, color: color))
            
            // Add collocations
            for relatedItem in lastWord.collocations.prefix(12) {
                words.append((
                    lemma: relatedItem.lemma,
                    rootId: groupId,
                    color: colorForState(relatedItem.learningState)
                ))
            }
            
            // Also add some recently reviewed words
            let recentWords = vocabularyItems.prefix(5).filter { item in
                !words.contains(where: { $0.lemma == item.lemma })
            }
            
            for item in recentWords {
                words.append((lemma: item.lemma, rootId: item.lemma, color: colorForState(item.learningState)))
            }
        }
        
        // If empty or cold start
        if words.isEmpty {
            // Sample mock for empty state
            graph.buildGraph(words: [
                (lemma: "rain", rootId: "rain", color: .blue),
                (lemma: "heavy", rootId: "rain", color: .yellow),
                (lemma: "fall", rootId: "rain", color: .green),
                (lemma: "cloud", rootId: "rain", color: .blue),
                (lemma: "wet", rootId: "rain", color: .yellow)
            ])
        } else {
            graph.buildGraph(words: words)
        }
        
        graph.runSimulation(iterations: 100)
        
        // Center on first node
        if let firstNode = graph.nodes.first,
           let index = graph.nodes.firstIndex(where: { $0.id == firstNode.id }) {
            graph.nodes[index].position = .zero
        }
    }
    
    private func centerGraphOnWord(_ lemma: String) {
        if let item = vocabularyItems.first(where: { $0.lemma == lemma }) {
            var words: [(lemma: String, rootId: String?, color: Color?)] = []
            
            let color = colorForState(item.learningState)
            let groupId = item.lemma
            
            words.append((lemma: item.lemma, rootId: groupId, color: color))
            
            // Add collocations
            for relatedItem in item.collocations.prefix(10) {
                 words.append((
                    lemma: relatedItem.lemma,
                    rootId: groupId,
                    color: colorForState(relatedItem.learningState)
                 ))
            }
            
            graph.buildGraph(words: words)
            graph.runSimulation(iterations: 100)
            
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
        .modelContainer(for: [VocabularyItem.self])
}
