import ActivityKit
import SwiftUI
import WidgetKit

struct DynamicIslandWidgetLiveActivity: Widget {
    private let metricBadgeWidth: CGFloat = 95
    private let metricBadgeHeight: CGFloat = 48
    private let progressBarWidth: CGFloat = 222
    private let progressBarHeight: CGFloat = 48
    private let rowSpacing: CGFloat = 8
    private let horizontalInset: CGFloat = 24

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OnVoiceLiveActivityAttributes.self) { context in
            lockScreenView(for: context)
                .containerBackground(for: .widget) {
                    lockScreenBackgroundColor
                }
                .activityBackgroundTint(lockScreenBackgroundColor)
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
                        .foregroundStyle(subColor.opacity(0.78))
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    GeometryReader { geometry in
                        progressBar(
                            for: context.state,
                            width: geometry.size.width,
                            height: 29,
                            cornerRadius: 14.5
                        )
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
    private func lockScreenView(
        for context: ActivityViewContext<OnVoiceLiveActivityAttributes>
    ) -> some View {
        ZStack {
            lockScreenBackgroundColor

            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .center, spacing: 12) {
                    Image("minglyWatermark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 28)

                    Text(context.attributes.name)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(subColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Spacer(minLength: 12)

                    Text(context.state.title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(subColor.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                HStack(spacing: rowSpacing) {
                    metricBadge(for: context.state)

                    progressBar(
                        for: context.state,
                        width: progressBarWidth,
                        height: progressBarHeight,
                        cornerRadius: 24
                    )
                }
            }
            .padding(.horizontal, horizontalInset)
            .padding(.vertical, 24)
        }
    }

    @ViewBuilder
    private func metricBadge(
        for state: OnVoiceLiveActivityAttributes.ContentState,
        valueWidth: CGFloat = 30
    ) -> some View {
        let badgeGradient = levelGradient(for: state)

        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(lockScreenBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(badgeGradient, lineWidth: 1)
                )

            HStack(alignment: .center, spacing: 1) {
                Text(emoji(for: state.level))
                    .font(.system(size: 22))

                Text("\(state.decibels)")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(subColor)
                    .frame(width: valueWidth, alignment: .trailing)
                    .monospacedDigit()

                Text("dB")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(subColor)
                    .padding(.bottom, 2)
            }
            //.padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .frame(width: metricBadgeWidth, height: metricBadgeHeight)
    }

    @ViewBuilder
    private func progressBar(
        for state: OnVoiceLiveActivityAttributes.ContentState,
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat
    ) -> some View {
        let clampedProgress = min(max(CGFloat(state.progress) / 100, 0), 1)
        let fillWidth = width * clampedProgress
        let isIdle = state.level == .idle || state.progress == 0

        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(gray9Color)
                .frame(width: width, height: height)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(levelGradient(for: state))
                .frame(width: isIdle ? 0 : fillWidth, height: height)
                .overlay(alignment: .trailing) {
                    if !isIdle {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.white.opacity(0.16))
                            .frame(width: min(height * 0.42, fillWidth), height: height * 0.74)
                            .blur(radius: 8)
                            .padding(.trailing, height * 0.08)
                    }
                }
                .animation(
                    .interactiveSpring(response: 0.42, dampingFraction: 0.86),
                    value: state.progress
                )
                .animation(
                    .easeInOut(duration: 0.32),
                    value: state.level
                )
        }
        .frame(width: width, height: height)
        .drawingGroup()
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

    private var lockScreenBackgroundColor: Color {
        Color(red: 34 / 255, green: 34 / 255, blue: 34 / 255)
    }

    private var subColor: Color {
        Color(red: 221 / 255, green: 232 / 255, blue: 253 / 255)
    }

    private var gray8Color: Color {
        Color(red: 64 / 255, green: 67 / 255, blue: 80 / 255)
    }

    private var gray9Color: Color {
        Color(red: 46 / 255, green: 48 / 255, blue: 58 / 255)
    }

    private var compactUnitColor: Color {
        subColor
    }

    private func compactNumberColor(for level: OnVoiceLiveActivityAttributes.Level) -> Color {
        switch level {
        case .idle:
            return subColor.opacity(0.72)
        default:
            return subColor
        }
    }

    private func levelGradient(for state: OnVoiceLiveActivityAttributes.ContentState) -> LinearGradient {
        guard state.level != .idle else {
            return LinearGradient(
                colors: [
                    gray8Color.opacity(0.95),
                    gray9Color
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        let gradientColors = gradientColors(for: state)
        return LinearGradient(
            colors: gradientColors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func fillColor(for state: OnVoiceLiveActivityAttributes.ContentState) -> Color {
        guard state.level != .idle else {
            return gray8Color
        }

        let phase = OnVoiceLiveActivityState.interpolationPhase(for: state)
        if phase <= 0.5 {
            return mixColor(
                from: .init(red: 1.0, green: 0.95, blue: 0.44),
                to: .init(red: 0.47, green: 0.77, blue: 0.98),
                fraction: phase / 0.5
            )
        }

        return mixColor(
            from: .init(red: 0.47, green: 0.77, blue: 0.98),
            to: .init(red: 1.0, green: 0.49, blue: 0.56),
            fraction: (phase - 0.5) / 0.5
        )
    }

    private func borderColor(for state: OnVoiceLiveActivityAttributes.ContentState) -> Color {
        guard state.level != .idle else {
            return gray8Color.opacity(0.8)
        }

        let phase = OnVoiceLiveActivityState.interpolationPhase(for: state)
        if phase <= 0.5 {
            return mixColor(
                from: .init(red: 1.0, green: 0.96, blue: 0.58),
                to: .init(red: 0.58, green: 0.84, blue: 1.0),
                fraction: phase / 0.5
            )
        }

        return mixColor(
            from: .init(red: 0.58, green: 0.84, blue: 1.0),
            to: .init(red: 1.0, green: 0.61, blue: 0.65),
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
            RGBAColor(red: 1.0, green: 0.99, blue: 0.79),
            RGBAColor(red: 1.0, green: 0.95, blue: 0.40)
        )
        let mediumGradient = (
            RGBAColor(red: 0.67, green: 0.87, blue: 1.0),
            RGBAColor(red: 0.32, green: 0.58, blue: 1.0)
        )
        let highGradient = (
            RGBAColor(red: 1.0, green: 0.70, blue: 0.76),
            RGBAColor(red: 1.0, green: 0.37, blue: 0.48)
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
