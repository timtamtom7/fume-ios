import SwiftUI

// MARK: - Brain Illustration (Onboarding Screen 1)

struct BrainIllustration: View {
    @State private var pulsePhase: CGFloat = 0
    @State private var rotationAngle: Double = 0

    var body: some View {
        ZStack {
            // Ambient glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [FumeColors.accent.opacity(0.2), Color.clear],
                        center: .center,
                        startRadius: 30,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .blur(radius: pulsePhase * 10 + 5)
                .opacity(0.6)

            // Neuron connections - outer ring
            ForEach(0..<6, id: \.self) { index in
                NeuronDot(index: index, phase: pulsePhase)
            }

            // Central brain icon
            ZStack {
                // Glow ring
                Circle()
                    .stroke(FumeColors.accent.opacity(0.3 + pulsePhase * 0.2), lineWidth: 2)
                    .frame(width: 100, height: 100)

                Circle()
                    .fill(FumeColors.surfaceRaised)
                    .frame(width: 90, height: 90)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [FumeColors.accent, FumeColors.accentDim],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .rotationEffect(.degrees(rotationAngle))
            }

            // Orbiting particles
            ForEach(0..<4, id: \.self) { index in
                OrbitParticle(index: index, phase: pulsePhase)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                pulsePhase = 1
            }
            withAnimation(.easeInOut(duration: 20).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }
}

struct NeuronDot: View {
    let index: Int
    let phase: CGFloat

    var body: some View {
        let angle = Double(index) * 60 + phase * 30
        let radius: CGFloat = 80 + phase * 10

        Circle()
            .fill(FumeColors.accent.opacity(0.4 + phase * 0.3))
            .frame(width: 8, height: 8)
            .offset(
                x: cos(angle * .pi / 180) * radius,
                y: sin(angle * .pi / 180) * radius
            )
            .blur(radius: 2)
    }
}

struct OrbitParticle: View {
    let index: Int
    let phase: CGFloat

    var body: some View {
        let angle = Double(index) * 90 + phase * 60
        let radius: CGFloat = 110 + phase * 5

        Circle()
            .fill(FumeColors.accent.opacity(0.6))
            .frame(width: 4, height: 4)
            .offset(
                x: cos(angle * .pi / 180) * radius,
                y: sin(angle * .pi / 180) * radius
            )
    }
}

// MARK: - Query Illustration (Onboarding Screen 3)

struct QueryIllustration: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Query bubble
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(FumeColors.textSecondary)

                    Text("What did I read about local AI?")
                        .font(.system(size: 14))
                        .foregroundStyle(FumeColors.textPrimary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(FumeColors.surfaceRaised)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(FumeColors.accent.opacity(0.4), lineWidth: 1)
                        )
                )
                .offset(x: isAnimating ? 0 : -20)
                .opacity(isAnimating ? 1 : 0)

                // Response bubble
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 12))
                            .foregroundStyle(FumeColors.accent)

                        Text("From your notes:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(FumeColors.textSecondary)
                    }

                    Rectangle()
                        .fill(FumeColors.textSecondary.opacity(0.3))
                        .frame(height: 12)
                        .cornerRadius(4)
                        .padding(.trailing, 40)

                    Rectangle()
                        .fill(FumeColors.textSecondary.opacity(0.3))
                        .frame(height: 12)
                        .cornerRadius(4)
                        .padding(.trailing, 20)

                    Rectangle()
                        .fill(FumeColors.textSecondary.opacity(0.2))
                        .frame(width: 100, height: 12)
                        .cornerRadius(4)
                }
                .padding(14)
                .glassCard()
                .amberGlow(isActive: true, cornerRadius: 16)
                .offset(x: isAnimating ? 0 : 20)
                .opacity(isAnimating ? 1 : 0)
            }
            .padding(20)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Amplified Mind Illustration (Onboarding Screen 4)

struct AmplifiedMindIllustration: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            // Central brain
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [FumeColors.accent.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .blur(radius: phase * 8 + 4)

                Circle()
                    .stroke(FumeColors.accent.opacity(0.4), lineWidth: 1.5)
                    .frame(width: 90, height: 90)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 38))
                    .foregroundStyle(FumeColors.accent)
            }

            // Radiating knowledge nodes
            ForEach(0..<5, id: \.self) { index in
                KnowledgeNode(index: index, phase: phase)
            }

            // Connection lines
            ForEach(0..<5, id: \.self) { index in
                ConnectionLine(index: index, phase: phase)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }
}

struct KnowledgeNode: View {
    let index: Int
    let phase: CGFloat

    var body: some View {
        let angle = Double(index) * 72 + phase * 20
        let radius: CGFloat = 85 + phase * 15

        ZStack {
            Circle()
                .fill(FumeColors.accent.opacity(0.15))
                .frame(width: 30, height: 30)

            Image(systemName: nodeIcon)
                .font(.system(size: 13))
                .foregroundStyle(FumeColors.accent)
        }
        .offset(
            x: cos(angle * .pi / 180) * radius,
            y: sin(angle * .pi / 180) * radius
        )
        .opacity(0.7 + phase * 0.3)
    }

    var nodeIcon: String {
        let icons = ["note.text", "link", "waveform", "photo", "doc.text"]
        return icons[index]
    }
}

struct ConnectionLine: View {
    let index: Int
    let phase: CGFloat

    var body: some View {
        let angle = Double(index) * 72
        let radius: CGFloat = 85 + phase * 15

        Path { path in
            path.move(to: .zero)
            path.addLine(to: CGPoint(
                x: cos(angle * .pi / 180) * radius,
                y: sin(angle * .pi / 180) * radius
            ))
        }
        .stroke(
            FumeColors.accent.opacity(0.2 + phase * 0.2),
            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
        )
    }
}

// MARK: - Source Type Icons with Amber Glow

struct SourceTypeIcon: View {
    let type: SourceType
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            Circle()
                .fill(iconColor.opacity(0.15))
                .frame(width: size + 16, height: size + 16)

            Image(systemName: type.icon)
                .font(.system(size: size * 0.7))
                .foregroundStyle(iconColor)
        }
    }

    var iconColor: Color {
        switch type {
        case .note: return FumeColors.accent
        case .article: return Color(hex: "3b82f6")
        case .voiceMemo: return Color(hex: "8b5cf6")
        case .image: return Color(hex: "10b981")
        case .pdf: return Color(hex: "ef4444")
        }
    }
}

// MARK: - Amber Processing Glow

struct AmberProcessingGlow: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [FumeColors.accent.opacity(0.3), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)
                .scaleEffect(isAnimating ? 1.3 : 1.0)
                .opacity(isAnimating ? 0.4 : 0.8)

            // Inner pulse
            Circle()
                .fill(FumeColors.accent.opacity(0.15))
                .frame(width: 60, height: 60)
                .scaleEffect(isAnimating ? 1.2 : 0.8)
                .opacity(isAnimating ? 0.6 : 1.0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Thinking Dots (enhanced)

struct ThinkingDotsView: View {
    @State private var animPhase: CGFloat = 0

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<4) { index in
                Circle()
                    .fill(FumeColors.accent)
                    .frame(width: 8, height: 8)
                    .offset(y: dotOffset(for: index))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                animPhase = 1
            }
        }
    }

    private func dotOffset(for index: Int) -> CGFloat {
        guard animPhase > 0 else { return 0 }
        let delay = Double(index) * 0.15
        return sin((animPhase + CGFloat(delay)) * .pi) * 8
    }
}
