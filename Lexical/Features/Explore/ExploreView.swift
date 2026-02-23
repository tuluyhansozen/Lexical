import SwiftUI
import SwiftData
import LexicalCore

/// Explore renders a fixed-topology daily matrix aligned to the iPhone 16-3 Figma composition.
struct ExploreView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

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
    private let figmaSpec = ExploreFigmaSpec()
    private let triageService = NotificationTriageService()

    private var profile: UserProfile {
        UserProfile.resolveActiveProfile(modelContext: modelContext)
    }

    var body: some View {
        GeometryReader { geometry in
            let layoutWidth = geometry.size.width
            ZStack {
                backgroundColor.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerView(layoutWidth: layoutWidth)
                    matrixView
                }
            }
        }
        .safeAreaPadding(.bottom, 92)
        .onAppear(perform: buildMatrix)
        .onChange(of: roots.count) { buildMatrix() }
        .onChange(of: lexemes.count) { buildMatrix() }
        .onChange(of: userStatesRevisionKey) { buildMatrix() }
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

    private func headerView(layoutWidth: CGFloat) -> some View {
        let scale = headerScale(for: layoutWidth)
        let titleColor = colorScheme == .dark
            ? Color(hex: figmaSpec.titleDarkHex)
            : Color(hex: figmaSpec.titleLightHex)
        let subtitleColor = colorScheme == .dark
            ? Color(hex: figmaSpec.subtitleDarkHex)
            : Color(hex: figmaSpec.subtitleLightHex)

        return VStack(alignment: .leading, spacing: 6 * scale) {
            Text(figmaSpec.titleText)
                .font(.system(size: figmaSpec.titleFontSize * scale, weight: .semibold))
                .kerning(figmaSpec.titleKerning * scale)
                .foregroundStyle(titleColor)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Text(figmaSpec.subtitleText)
                .font(.system(size: figmaSpec.subtitleFontSize * scale, weight: .light))
                .foregroundStyle(subtitleColor)
                .minimumScaleFactor(0.85)
                .lineLimit(1)
                .accessibilityIdentifier("explore.subtitle")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 16 * scale)
        .padding(.horizontal, 24 * scale)
        .padding(.bottom, 18 * scale)
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
            .padding(.horizontal, 1)
            .padding(.top, 4)
            .padding(.bottom, 14)
        }
    }

    private func nodeButton(for node: ExploreMatrixNode, figmaScale: CGFloat, size: CGSize) -> some View {
        LiquidGlassButton(
            style: node.role == .root ? figmaSpec.rootLiquidGlassStyle : figmaSpec.leafLiquidGlassStyle,
            action: {
                let card = reviewCard(for: node)
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    selectedNodeID = node.id
                }
                infoData = WordDetailDataBuilder.build(for: card, modelContext: modelContext)
            }
        ) {
            if node.role == .root {
                VStack(spacing: 2 * figmaScale) {
                    Text(node.label.lowercased())
                        .font(.system(size: figmaSpec.rootPrimaryFontSize * figmaScale, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text("root")
                        .font(.system(size: figmaSpec.rootSecondaryFontSize * figmaScale, weight: .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(.white)
            } else {
                VStack(spacing: 2) {
                    Text(node.label)
                        .font(.system(size: figmaSpec.leafFontSize * figmaScale, weight: .regular))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 4)
                }
                .overlay(
                    Group {
                        if let status = nodeStatusByID[node.id], status.isLearned {
                            Circle()
                                .stroke(Color(hex: "8ADD95").opacity(0.64), lineWidth: 2)
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

                let lineOpacity = colorScheme == .dark
                    ? figmaSpec.connectorOpacityDark
                    : figmaSpec.connectorOpacityLight
                let gradient = Gradient(colors: [
                    Color(hex: figmaSpec.connectorStartHex).opacity(lineOpacity),
                    Color(hex: figmaSpec.connectorEndHex).opacity(lineOpacity * 0.9)
                ])
                context.stroke(
                    path,
                    with: .linearGradient(
                        gradient,
                        startPoint: rootPos,
                        endPoint: leafPos
                    ),
                    style: StrokeStyle(lineWidth: figmaSpec.connectorLineWidth, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }

    private func position(for node: ExploreMatrixNode, in size: CGSize) -> CGPoint {
        let horizontalInset = figmaSpec.matrixHorizontalInset
        let topInset = figmaSpec.matrixTopInset
        let bottomInset = figmaSpec.matrixBottomInset
        let width = max(1, size.width - (horizontalInset * 2))
        let height = max(1, size.height - topInset - bottomInset)

        return CGPoint(
            x: horizontalInset + (node.position.x * width),
            y: topInset + (node.position.y * height)
        )
    }

    private func headerScale(for layoutWidth: CGFloat) -> CGFloat {
        let scale = layoutWidth / 393.0
        return scale.clamped(to: 0.88...1.2)
    }

    private func matrixScale(for size: CGSize) -> CGFloat {
        let scale = size.width / 393.0
        return scale.clamped(to: 0.86...1.2)
    }

    private var backgroundColor: Color {
        if colorScheme == .dark {
            return Color(hex: figmaSpec.darkBackgroundHex)
        }
        return Color(hex: figmaSpec.lightBackgroundHex)
    }

    private var userStatesRevisionKey: Int {
        var hasher = Hasher()
        for state in userStates {
            hasher.combine(state.userLemmaKey)
            hasher.combine(state.statusRawValue)
            hasher.combine(state.reviewCount)
            hasher.combine(state.stateUpdatedAt.timeIntervalSinceReferenceDate)
            hasher.combine(state.nextReviewDate?.timeIntervalSinceReferenceDate ?? -1)
        }
        return hasher.finalize()
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
                position: figmaSpec.rootPosition,
                diameter: figmaSpec.rootDiameter
            )
        ]

        var statusMap: [String: UserWordStatus] = [:]
        let satellites = Array(resolution.satellites.prefix(figmaSpec.leaves.count))

        for (index, slot) in figmaSpec.leaves.enumerated() {
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
        rootMeaning = resolution.rootMeaning.isEmpty ? figmaSpec.rootMeaning : resolution.rootMeaning
        nodeStatusByID = statusMap
    }

    private func renderFallbackMatrix() {
        let rootID = "root:\(figmaSpec.rootLabel)"
        var matrixNodes: [ExploreMatrixNode] = [
            ExploreMatrixNode(
                id: rootID,
                label: figmaSpec.rootLabel,
                role: .root,
                position: figmaSpec.rootPosition,
                diameter: figmaSpec.rootDiameter
            )
        ]

        for (index, leaf) in figmaSpec.leaves.enumerated() {
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
        rootMeaning = figmaSpec.rootMeaning
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
}

struct ExploreFigmaSpec {
    struct Leaf {
        let label: String
        let position: CGPoint
        let diameter: CGFloat
    }

    let titleText = "Explore"
    let subtitleText = "Daily word families for you"
    let titleFontSize: CGFloat = 32
    let subtitleFontSize: CGFloat = 16
    let titleKerning: CGFloat = 0.3955
    let rootPrimaryFontSize: CGFloat = 16
    let rootSecondaryFontSize: CGFloat = 10
    let leafFontSize: CGFloat = 9
    let lightBackgroundHex = "F5F5F7"
    let darkBackgroundHex = "121417"
    let titleLightHex = "0A0A0A"
    let titleDarkHex = "F5F5F7"
    let subtitleLightHex = "4A4A4A"
    let subtitleDarkHex = "97A1AC"
    let connectorStartHex = "D4D7DD"
    let connectorEndHex = "BCC3CB"
    let connectorOpacityLight: Double = 0.57
    let connectorOpacityDark: Double = 0.32
    let connectorLineWidth: CGFloat = 1
    let rootNodeStyleKey = "rootCoralGlass"
    let leafNodeStyleKey = "leafGreenGlass"

    let matrixHorizontalInset: CGFloat = 12
    let matrixTopInset: CGFloat = 16
    let matrixBottomInset: CGFloat = 30

    let rootLabel = "spec"
    let rootMeaning = "A morphological root tied to seeing, looking, and observation."
    let rootPosition = CGPoint(x: 0.50, y: 0.4432)
    let rootDiameter: CGFloat = 99

    let leaves: [Leaf] = [
        Leaf(label: "Spectator", position: CGPoint(x: 0.3143, y: 0.1473), diameter: 73),
        Leaf(label: "Retrospect", position: CGPoint(x: 0.6985, y: 0.1787), diameter: 88),
        Leaf(label: "Spectacle", position: CGPoint(x: 0.1710, y: 0.3260), diameter: 73),
        Leaf(label: "Conspicious", position: CGPoint(x: 0.7868, y: 0.5615), diameter: 82),
        Leaf(label: "Perspective", position: CGPoint(x: 0.2114, y: 0.6323), diameter: 89),
        Leaf(label: "Inspect", position: CGPoint(x: 0.4908, y: 0.7367), diameter: 73)
    ]

    var rootLiquidGlassStyle: LiquidGlassStyle { .root }
    var leafLiquidGlassStyle: LiquidGlassStyle { .leaf }
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

@MainActor
private func explorePreviewContainer() -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: MorphologicalRoot.self,
        LexemeDefinition.self,
        UserWordState.self,
        UserProfile.self,
        configurations: config
    )
    
    let root = MorphologicalRoot(
        rootId: 1,
        root: "spec",
        basicMeaning: "A morphological root tied to seeing, looking, and observation."
    )
    container.mainContext.insert(root)
    
    let lexemes = [
        LexemeDefinition(lemma: "spectator", basicMeaning: "A person who watches at a show, game, or other event."),
        LexemeDefinition(lemma: "retrospect", basicMeaning: "A survey or review of a past course of events or period of time."),
        LexemeDefinition(lemma: "spectacle", basicMeaning: "A visually striking performance or display.")
    ]
    for l in lexemes { container.mainContext.insert(l) }
    
    container.mainContext.insert(UserProfile(userId: UserProfile.fallbackLocalUserID, lexicalRank: 100))
    
    return container
}

#Preview {
    ExploreView()
        .modelContainer(explorePreviewContainer())
}
