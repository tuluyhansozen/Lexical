import Foundation
import SwiftUI

/// A node in the force-directed graph
public struct GraphNode: Identifiable, Equatable {
    public let id: String
    public let label: String
    public let isRoot: Bool
    public var position: CGPoint
    public var velocity: CGPoint = .zero
    public var color: Color
    
    public init(id: String, label: String, isRoot: Bool = false, position: CGPoint = .zero, color: Color = .blue) {
        self.id = id
        self.label = label
        self.isRoot = isRoot
        self.position = position
        self.color = color
    }
}

/// An edge connecting two nodes
public struct GraphEdge: Identifiable, Equatable {
    public var id: String { "\(sourceId)-\(targetId)" }
    public let sourceId: String
    public let targetId: String
    
    public init(sourceId: String, targetId: String) {
        self.sourceId = sourceId
        self.targetId = targetId
    }
}

/// Force-directed graph layout engine
/// Uses spring forces for edges and repulsion between all nodes
public class ForceDirectedGraph: ObservableObject {
    
    // MARK: - Configuration
    
    /// Spring constant for edge attraction
    private let springConstant: CGFloat = 0.05
    
    /// Natural length of springs
    private let springLength: CGFloat = 100
    
    /// Repulsion constant between nodes
    private let repulsionConstant: CGFloat = 5000
    
    /// Damping factor for velocity
    private let damping: CGFloat = 0.85
    
    /// Minimum distance to prevent singularities
    private let minDistance: CGFloat = 1
    
    // MARK: - State
    
    @Published public var nodes: [GraphNode] = []
    @Published public var edges: [GraphEdge] = []
    
    /// Whether simulation is running
    @Published public var isSimulating: Bool = false
    
    private var displayLink: CADisplayLink?
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Graph Building
    
    /// Build graph from vocabulary items with morphological relationships
    public func buildGraph(words: [(lemma: String, rootId: String?, color: Color?)]) {
        var nodeDict: [String: GraphNode] = [:]
        var edgeList: [GraphEdge] = []
        
        // Extract unique roots
        let roots = Set(words.compactMap { $0.rootId })
        
        // Create root nodes (centered)
        for (index, rootId) in roots.enumerated() {
            let angle = (CGFloat(index) / CGFloat(roots.count)) * 2 * .pi
            let radius: CGFloat = 50
            let position = CGPoint(
                x: 200 + radius * cos(angle),
                y: 200 + radius * sin(angle)
            )
            nodeDict[rootId] = GraphNode(
                id: rootId,
                label: rootId,
                isRoot: true,
                position: position,
                color: Color.sonPrimary
            )
        }
        
        // Create word nodes
        for (index, word) in words.enumerated() {
            let angle = (CGFloat(index) / CGFloat(words.count)) * 2 * .pi
            let radius: CGFloat = 150
            let position = CGPoint(
                x: 200 + radius * cos(angle) + CGFloat.random(in: -20...20),
                y: 200 + radius * sin(angle) + CGFloat.random(in: -20...20)
            )
            
            nodeDict[word.lemma] = GraphNode(
                id: word.lemma,
                label: word.lemma,
                isRoot: false,
                position: position,
                color: word.color ?? .blue.opacity(0.6)
            )
            
            // Create edge to root if exists
            if let rootId = word.rootId {
                edgeList.append(GraphEdge(sourceId: word.lemma, targetId: rootId))
            }
        }
        
        self.nodes = Array(nodeDict.values)
        self.edges = edgeList
    }
    
    // MARK: - Simulation
    
    /// Run one iteration of the force simulation
    public func simulate() {
        guard nodes.count > 1 else { return }
        
        var forces: [String: CGPoint] = [:]
        
        // Initialize forces to zero
        for node in nodes {
            forces[node.id] = .zero
        }
        
        // Calculate repulsion forces (all pairs)
        for i in 0..<nodes.count {
            for j in (i+1)..<nodes.count {
                let nodeA = nodes[i]
                let nodeB = nodes[j]
                
                var dx = nodeB.position.x - nodeA.position.x
                var dy = nodeB.position.y - nodeA.position.y
                let distance = max(sqrt(dx * dx + dy * dy), minDistance)
                
                // Coulomb's law: F = k / d^2
                let force = repulsionConstant / (distance * distance)
                
                dx /= distance
                dy /= distance
                
                forces[nodeA.id]!.x -= force * dx
                forces[nodeA.id]!.y -= force * dy
                forces[nodeB.id]!.x += force * dx
                forces[nodeB.id]!.y += force * dy
            }
        }
        
        // Calculate spring forces (edges only)
        for edge in edges {
            guard let sourceIndex = nodes.firstIndex(where: { $0.id == edge.sourceId }),
                  let targetIndex = nodes.firstIndex(where: { $0.id == edge.targetId }) else {
                continue
            }
            
            let source = nodes[sourceIndex]
            let target = nodes[targetIndex]
            
            var dx = target.position.x - source.position.x
            var dy = target.position.y - source.position.y
            let distance = max(sqrt(dx * dx + dy * dy), minDistance)
            
            // Hooke's law: F = k * (d - L)
            let displacement = distance - springLength
            let force = springConstant * displacement
            
            dx /= distance
            dy /= distance
            
            forces[source.id]!.x += force * dx
            forces[source.id]!.y += force * dy
            forces[target.id]!.x -= force * dx
            forces[target.id]!.y -= force * dy
        }
        
        // Apply forces to velocities and positions
        for i in 0..<nodes.count {
            let force = forces[nodes[i].id] ?? .zero
            
            // Update velocity
            nodes[i].velocity.x = (nodes[i].velocity.x + force.x) * damping
            nodes[i].velocity.y = (nodes[i].velocity.y + force.y) * damping
            
            // Update position (roots move slower)
            let moveFactor: CGFloat = nodes[i].isRoot ? 0.3 : 1.0
            nodes[i].position.x += nodes[i].velocity.x * moveFactor
            nodes[i].position.y += nodes[i].velocity.y * moveFactor
        }
    }
    
    /// Run multiple simulation iterations
    public func runSimulation(iterations: Int = 50) {
        for _ in 0..<iterations {
            simulate()
        }
    }
    
    /// Start continuous simulation using display link
    public func startSimulation() {
        isSimulating = true
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    /// Stop continuous simulation
    public func stopSimulation() {
        isSimulating = false
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func tick() {
        simulate()
    }
    
    // MARK: - Node Interaction
    
    /// Move a node to a new position (for dragging)
    public func moveNode(id: String, to position: CGPoint) {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            nodes[index].position = position
            nodes[index].velocity = .zero
        }
    }
}
