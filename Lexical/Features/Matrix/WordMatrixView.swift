import SwiftUI
import SwiftData
import LexicalCore

/// Morphology Matrix visualization using force-directed graph
struct WordMatrixView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var vocabularyItems: [VocabularyItem]
    
    @StateObject private var graph = ForceDirectedGraph()
    @State private var selectedNode: GraphNode?
    @State private var draggedNodeId: String?
    
    var body: some View {
        ZStack {
            // Background
            Color.adaptiveBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                header
                
                // Graph Canvas
                graphCanvas
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Selected Node Detail
                if let node = selectedNode {
                    nodeDetailCard(node: node)
                }
            }
        }
        .onAppear {
            buildGraphFromVocabulary()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Word Matrix")
                    .font(.display(size: 28, weight: .bold))
                    .foregroundStyle(Color.adaptiveText)
                
                Text("\(graph.nodes.count) words • \(graph.edges.count) connections")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Simulation toggle
            Button {
                if graph.isSimulating {
                    graph.stopSimulation()
                } else {
                    graph.startSimulation()
                }
            } label: {
                Image(systemName: graph.isSimulating ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title)
                    .foregroundStyle(Color.sonPrimary)
            }
        }
        .padding()
    }
    
    // MARK: - Graph Canvas
    
    private var graphCanvas: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let scale: CGFloat = min(size.width, size.height) / 400
                
                // Draw edges
                for edge in graph.edges {
                    guard let source = graph.nodes.first(where: { $0.id == edge.sourceId }),
                          let target = graph.nodes.first(where: { $0.id == edge.targetId }) else {
                        continue
                    }
                    
                    let sourcePoint = transformPoint(source.position, center: center, scale: scale)
                    let targetPoint = transformPoint(target.position, center: center, scale: scale)
                    
                    var path = Path()
                    path.move(to: sourcePoint)
                    path.addLine(to: targetPoint)
                    
                    context.stroke(
                        path,
                        with: .color(.secondary.opacity(0.3)),
                        lineWidth: 1
                    )
                }
                
                // Draw nodes
                for node in graph.nodes {
                    let point = transformPoint(node.position, center: center, scale: scale)
                    let radius: CGFloat = node.isRoot ? 30 : 20
                    
                    let rect = CGRect(
                        x: point.x - radius,
                        y: point.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    
                    // Node circle
                    let nodeColor = node.isRoot ? Color.sonPrimary : Color.sonPrimary.opacity(0.6)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(nodeColor)
                    )
                    
                    // Node border if selected
                    if selectedNode?.id == node.id {
                        context.stroke(
                            Path(ellipseIn: rect.insetBy(dx: -3, dy: -3)),
                            with: .color(.white),
                            lineWidth: 3
                        )
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDrag(value: value, in: geometry.size)
                    }
                    .onEnded { _ in
                        draggedNodeId = nil
                    }
            )
            .onTapGesture { location in
                handleTap(at: location, in: geometry.size)
            }
        }
    }
    
    // MARK: - Node Detail Card
    
    private func nodeDetailCard(node: GraphNode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(node.label.capitalized)
                    .font(.headline)
                    .foregroundStyle(Color.adaptiveText)
                
                Spacer()
                
                if node.isRoot {
                    Text("ROOT")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.sonPrimary.opacity(0.2))
                        .cornerRadius(8)
                }
                
                Button {
                    selectedNode = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
            
            // Find related words
            let relatedWords = graph.edges
                .filter { $0.sourceId == node.id || $0.targetId == node.id }
                .map { edge in
                    edge.sourceId == node.id ? edge.targetId : edge.sourceId
                }
            
            if !relatedWords.isEmpty {
                Text("Related: \(relatedWords.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.adaptiveSurface)
        .cornerRadius(16)
        .shadow(radius: 5)
        .padding()
    }
    
    // MARK: - Helpers
    
    private func transformPoint(_ point: CGPoint, center: CGPoint, scale: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + (point.x - 200) * scale,
            y: center.y + (point.y - 200) * scale
        )
    }
    
    private func inverseTransformPoint(_ point: CGPoint, center: CGPoint, scale: CGFloat) -> CGPoint {
        CGPoint(
            x: 200 + (point.x - center.x) / scale,
            y: 200 + (point.y - center.y) / scale
        )
    }
    
    private func handleTap(at location: CGPoint, in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let scale: CGFloat = min(size.width, size.height) / 400
        
        for node in graph.nodes {
            let screenPoint = transformPoint(node.position, center: center, scale: scale)
            let radius: CGFloat = node.isRoot ? 30 : 20
            
            let distance = hypot(location.x - screenPoint.x, location.y - screenPoint.y)
            if distance < radius {
                withAnimation(.spring()) {
                    selectedNode = node
                }
                return
            }
        }
        
        // Deselect if tap on empty space
        withAnimation(.spring()) {
            selectedNode = nil
        }
    }
    
    private func handleDrag(value: DragGesture.Value, in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let scale: CGFloat = min(size.width, size.height) / 400
        
        // Find node under drag start if not already dragging
        if draggedNodeId == nil {
            for node in graph.nodes {
                let screenPoint = transformPoint(node.position, center: center, scale: scale)
                let radius: CGFloat = node.isRoot ? 30 : 20
                
                let distance = hypot(value.startLocation.x - screenPoint.x, value.startLocation.y - screenPoint.y)
                if distance < radius {
                    draggedNodeId = node.id
                    break
                }
            }
        }
        
        // Move dragged node
        if let nodeId = draggedNodeId {
            let newPosition = inverseTransformPoint(value.location, center: center, scale: scale)
            graph.moveNode(id: nodeId, to: newPosition)
        }
    }
    
    private func buildGraphFromVocabulary() {
        // Build words list from vocabulary
        let words: [(lemma: String, rootId: String?, color: Color?)] = vocabularyItems.map { item in
            // Dynamic resolution via EtymologyService OR persisted root
            let root = EtymologyService.resolveRoot(for: item.lemma) ?? item.root?.root
            let color = color(for: item.learningState)
            return (lemma: item.lemma, rootId: root, color: color)
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
        
        // Run initial layout
        graph.runSimulation(iterations: 100)
    }
    
    private func color(for state: LearningState) -> Color {
        switch state {
        case .new: return .blue
        case .learning: return .yellow
        case .mastered: return .green
        }
    }
}

#Preview {
    WordMatrixView()
        .modelContainer(for: VocabularyItem.self, inMemory: true)
}
