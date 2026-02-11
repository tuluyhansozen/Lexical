import SwiftUI
import SwiftData
import LexicalCore

/// Explore renders a fixed-topology daily matrix aligned to the iPhone 16-3 Figma composition.
struct ExploreView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @Query private var roots: [MorphologicalRoot]
    @Query private var lexemes: [LexemeDefinition]
    @Query private var userStates: [UserWordState]

    @State private var nodes: [ExploreMatrixNode] = []
    @State private var selectedNodeID: String?
    @State private var rootMeaning: String = ""
    @State private var nodeStatusByID: [String: UserWordStatus] = [:]
    @State private var infoData: WordDetailData?
    @State private var actionMessage: ExploreActionMessage?

    private let dailyRootResolver = DailyRootResolver()
    private let figmaReference = FigmaReferenceMatrix()
    private let triageService = NotificationTriageService()

    private var profile: UserProfile {
        UserProfile.resolveActiveProfile(modelContext: modelContext)
    }

    var body: some View {
        ZStack {
            Color(hex: "F5F5F7").ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                matrixView
            }
        }
        .safeAreaPadding(.bottom, 92)
        .onAppear(perform: buildMatrix)
        .onChange(of: roots.count) { buildMatrix() }
        .onChange(of: lexemes.count) { buildMatrix() }
        .onChange(of: userStates.count) { buildMatrix() }
        .sheet(item: $infoData) { detail in
            WordDetailSheet(
                data: detail,
                onAddToDeck: {
                    addToDeck(lemma: detail.lemma, definition: detail.definition)
                }
            )
            .presentationDetents([.medium, .large])
        }
        .alert(item: $actionMessage) { message in
            Alert(title: Text(message.title), message: Text(message.body), dismissButton: .default(Text("OK")))
        }
    }

    private var headerView: some View {
        HStack(spacing: 0) {
            Text("Word Matrix")
                .font(.system(size: titleFontSize, weight: .bold))
                .kerning(0.3955 * headerScale)
                .foregroundStyle(Color(hex: "0A0A0A"))
                .minimumScaleFactor(0.8)
                .lineLimit(1)
                .frame(width: 236 * headerScale, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
        }
        .frame(height: 67 * headerScale)
        .padding(.horizontal, 18 * headerScale)
    }

    private var matrixView: some View {
        GeometryReader { geometry in
            let figmaScale = matrixScale(for: geometry.size)
            ZStack {
                edgeLayer(in: geometry.size)

                ForEach(nodes) { node in
                    nodeButton(for: node, figmaScale: figmaScale, size: geometry.size)
                }
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 8)
        }
    }

    private func nodeButton(for node: ExploreMatrixNode, figmaScale: CGFloat, size: CGSize) -> some View {
        LiquidGlassButton(
            style: node.role == .root ? .root : .leaf,
            action: {
                let card = reviewCard(for: node)
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    selectedNodeID = node.id
                }
                infoData = WordDetailDataBuilder.build(for: card, modelContext: modelContext)
            }
        ) {
            if node.role == .root {
                Text(node.label)
                    .font(.system(size: 18 * figmaScale, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(hex: "0A0A0A"))
            } else {
                VStack(spacing: 2) {
                    Text(node.label.capitalized)
                        .font(.system(size: 9 * figmaScale, weight: .regular))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.62)
                        .padding(.horizontal, 4)
                }
                .overlay(
                    Group {
                        if let status = nodeStatusByID[node.id], status.isLearned {
                            Circle()
                                .stroke(Color.green.opacity(0.6), lineWidth: 2)
                                .frame(width: node.diameter * figmaScale + 6, height: node.diameter * figmaScale + 6)
                        }
                    }
                )
            }
        }
        .frame(width: node.diameter * figmaScale, height: node.diameter * figmaScale)
        .scaleEffect(selectedNodeID == node.id ? 1.04 : 1)
        .position(position(for: node, in: size))
        .accessibilityLabel(node.label)
        .accessibilityHint(node.role == .root ? (rootMeaning) : "Double tap for details")
    }


    private func edgeLayer(in size: CGSize) -> some View {
        Canvas { context, _ in
            guard let root = nodes.first(where: { $0.role == .root }) else { return }
            let rootPos = position(for: root, in: size)

            for leaf in nodes where leaf.role == .leaf {
                let leafPos = position(for: leaf, in: size)
                var path = Path()
                path.move(to: rootPos)
                path.addLine(to: leafPos)

                let gradient = Gradient(colors: [
                    Color(hex: "C9A8A8").opacity(0.42),
                    Color(hex: "A8B5AA").opacity(0.32)
                ])
                context.stroke(
                    path,
                    with: .linearGradient(
                        gradient,
                        startPoint: rootPos,
                        endPoint: leafPos
                    ),
                    style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }

    private func position(for node: ExploreMatrixNode, in size: CGSize) -> CGPoint {
        let horizontalInset: CGFloat = 10
        let topInset: CGFloat = 6
        let bottomInset: CGFloat = 22
        let width = max(1, size.width - (horizontalInset * 2))
        let height = max(1, size.height - topInset - bottomInset)

        return CGPoint(
            x: horizontalInset + (node.position.x * width),
            y: topInset + (node.position.y * height)
        )
    }

    private var titleFontSize: CGFloat {
#if canImport(UIKit)
        let scale = UIScreen.main.bounds.width / 272.0
        return (25 * scale).clamped(to: 30...39)
#else
        return 25
#endif
    }

    private var headerScale: CGFloat {
#if canImport(UIKit)
        let scale = UIScreen.main.bounds.width / 272.0
        return scale.clamped(to: 1.05...1.55)
#else
        return 1
#endif
    }

    private func matrixScale(for size: CGSize) -> CGFloat {
        let scale = size.width / 272.0
        return scale.clamped(to: 1.0...1.55)
    }

    private func buildMatrix() {
        guard let resolution = dailyRootResolver.resolve(
            roots: roots,
            lexemes: lexemes,
            userStates: userStates,
            profile: profile,
            highlightedLemma: nil
        ) else {
            renderFallbackMatrix()
            return
        }

        let rootID = "root:\(resolution.centerLemma.lowercased())"
        var matrixNodes: [ExploreMatrixNode] = [
            ExploreMatrixNode(
                id: rootID,
                label: resolution.centerLemma.lowercased(),
                role: .root,
                position: figmaReference.rootPosition,
                diameter: figmaReference.rootDiameter
            )
        ]

        var statusMap: [String: UserWordStatus] = [:]
        let satellites = Array(resolution.satellites.prefix(figmaReference.leaves.count))

        for (index, slot) in figmaReference.leaves.enumerated() {
            let satellite = satellites[safe: index]
            let title = satellite.map { displayLabel($0.lemma) } ?? slot.label
            let nodeID = "leaf:\(title.lowercased()):\(index)"

            matrixNodes.append(
                ExploreMatrixNode(
                    id: nodeID,
                    label: title,
                    role: .leaf,
                    position: slot.position,
                    diameter: slot.diameter
                )
            )

            if let status = satellite?.status {
                statusMap[nodeID] = status
            }
        }

        nodes = matrixNodes
        selectedNodeID = selectedNodeID.flatMap { previous in
            matrixNodes.contains(where: { $0.id == previous }) ? previous : nil
        } ?? rootID
        rootMeaning = resolution.rootMeaning.isEmpty ? figmaReference.rootMeaning : resolution.rootMeaning
        nodeStatusByID = statusMap
    }

    private func renderFallbackMatrix() {
        let rootID = "root:\(figmaReference.rootLabel)"
        var matrixNodes: [ExploreMatrixNode] = [
            ExploreMatrixNode(
                id: rootID,
                label: figmaReference.rootLabel,
                role: .root,
                position: figmaReference.rootPosition,
                diameter: figmaReference.rootDiameter
            )
        ]

        for (index, leaf) in figmaReference.leaves.enumerated() {
            matrixNodes.append(
                ExploreMatrixNode(
                    id: "leaf:\(leaf.label.lowercased()):\(index)",
                    label: leaf.label,
                    role: .leaf,
                    position: leaf.position,
                    diameter: leaf.diameter
                )
            )
        }

        nodes = matrixNodes
        selectedNodeID = rootID
        rootMeaning = figmaReference.rootMeaning
        nodeStatusByID = [:]
    }

    private func displayLabel(_ lemma: String) -> String {
        let cleaned = lemma.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = cleaned.first else { return lemma }
        return first.uppercased() + cleaned.dropFirst()
    }

    private func reviewCard(for node: ExploreMatrixNode) -> ReviewCard {
        let normalizedLemma = node.label
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let lexeme = lexemes.first { $0.lemma == normalizedLemma }
        let state = userStates.first {
            $0.userId == profile.userId && $0.lemma == normalizedLemma
        }

        return ReviewCard(
            lemma: normalizedLemma,
            originalWord: node.label,
            contextSentence: lexeme?.sampleSentence ?? "Use '\(normalizedLemma)' in a sentence.",
            definition: lexeme?.basicMeaning,
            stability: state?.stability ?? 0.2,
            difficulty: state?.difficulty ?? 0.3,
            retrievability: state?.retrievability ?? 0.25,
            nextReviewDate: state?.nextReviewDate,
            lastReviewDate: state?.lastReviewDate,
            reviewCount: state?.reviewCount ?? 0,
            createdAt: state?.createdAt ?? Date(),
            status: state?.status ?? .new
        )
    }

    @MainActor
    private func addToDeck(lemma: String, definition: String?) {
        let normalizedLemma = lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedLemma.isEmpty else { return }

        do {
            _ = try triageService.addToDeck(
                NotificationTriagePayload(
                    lemma: normalizedLemma,
                    definition: definition,
                    rank: nil
                ),
                modelContext: modelContext
            )
            buildMatrix()
            infoData = nil
            actionMessage = ExploreActionMessage(
                title: "Added to Deck",
                body: "\(displayLabel(normalizedLemma)) is ready for review."
            )
        } catch {
            actionMessage = ExploreActionMessage(
                title: "Couldn’t Add",
                body: "Try again in a moment."
            )
        }
    }

    private struct FigmaReferenceMatrix {
        struct Leaf {
            let label: String
            let position: CGPoint
            let diameter: CGFloat
        }

        let rootLabel = "spec"
        let rootMeaning = "A morphological root tied to seeing, looking, and observation."
        let rootPosition = CGPoint(x: 0.50, y: 0.4432)
        let rootDiameter: CGFloat = 74

        let leaves: [Leaf] = [
            Leaf(label: "Spectator", position: CGPoint(x: 0.3143, y: 0.1473), diameter: 55),
            Leaf(label: "Retrospect", position: CGPoint(x: 0.6985, y: 0.1787), diameter: 66),
            Leaf(label: "Spectacle", position: CGPoint(x: 0.1710, y: 0.3260), diameter: 55),
            Leaf(label: "Conspicious", position: CGPoint(x: 0.7868, y: 0.5615), diameter: 62),
            Leaf(label: "Perspective", position: CGPoint(x: 0.2114, y: 0.6323), diameter: 67),
            Leaf(label: "Inspect", position: CGPoint(x: 0.4908, y: 0.7367), diameter: 55)
        ]
    }
}

private struct ExploreMatrixNode: Identifiable {
    enum Role {
        case root
        case leaf
    }

    let id: String
    let label: String
    let role: Role
    let position: CGPoint
    let diameter: CGFloat
}

private struct ExploreActionMessage: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}



private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
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
