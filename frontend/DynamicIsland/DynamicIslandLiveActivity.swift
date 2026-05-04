import ActivityKit
import WidgetKit
import SwiftUI

struct DynamicIslandWidgetLiveActivity: Widget {
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
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.clear)
                            .frame(width: 95, height: 48)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(borderColor(for: context.state), lineWidth: 1)
                            )
                        HStack(spacing: 1) {
                            Text(emoji(for: context.state.level))
                                .font(.title3)
                            
                            Text("\(context.state.decibels)")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 30)
                            
                            Text("dB")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .padding(.top, 3)
                        }
                    }
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 222, height: 48)
                        
                        RoundedRectangle(cornerRadius: 24)
                            .fill(fillColor(for: context.state))
                            .frame(width: CGFloat(context.state.progress) / 100 * 222, height: 48)
                    }
                }
                .padding([.bottom, .horizontal])
            }
            .activityBackgroundTint(Color(red: 0.15, green: 0.17, blue: 0.23))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(alignment: .bottom) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.clear)
                                .frame(width: 95, height: 48)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(borderColor(for: context.state), lineWidth: 1)
                                )
                            HStack(alignment: .bottom, spacing: 1) {
                                Text(emoji(for: context.state.level))
                                    .font(.title3)
                                
                                Text("\(context.state.decibels)")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 35)
                                
                                Text("dB")
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                                    .padding(.top, 3)
                            }
                        }
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
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: geometry.size.width, height: 29)
                            
                            RoundedRectangle(cornerRadius: 24)
                                .fill(fillColor(for: context.state))
                                .frame(width: geometry.size.width * CGFloat(context.state.progress) / 100, height: 29)
                        }
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

        let phase = colorInterpolationPhase(for: state)
        if phase <= 0.5 {
            return mixColor(
                from: Color(red: 0.96, green: 0.74, blue: 0.23),
                to: Color(red: 0.31, green: 0.67, blue: 0.95),
                fraction: phase / 0.5
            )
        }

        return mixColor(
            from: Color(red: 0.31, green: 0.67, blue: 0.95),
            to: Color(red: 0.91, green: 0.35, blue: 0.33),
            fraction: (phase - 0.5) / 0.5
        )
    }

    private func borderColor(for state: OnVoiceLiveActivityAttributes.ContentState) -> Color {
        guard state.level != .idle else {
            return Color.gray.opacity(0.6)
        }

        let phase = colorInterpolationPhase(for: state)
        if phase <= 0.5 {
            return mixColor(
                from: Color(red: 0.98, green: 0.85, blue: 0.40),
                to: Color(red: 0.46, green: 0.76, blue: 0.98),
                fraction: phase / 0.5
            )
        }

        return mixColor(
            from: Color(red: 0.46, green: 0.76, blue: 0.98),
            to: Color(red: 0.98, green: 0.52, blue: 0.49),
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
        let phase = colorInterpolationPhase(for: state)

        let lowGradient = (
            Color(red: 0.99, green: 0.99, blue: 0.78),
            Color(red: 1.0, green: 0.97, blue: 0.36)
        )
        let mediumGradient = (
            Color(red: 0.56, green: 0.77, blue: 1.0),
            Color(red: 0.24, green: 0.44, blue: 0.96)
        )
        let highGradient = (
            Color(red: 1.0, green: 0.58, blue: 0.68),
            Color(red: 1.0, green: 0.30, blue: 0.39)
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

    private func colorInterpolationPhase(for state: OnVoiceLiveActivityAttributes.ContentState) -> Double {
        let decibels = Double(state.decibels)
        let low = Double(state.lowThreshold)
        let high = Double(state.highThreshold)
        let transitionWidth = 8.0
        let halfTransition = transitionWidth / 2

        guard state.level != .idle else { return 0 }

        if high <= low {
            return decibels > high ? 1 : 0
        }

        let lowTransitionStart = low - halfTransition
        let lowTransitionEnd = low + halfTransition
        let highTransitionStart = high - halfTransition
        let highTransitionEnd = high + halfTransition

        if decibels <= lowTransitionStart {
            return 0
        }

        if decibels < lowTransitionEnd {
            let fraction = (decibels - lowTransitionStart) / transitionWidth
            return smoothStep(fraction) * 0.5
        }

        if decibels <= highTransitionStart {
            return 0.5
        }

        if decibels < highTransitionEnd {
            let fraction = (decibels - highTransitionStart) / transitionWidth
            return 0.5 + smoothStep(fraction) * 0.5
        }

        return 1.0
    }

    private func mixColor(from start: Color, to end: Color, fraction: Double) -> Color {
        let clampedFraction = min(max(fraction, 0), 1)
        let startComponents = rgbaComponents(for: UIColor(start))
        let endComponents = rgbaComponents(for: UIColor(end))

        return Color(
            red: startComponents.red + (endComponents.red - startComponents.red) * clampedFraction,
            green: startComponents.green + (endComponents.green - startComponents.green) * clampedFraction,
            blue: startComponents.blue + (endComponents.blue - startComponents.blue) * clampedFraction,
            opacity: startComponents.alpha + (endComponents.alpha - startComponents.alpha) * clampedFraction
        )
    }

    private func rgbaComponents(for color: UIColor) -> (red: Double, green: Double, blue: Double, alpha: Double) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return (0, 0, 0, 1)
        }

        return (Double(red), Double(green), Double(blue), Double(alpha))
    }

    private func smoothStep(_ value: Double) -> Double {
        let clampedValue = min(max(value, 0), 1)
        return clampedValue * clampedValue * (3 - 2 * clampedValue)
    }
}
