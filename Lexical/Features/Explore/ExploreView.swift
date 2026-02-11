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
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let tilt = CGPoint(x: sin(time * 0.5) * 0.5, y: cos(time * 0.3) * 0.5) // Simulated gentle tilt

            ZStack {
                Color(hex: "F5F5F7").ignoresSafeArea()

                VStack(spacing: 0) {
                    headerView
                    matrixView(time: time, tilt: tilt)
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

    private func matrixView(time: TimeInterval, tilt: CGPoint) -> some View {
        GeometryReader { geometry in
            let figmaScale = matrixScale(for: geometry.size)
            ZStack {
                edgeLayer(in: geometry.size)

                ForEach(nodes) { node in
                    ExploreNodeBubbleView(
                        node: node,
                        isSelected: selectedNodeID == node.id,
                        status: nodeStatusByID[node.id],
                        reduceTransparency: reduceTransparency,
                        rootMeaning: node.role == .root ? rootMeaning : nil,
                        scale: figmaScale,
                        time: time,
                        tilt: tilt
                    )
                    .position(position(for: node, in: geometry.size))
                    .onTapGesture {
                        let card = reviewCard(for: node)
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            selectedNodeID = node.id
                        }
                        infoData = WordDetailDataBuilder.build(for: card, modelContext: modelContext)
                    }
                }
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 8)
        }
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

private struct ExploreNodeBubbleView: View {
    let node: ExploreMatrixNode
    let isSelected: Bool
    let status: UserWordStatus?
    let reduceTransparency: Bool
    let rootMeaning: String?
    let scale: CGFloat
    let time: TimeInterval
    let tilt: CGPoint

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if node.role == .root {
                rootBubble
            } else {
                leafBubble
            }
        }
        .scaleEffect(isSelected ? 1.04 : 1)
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.32 : 0.18),
            radius: isSelected ? 11 * scale : 8.5 * scale,
            x: 0,
            y: isSelected ? 7 * scale : 4.6 * scale
        )
        // Apply Metal Liquid Glass Shader (Elite Effect)
        .layerEffect(
            ShaderLibrary.liquid_glass_surface(
                .float(time),
                .float2(tilt)
            ),
            maxSampleOffset: .init(width: 20, height: 20),
            isEnabled: !reduceTransparency && ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 17
        )
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    // MARK: - Root Bubble (Coral Liquid Glass)

    private var rootBubble: some View {
        let diameter = node.diameter * scale

        return ZStack {
            // Base glass layer
            rootGlassBase

            // Specular highlight — radial, centered top-left (Figma: inset 16 16 9 -18 white@0.5)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(reduceTransparency ? 0.15 : 0.38),
                            .clear
                        ],
                        center: .init(x: 0.28, y: 0.22),
                        startRadius: 0,
                        endRadius: diameter * 0.55
                    )
                )

            // Bottom-right vignette (Figma: inset -12 -12 9 -16 #B3B3B3@0.6)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "B3B3B3").opacity(0.28),
                            .clear
                        ],
                        center: .init(x: 0.72, y: 0.78),
                        startRadius: 0,
                        endRadius: diameter * 0.45
                    )
                )

            // Inner glow (Figma: inset 0 0 22px rgba(242,242,242,0.5))
            Circle()
                .stroke(Color(hex: "F2F2F2").opacity(0.45), lineWidth: 10 * scale)
                .blur(radius: 10 * scale)
                .clipShape(Circle())

            // Gradient border — white accent top-left fading to transparent bottom-right
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.72),
                            Color.white.opacity(0.48),
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.72)
                        ],
                        center: .center,
                        startAngle: .degrees(200),
                        endAngle: .degrees(560)
                    ),
                    lineWidth: 1.2
                )

            // Labels
            VStack(spacing: 2) {
                Text(node.label)
                    .font(.system(size: 14 * scale, weight: .bold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)

                Text("root")
                    .font(.system(size: 7 * scale, weight: .regular))
                    .foregroundStyle(.white.opacity(0.92))
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
        }
        .frame(width: diameter, height: diameter)
    }

    @ViewBuilder
    private var rootGlassBase: some View {
        if reduceTransparency {
            // Accessibility: solid opaque coral
            Circle().fill(Color(hex: "C94A55"))
        } else if #available(iOS 26.0, *) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "FF9AA5"),
                            Color(hex: "F96A78"),
                            Color(hex: "EE5563")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .glassEffect(
                    .regular
                        .tint(Color(hex: "E85D6C").opacity(0.8))
                        .interactive(),
                    in: Circle()
                )
        } else {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "FF9AA5"),
                                Color(hex: "F96A78"),
                                Color(hex: "EE5563")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(Color(hex: "7B0002").opacity(0.35))
                    .blendMode(.colorBurn)

                Circle()
                    .fill(.clear)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .opacity(0.35)
            }
        }
    }

    // MARK: - Leaf Bubble (Forest Green Liquid Glass)

    private var leafBubble: some View {
        let diameter = node.diameter * scale

        return ZStack {
            // Base glass layer
            leafGlassBase

            // Specular highlight — radial, top-left (dimmer than root)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(reduceTransparency ? 0.10 : 0.24),
                            .clear
                        ],
                        center: .init(x: 0.28, y: 0.22),
                        startRadius: 0,
                        endRadius: diameter * 0.50
                    )
                )

            // Bottom-right vignette (Figma: inset -12 -12 6 -14 #B3B3B3)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "B3B3B3").opacity(0.22),
                            .clear
                        ],
                        center: .init(x: 0.72, y: 0.78),
                        startRadius: 0,
                        endRadius: diameter * 0.40
                    )
                )

            // Inner glow (Figma: inset 0 0 22px rgba(242,242,242,0.5))
            Circle()
                .stroke(Color(hex: "F2F2F2").opacity(0.35), lineWidth: 8 * scale)
                .blur(radius: 8 * scale)
                .clipShape(Circle())

            // Gradient border — angular white accent
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.50),
                            Color.white.opacity(0.28),
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.10),
                            Color.white.opacity(0.50)
                        ],
                        center: .center,
                        startAngle: .degrees(200),
                        endAngle: .degrees(560)
                    ),
                    lineWidth: 1.0
                )

            // Selected state — outer ring
            if isSelected {
                Circle()
                    .stroke(Color.white.opacity(0.58), lineWidth: 1.8)
                    .padding(-2.5)
            }

            // Label
            Text(node.label)
                .font(.system(size: 9 * scale, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.62)
                .padding(.horizontal, 8)
        }
        .frame(width: diameter, height: diameter)
    }

    @ViewBuilder
    private var leafGlassBase: some View {
        if reduceTransparency {
            // Accessibility: solid opaque forest green
            Circle().fill(Color(hex: "2B4735"))
        } else if #available(iOS 26.0, *) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "5A765F"),
                            Color(hex: "36513F"),
                            Color(hex: "24392C")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .glassEffect(
                    .regular
                        .tint(Color(hex: "2B4735").opacity(0.75))
                        .interactive(),
                    in: Circle()
                )
        } else {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "5A765F"),
                                Color(hex: "36513F"),
                                Color(hex: "24392C")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(Color(hex: "021105").opacity(0.45))
                    .blendMode(.colorBurn)

                Circle()
                    .fill(.clear)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .opacity(0.28)
            }
        }
    }

    private var accessibilityLabel: String {
        if node.role == .root {
            return "\(node.label), root node"
        }

        if let status {
            let statusText: String
            switch status {
            case .new:
                statusText = "new"
            case .learning:
                statusText = "learning"
            case .known:
                statusText = "known"
            case .ignored:
                statusText = "ignored"
            }
            return "\(node.label), \(statusText)"
        }

        return node.label
    }

    private var accessibilityHint: String {
        if node.role == .root, let rootMeaning, !rootMeaning.isEmpty {
            return rootMeaning
        }
        return "Double tap to focus this matrix node."
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
