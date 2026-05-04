import ActivityKit
import WidgetKit
import SwiftUI

struct DynamicIslandWidgetLiveActivity: Widget {
    private let metricBadgeWidth: CGFloat = 95
    private let barHeight: CGFloat = 48

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OnVoiceLiveActivityAttributes.self) { context in
            VStack {
                HStack {
                    Text("OnVoice")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.leading)
                    
                    Spacer()
                    
                    Text("\(context.state.title)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.trailing)
                }
                .padding([.top, .horizontal])
                
                HStack(spacing: 10) {
                    metricBadge(for: context.state)
                    GeometryReader { geometry in
                        progressBar(
                            for: context.state,
                            width: geometry.size.width,
                            height: barHeight
                        )
                    }
                    .frame(height: barHeight)
                }
                .padding([.bottom, .horizontal])
            }
            .activityBackgroundTint(Color(red: 0.15, green: 0.17, blue: 0.23))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(alignment: .bottom) {
                        metricBadge(for: context.state, valueWidth: 35)
                        .padding(.leading, 8)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: symbolName(for: context.state.level))
                        .font(.title2)
                        .foregroundStyle(fillColor(for: context.state))
                        .frame(width: 40, height: 40)
                        .padding(.trailing, 11)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                }

                DynamicIslandExpandedRegion(.bottom) {
                    GeometryReader { geometry in
                        progressBar(for: context.state, width: geometry.size.width, height: 29)
                    }
                    .padding(.bottom, 18)
                    .padding(.horizontal, 11)
                }
            } compactLeading: {
                compactDecibelView(for: context.state)
            } compactTrailing: {
                compactLevelIndicator(for: context.state)
            } minimal: {
                minimalLevelIndicator(for: context.state)
            }
            .keylineTint(borderColor(for: context.state))
        }
    }

    @ViewBuilder
    private func metricBadge(
        for state: OnVoiceLiveActivityAttributes.ContentState,
        valueWidth: CGFloat = 30
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.clear)
                .frame(width: metricBadgeWidth, height: barHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(borderColor(for: state), lineWidth: 1)
                )
            HStack(alignment: .bottom, spacing: 1) {
                Text(emoji(for: state.level))
                    .font(.title3)

                Text("\(state.decibels)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: valueWidth)

                Text("dB")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.top, 3)
            }
        }
    }

    @ViewBuilder
    private func progressBar(
        for state: OnVoiceLiveActivityAttributes.ContentState,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        let clampedProgress = min(max(CGFloat(state.progress), 0), 100)

        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.gray.opacity(0.3))
                .frame(width: width, height: height)

            RoundedRectangle(cornerRadius: 24)
                .fill(fillColor(for: state))
                .frame(width: width * clampedProgress / 100, height: height)
        }
    }

    @ViewBuilder
    private func compactDecibelView(for state: OnVoiceLiveActivityAttributes.ContentState) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 1) {
            Text("\(state.decibels)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(compactNumberColor(for: state.level))
                .monospacedDigit()

            Text("dB")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(compactUnitColor)
        }
        .frame(minWidth: 33, alignment: .leading)
    }

    @ViewBuilder
    private func compactLevelIndicator(for state: OnVoiceLiveActivityAttributes.ContentState) -> some View {
        Capsule()
            .fill(levelGradient(for: state))
            .overlay(
                Capsule()
                    .stroke(borderColor(for: state).opacity(0.35), lineWidth: 1)
            )
            .frame(width: 41, height: 23)
    }

    @ViewBuilder
    private func minimalLevelIndicator(for state: OnVoiceLiveActivityAttributes.ContentState) -> some View {
        Circle()
            .fill(levelGradient(for: state))
            .overlay(
                Circle()
                    .stroke(borderColor(for: state).opacity(0.4), lineWidth: 1)
            )
            .frame(width: 20, height: 20)
    }

    private var compactUnitColor: Color {
        Color(red: 0.83, green: 0.88, blue: 0.98)
    }

    private func compactNumberColor(for level: OnVoiceLiveActivityAttributes.Level) -> Color {
        switch level {
        case .idle:
            return Color.white.opacity(0.75)
        default:
            return Color(red: 0.86, green: 0.91, blue: 1.0)
        }
    }

    private func levelGradient(for state: OnVoiceLiveActivityAttributes.ContentState) -> LinearGradient {
        guard state.level != .idle else {
            return LinearGradient(
                colors: [
                    Color(red: 0.72, green: 0.72, blue: 0.76),
                    Color(red: 0.52, green: 0.52, blue: 0.56)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        let gradientColors = gradientColors(for: state)
        return LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing)
    }

    private func fillColor(for state: OnVoiceLiveActivityAttributes.ContentState) -> Color {
        guard state.level != .idle else {
            return Color.gray
        }

        let phase = OnVoiceLiveActivityState.interpolationPhase(for: state)
        if phase <= 0.5 {
            return mixColor(
                from: .init(red: 0.96, green: 0.74, blue: 0.23),
                to: .init(red: 0.31, green: 0.67, blue: 0.95),
                fraction: phase / 0.5
            )
        }

        return mixColor(
            from: .init(red: 0.31, green: 0.67, blue: 0.95),
            to: .init(red: 0.91, green: 0.35, blue: 0.33),
            fraction: (phase - 0.5) / 0.5
        )
    }

    private func borderColor(for state: OnVoiceLiveActivityAttributes.ContentState) -> Color {
        guard state.level != .idle else {
            return Color.gray.opacity(0.6)
        }

        let phase = OnVoiceLiveActivityState.interpolationPhase(for: state)
        if phase <= 0.5 {
            return mixColor(
                from: .init(red: 0.98, green: 0.85, blue: 0.40),
                to: .init(red: 0.46, green: 0.76, blue: 0.98),
                fraction: phase / 0.5
            )
        }

        return mixColor(
            from: .init(red: 0.46, green: 0.76, blue: 0.98),
            to: .init(red: 0.98, green: 0.52, blue: 0.49),
            fraction: (phase - 0.5) / 0.5
        )
    }

    private func emoji(for level: OnVoiceLiveActivityAttributes.Level) -> String {
        switch level {
        case .low:
            return "🤔"
        case .medium:
            return "👍"
        case .high:
            return "😮"
        case .idle:
            return "🔇"
        }
    }

    private func symbolName(for level: OnVoiceLiveActivityAttributes.Level) -> String {
        switch level {
        case .low:
            return "speaker.wave.1.fill"
        case .medium:
            return "speaker.wave.2.fill"
        case .high:
            return "speaker.wave.3.fill"
        case .idle:
            return "speaker.slash.fill"
        }
    }

    private func gradientColors(for state: OnVoiceLiveActivityAttributes.ContentState) -> [Color] {
        let phase = OnVoiceLiveActivityState.interpolationPhase(for: state)

        let lowGradient = (
            RGBAColor(red: 0.99, green: 0.99, blue: 0.78),
            RGBAColor(red: 1.0, green: 0.97, blue: 0.36)
        )
        let mediumGradient = (
            RGBAColor(red: 0.56, green: 0.77, blue: 1.0),
            RGBAColor(red: 0.24, green: 0.44, blue: 0.96)
        )
        let highGradient = (
            RGBAColor(red: 1.0, green: 0.58, blue: 0.68),
            RGBAColor(red: 1.0, green: 0.30, blue: 0.39)
        )

        if phase <= 0.5 {
            let fraction = phase / 0.5
            return [
                mixColor(from: lowGradient.0, to: mediumGradient.0, fraction: fraction),
                mixColor(from: lowGradient.1, to: mediumGradient.1, fraction: fraction)
            ]
        }

        let fraction = (phase - 0.5) / 0.5
        return [
            mixColor(from: mediumGradient.0, to: highGradient.0, fraction: fraction),
            mixColor(from: mediumGradient.1, to: highGradient.1, fraction: fraction)
        ]
    }

    private func mixColor(from start: RGBAColor, to end: RGBAColor, fraction: Double) -> Color {
        let clampedFraction = min(max(fraction, 0), 1)
        let mixed = RGBAColor(
            red: start.red + (end.red - start.red) * clampedFraction,
            green: start.green + (end.green - start.green) * clampedFraction,
            blue: start.blue + (end.blue - start.blue) * clampedFraction,
            alpha: start.alpha + (end.alpha - start.alpha) * clampedFraction
        )

        return Color(
            red: mixed.red,
            green: mixed.green,
            blue: mixed.blue,
            opacity: mixed.alpha
        )
    }

    private struct RGBAColor {
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }
    }
}
