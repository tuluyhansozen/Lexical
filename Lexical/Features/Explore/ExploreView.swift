import SwiftUI
import SwiftData
import LexicalCore

/// Explore renders a fixed-topology daily matrix with accessibility-aware fallbacks.
struct ExploreView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query private var roots: [MorphologicalRoot]
    @Query private var lexemes: [LexemeDefinition]
    @Query private var userStates: [UserWordState]

    @State private var nodes: [ExploreMatrixNode] = []
    @State private var selectedNodeID: String?
    @State private var rootMeaning: String = ""
    @State private var nodeStatusByID: [String: UserWordStatus] = [:]
    @State private var infoData: WordDetailData?
    @State private var infoCard: ReviewCard?
    @State private var actionMessage: ExploreActionMessage?

    private let dailyRootResolver = DailyRootResolver()
    private let visualSpec = ExploreVisualSpec()
    private let triageService = NotificationTriageService()

    private var profile: UserProfile {
        UserProfile.resolveActiveProfile(modelContext: modelContext)
    }

    private var accessibilityMode: ExploreAccessibilityMode {
        ExploreAccessibilityMode.resolve(
            reduceMotion: reduceMotion,
            dynamicTypeSize: dynamicTypeSize
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let layoutWidth = geometry.size.width
            ZStack {
                matrixBackground(in: geometry.size).ignoresSafeArea()

                VStack(spacing: 0) {
                    headerView(layoutWidth: layoutWidth)

                    if accessibilityMode == .graph {
                        graphStage(in: geometry.size)
                    } else {
                        fallbackListView
                    }
                }
            }
        }
        .safeAreaPadding(.bottom, 78)
        .onAppear(perform: buildMatrix)
        .onChange(of: roots.count) { buildMatrix() }
        .onChange(of: lexemes.count) { buildMatrix() }
        .onChange(of: userStatesRevisionKey) { buildMatrix() }
        .task {
            SeedLexemeIndex.prewarm()
        }
        .sheet(item: $infoData, onDismiss: {
            infoCard = nil
        }) { detail in
            WordDetailSheet(
                data: detail,
                onAddToDeck: {
                    addToDeck(lemma: detail.lemma, definition: detail.definition)
                }
            )
            .presentationDetents(
                WordInfoSheetPresentation.detents(for: detail, includesPrimaryAction: true)
            )
            .presentationContentInteraction(.scrolls)
        }
        .alert(item: $actionMessage) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.body),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func headerView(layoutWidth: CGFloat) -> some View {
        let scale = headerScale(for: layoutWidth)
        let titleColor = colorScheme == .dark
            ? Color(hex: visualSpec.titleDarkHex)
            : Color(hex: visualSpec.titleLightHex)
        let subtitleColor = colorScheme == .dark
            ? Color(hex: visualSpec.subtitleDarkHex)
            : Color(hex: visualSpec.subtitleLightHex)

        return VStack(alignment: .leading, spacing: 6 * scale) {
            Text(visualSpec.titleText)
                .font(.system(size: visualSpec.titleFontSize * scale, weight: .semibold, design: .default))
                .kerning(visualSpec.titleKerning * scale)
                .foregroundStyle(titleColor)
                .minimumScaleFactor(0.82)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("explore.headerTitle")

            Text(visualSpec.subtitleText)
                .font(.system(size: visualSpec.subtitleFontSize * scale, weight: .light, design: .default))
                .kerning(visualSpec.subtitleKerning * scale)
                .foregroundStyle(subtitleColor)
                .minimumScaleFactor(0.85)
                .lineLimit(1)
                .accessibilityIdentifier("explore.subtitle")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 17 * scale)
        .padding(.horizontal, 24 * scale)
        .padding(.bottom, 10 * scale)
    }

    private func graphStage(in _: CGSize) -> some View {
        GeometryReader { proxy in
            let canvasSize = fittedCanvasSize(for: proxy.size)
            let scale = canvasSize.width / visualSpec.designCanvasSize.width

            matrixView(canvasSize: canvasSize, scale: scale)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func matrixView(canvasSize: CGSize, scale: CGFloat) -> some View {
        ZStack {
            edgeLayer(in: canvasSize)

            ForEach(nodes) { node in
                nodeButton(for: node, scale: scale, size: canvasSize)
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
    }

    @ViewBuilder
    private func nodeButton(for node: ExploreMatrixNode, scale: CGFloat, size: CGSize) -> some View {
        Button {
            openDetail(for: node)
        } label: {
            nodeLabel(for: node, scale: scale)
                .frame(width: node.diameter * scale, height: node.diameter * scale)
                .modifier(
                    ExploreNodeSurface(
                        role: node.role,
                        visualSpec: visualSpec,
                        isSelected: selectedNodeID == node.id
                    )
                )
        }
        .buttonStyle(.plain)
        .position(position(for: node, in: size))
        .accessibilityIdentifier(node.accessibilityID)
        .accessibilityLabel(ExploreNodeLabelPolicy.accessibilityLabel(for: node.label))
        .accessibilityHint(node.role == .root ? rootMeaning : "Double tap for details")
        .accessibilityValue(node.role == .leaf ? statusSummary(for: node) : "Root")
    }

    @ViewBuilder
    private func nodeLabel(for node: ExploreMatrixNode, scale: CGFloat) -> some View {
        if node.role == .root {
            VStack(spacing: 2 * scale) {
                Text(node.label.lowercased())
                    .font(.system(size: visualSpec.rootPrimaryFontSize * scale, weight: .bold, design: .default))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("root")
                    .font(.system(size: visualSpec.rootSecondaryFontSize * scale, weight: .regular, design: .default))
                    .lineLimit(1)
            }
        } else {
            Text(
                ExploreNodeLabelPolicy.renderedLabel(
                    for: node.label,
                    dynamicTypeSize: dynamicTypeSize
                )
            )
            .font(.system(size: visualSpec.leafFontSize * scale, weight: .regular, design: .default))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.65)
            .padding(.horizontal, 6)
        }
    }

    private var fallbackListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Accessible list mode")
                    .font(.display(.caption, weight: .semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary)
                    .padding(.top, 4)

                ForEach(nodes) { node in
                    fallbackListRow(for: node)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("explore.fallbackList")
    }

    private func fallbackListRow(for node: ExploreMatrixNode) -> some View {
        Button {
            openDetail(for: node)
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(node.role == .root ? rootListColor : leafListColor)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(ExploreNodeLabelPolicy.accessibilityLabel(for: node.label))
                        .font(.display(.body, weight: .semibold))
                        .foregroundStyle(Color.adaptiveText)

                    Text(node.role == .root ? rootMeaning : statusSummary(for: node))
                        .font(.display(.caption, weight: .regular))
                        .foregroundStyle(Color.adaptiveTextSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.adaptiveSurfaceElevated.opacity(0.9))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.adaptiveBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(node.accessibilityID)
    }

    private func statusSummary(for node: ExploreMatrixNode) -> String {
        guard let status = nodeStatusByID[node.id] else { return "New" }
        switch status {
        case .known: return "Known"
        case .learning: return "Learning"
        case .new: return "New"
        case .ignored: return "Unknown"
        }
    }

    private func openDetail(for node: ExploreMatrixNode) {
        let card = reviewCard(for: node)
        let lemma = card.lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        selectedNodeID = node.id
        infoCard = card
        infoData = WordDetailDataBuilder.build(for: card, modelContext: modelContext)

        Task { @MainActor in
            let hydrated = await WordDetailDataBuilder.buildEnsuringSeedData(
                for: card,
                modelContext: modelContext
            )
            guard infoData?.lemma == lemma else { return }
            infoData = hydrated
        }
    }

    private var leafListColor: Color {
        colorScheme == .dark
            ? Color(hex: visualSpec.leafFillHexDark)
            : Color(hex: visualSpec.leafFillHexLight)
    }

    private var rootListColor: Color {
        (colorScheme == .dark
            ? Color(hex: visualSpec.rootFillHexDark)
            : Color(hex: visualSpec.rootFillHexLight))
            .opacity(visualSpec.rootFillOpacity)
    }

    private func edgeLayer(in size: CGSize) -> some View {
        Canvas { context, _ in
            guard let root = nodes.first(where: { $0.role == .root }) else { return }
            let rootPos = position(for: root, in: size)
            let lineColor = colorScheme == .dark
                ? Color(hex: visualSpec.connectorHexDark)
                : Color(hex: visualSpec.connectorHexLight)
            let lineOpacity = colorScheme == .dark
                ? visualSpec.connectorOpacityDark
                : visualSpec.connectorOpacityLight

            for leaf in nodes where leaf.role == .leaf {
                let leafPos = position(for: leaf, in: size)
                var path = Path()
                path.move(to: rootPos)
                path.addLine(to: leafPos)

                context.stroke(
                    path,
                    with: .color(lineColor.opacity(lineOpacity)),
                    style: StrokeStyle(
                        lineWidth: visualSpec.connectorLineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }
        }
        .accessibilityHidden(true)
    }

    private func position(for node: ExploreMatrixNode, in size: CGSize) -> CGPoint {
        return CGPoint(
            x: node.position.x * max(1, size.width),
            y: node.position.y * max(1, size.height)
        )
    }

    private func headerScale(for layoutWidth: CGFloat) -> CGFloat {
        let scale = layoutWidth / 393.0
        return scale.clamped(to: 0.88...1.22)
    }

    private func fittedCanvasSize(for availableSize: CGSize) -> CGSize {
        let designSize = visualSpec.designCanvasSize
        let widthScale = max(0.001, availableSize.width / designSize.width)
        let heightScale = max(0.001, availableSize.height / designSize.height)
        let scale = min(widthScale, heightScale).clamped(to: 0.74...1.28)

        return CGSize(
            width: designSize.width * scale,
            height: designSize.height * scale
        )
    }

    private func matrixBackground(in _: CGSize) -> some View {
        colorScheme == .dark
            ? Color(hex: visualSpec.darkBackgroundHex)
            : Color(hex: visualSpec.lightBackgroundHex)
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
                accessibilityID: "explore.node.root",
                label: resolution.centerLemma.lowercased(),
                role: .root,
                position: visualSpec.rootPosition,
                diameter: visualSpec.rootDiameter
            )
        ]

        var statusMap: [String: UserWordStatus] = [:]
        let satellites = Array(resolution.satellites.prefix(visualSpec.leafSlots.count))

        for (index, slot) in visualSpec.leafSlots.enumerated() {
            let satellite = satellites[safe: index]
            let title = satellite.map { displayLabel($0.lemma) } ?? slot.label
            let nodeID = "leaf:\(title.lowercased()):\(index)"

            matrixNodes.append(
                ExploreMatrixNode(
                    id: nodeID,
                    accessibilityID: "explore.node.leaf.\(index)",
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
        rootMeaning = resolution.rootMeaning.isEmpty ? visualSpec.rootMeaning : resolution.rootMeaning
        nodeStatusByID = statusMap
    }

    private func renderFallbackMatrix() {
        let rootID = "root:\(visualSpec.rootLabel)"
        var matrixNodes: [ExploreMatrixNode] = [
            ExploreMatrixNode(
                id: rootID,
                accessibilityID: "explore.node.root",
                label: visualSpec.rootLabel,
                role: .root,
                position: visualSpec.rootPosition,
                diameter: visualSpec.rootDiameter
            )
        ]

        for (index, leaf) in visualSpec.leafSlots.enumerated() {
            matrixNodes.append(
                ExploreMatrixNode(
                    id: "leaf:\(leaf.label.lowercased()):\(index)",
                    accessibilityID: "explore.node.leaf.\(index)",
                    label: leaf.label,
                    role: .leaf,
                    position: leaf.position,
                    diameter: leaf.diameter
                )
            )
        }

        nodes = matrixNodes
        selectedNodeID = rootID
        rootMeaning = visualSpec.rootMeaning
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

private struct ExploreMatrixNode: Identifiable {
    enum Role {
        case root
        case leaf
    }

    let id: String
    let accessibilityID: String
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

private struct ExploreNodeSurface: ViewModifier {
    let role: ExploreMatrixNode.Role
    let visualSpec: ExploreVisualSpec
    let isSelected: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var isRoot: Bool {
        role == .root
    }

    private var fillColor: Color {
        if isRoot {
            return (colorScheme == .dark
                ? Color(hex: visualSpec.rootFillHexDark)
                : Color(hex: visualSpec.rootFillHexLight))
                .opacity(visualSpec.rootFillOpacity)
        }
        return colorScheme == .dark
            ? Color(hex: visualSpec.leafFillHexDark)
            : Color(hex: visualSpec.leafFillHexLight)
    }

    private var strokeColor: Color {
        colorScheme == .dark
            ? Color(hex: visualSpec.nodeStrokeHexDark).opacity(0.24)
            : Color(hex: visualSpec.nodeStrokeHexLight).opacity(0.34)
    }

    func body(content: Content) -> some View {
        content
            .foregroundStyle(Color.white.opacity(0.92))
            .background(surface)
            .overlay(
                Circle()
                    .stroke(strokeColor, lineWidth: 0.9)
            )
            .clipShape(Circle())
            .shadow(
                color: Color.black.opacity(0.20),
                radius: 6,
                x: 0,
                y: 3
            )
            .shadow(
                color: Color.white.opacity(colorScheme == .dark ? 0.06 : 0.28),
                radius: 1.4,
                x: -0.5,
                y: -0.5
            )
    }

    @ViewBuilder
    private var surface: some View {
        if reduceTransparency {
            Circle().fill(fillColor)
        } else {
            ZStack {
                Circle()
                    .fill(fillColor)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottom
                        )
                    )

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.black.opacity(0.18)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.28),
                                Color.clear
                            ],
                            center: .topTrailing,
                            startRadius: 0,
                            endRadius: 45
                        )
                    )
            }
        }
    }
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
