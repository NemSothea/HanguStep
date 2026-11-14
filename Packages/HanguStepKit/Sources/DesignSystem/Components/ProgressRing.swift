import SwiftUI

public struct ProgressRing<Label: View>: View {
    private let progress: Double
    private let lineWidth: CGFloat
    private let tint: Color
    private let label: Label

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animated: Double = 0

    public init(
        progress: Double,
        lineWidth: CGFloat = 10,
        tint: Color = HSColor.accent,
        @ViewBuilder label: () -> Label
    ) {
        self.progress = min(max(progress, 0), 1)
        self.lineWidth = lineWidth
        self.tint = tint
        self.label = label()
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: animated)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            label
        }
        .padding(lineWidth / 2)
        .onAppear { update() }
        .onChange(of: progress) { update() }
        .accessibilityElement(children: .ignore)
        .accessibilityValue("\(Int((progress * 100).rounded())) percent")
    }

    private func update() {
        if reduceMotion {
            animated = progress
        } else {
            withAnimation(.easeOut(duration: 0.6)) { animated = progress }
        }
    }
}

#Preview("Ring") {
    ProgressRing(progress: 0.72) {
        VStack {
            Text("72%").font(Typography.statValue)
            Text("goal").font(Typography.caption).foregroundStyle(HSColor.textSecondary)
        }
    }
    .frame(width: 140, height: 140)
    .padding()
}
