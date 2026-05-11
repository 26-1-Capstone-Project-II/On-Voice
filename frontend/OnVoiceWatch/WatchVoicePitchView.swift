import SwiftUI

struct WatchVoicePitchView: View {
    private let thresholds = VoiceVolumeThresholds.loudTalking

    @State private var noiseMeter = WatchNoiseMeter()

    private var level: VoiceVolumeLevel {
        VoiceVolumeStateCalculator.level(
            for: noiseMeter.decibels,
            isMeasuring: noiseMeter.isMeasuring,
            thresholds: thresholds
        )
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(level.emoji)
                .font(.system(size: 26))
                .frame(height: 30)

            Text(level.message)
                .font(.system(size: 13, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 32)

            WatchVolumeGauge(
                decibels: noiseMeter.decibels,
                thresholds: thresholds,
                level: level
            )
            .frame(height: 46)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(VoiceVolumeStateCalculator.clampedDecibels(noiseMeter.decibels))")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("dB")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = noiseMeter.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            Button {
                Task {
                    await noiseMeter.toggleMetering()
                }
            } label: {
                Image(systemName: noiseMeter.isMeasuring ? "pause.fill" : "mic.fill")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 44, height: 34)
            }
            .buttonStyle(.borderedProminent)
            .tint(level.buttonColor)
            .accessibilityLabel(noiseMeter.isMeasuring ? "측정 일시정지" : "측정 시작")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onDisappear {
            noiseMeter.stopMetering()
        }
    }
}

private struct WatchVolumeGauge: View {
    let decibels: Float
    let thresholds: VoiceVolumeThresholds
    let level: VoiceVolumeLevel

    private var fillRatio: Double {
        Double(min(max(decibels / 120.0, 0.0), 1.0))
    }

    private var lowRatio: Double {
        Double(thresholds.low) / 120.0
    }

    private var highRatio: Double {
        Double(thresholds.high) / 120.0
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.16))

                RoundedRectangle(cornerRadius: 8)
                    .fill(level.gradient)
                    .frame(width: max(8, width * fillRatio))
                    .animation(.easeInOut(duration: 0.2), value: fillRatio)

                thresholdMarker(at: lowRatio, width: width, height: height)
                thresholdMarker(at: highRatio, width: width, height: height)
            }
        }
    }

    private func thresholdMarker(at ratio: Double, width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.72))
            .frame(width: 1, height: height)
            .offset(x: max(0, min(width - 1, width * ratio)))
    }
}

private extension VoiceVolumeLevel {
    var emoji: String {
        switch self {
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

    var message: String {
        switch self {
        case .low:
            return "조금 더 크게 말해볼까요?"
        case .medium:
            return "좋아요. 적절해요!"
        case .high:
            return "조금 더 작게 말해볼까요?"
        case .idle:
            return "버튼을 눌러 시작하세요"
        }
    }

    var buttonColor: Color {
        switch self {
        case .low:
            return .yellow
        case .medium:
            return .blue
        case .high:
            return .red
        case .idle:
            return .purple
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .low:
            return LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
        case .medium:
            return LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing)
        case .high:
            return LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
        case .idle:
            return LinearGradient(colors: [.gray, .gray.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
        }
    }
}

#Preview {
    WatchVoicePitchView()
}
