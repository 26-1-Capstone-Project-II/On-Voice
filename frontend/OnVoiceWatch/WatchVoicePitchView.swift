import SwiftUI

struct WatchVoicePitchView: View {
    private let thresholds = VoiceVolumeThresholds.loudTalking

    @Environment(\.dismiss) private var dismiss
    @State private var noiseMeter = WatchNoiseMeter()
    @State private var isPreparing = false
    @State private var startTask: Task<Void, Never>?

    let autoStart: Bool

    init(autoStart: Bool = false) {
        self.autoStart = autoStart
    }

    private var level: VoiceVolumeLevel {
        VoiceVolumeStateCalculator.level(
            for: noiseMeter.decibels,
            isMeasuring: noiseMeter.isMeasuring,
            thresholds: thresholds
        )
    }

    private var displayLevel: VoiceVolumeLevel {
        noiseMeter.isMeasuring ? level : .idle
    }

    var body: some View {
        ZStack {
            watchBackground

            if isPreparing {
                preparingContent
            } else {
                meterContent
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear {
            startTask?.cancel()
            noiseMeter.stopMetering()
        }
        .task {
            guard autoStart else { return }
            beginRecognitionFlow()
        }
    }

    private var watchBackground: some View {
        Color(.sRGB, red: 0.09, green: 0.10, blue: 0.14, opacity: 1)
            .ignoresSafeArea()
    }

    private var meterContent: some View {
        VStack(spacing: 0) {
            topBar(leadingTitle: "종료")

            Spacer()
                .frame(height: 10)

            statusBadge

            Spacer()
                .frame(height: 14)

            WatchVolumeGauge(
                decibels: noiseMeter.decibels,
                thresholds: thresholds,
                level: displayLevel
            )
            .frame(width: 143, height: 40)

            Spacer()
                .frame(height: 8)

            dbLabel

            if let errorMessage = noiseMeter.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.red.opacity(0.95))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 8)
            } else {
                Spacer()
                    .frame(height: 8)
            }

            controlButton

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.top, 2)
    }

    private var preparingContent: some View {
        VStack(spacing: 0) {
            topBar(leadingTitle: "취소")

            Spacer()

            WatchLoadingDots()

            Spacer()
                .frame(height: 14)

            Text("주변 소음을 인식하고 있어요!")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.top, 2)
    }

    private func topBar(leadingTitle: String) -> some View {
        HStack {
            Button(leadingTitle) {
                handleCloseTapped()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Self.watchBlue)
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private var statusBadge: some View {
        Capsule()
            .fill(Color(.sRGB, red: 0.11, green: 0.12, blue: 0.17, opacity: 1))
            .overlay {
                Capsule()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            }
            .frame(width: 40, height: 26)
            .overlay {
                Text(displayLevel.badgeSymbol)
                    .font(.system(size: 17))
            }
    }

    private var dbLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            if noiseMeter.isMeasuring {
                Text("\(VoiceVolumeStateCalculator.clampedDecibels(noiseMeter.decibels))")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text("dB")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            } else {
                Text("-")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                Text("dB")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    private var controlButton: some View {
        Button {
            handlePrimaryButtonTapped()
        } label: {
            ZStack {
                Capsule()
                    .fill(Color(.sRGB, red: 0.17, green: 0.19, blue: 0.25, opacity: 1))

                Image(systemName: noiseMeter.isMeasuring ? "pause.fill" : "mic.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Self.watchBlue)
            }
            .frame(width: 143, height: 42)
        }
        .buttonStyle(.plain)
        .padding(.top, 10)
        .accessibilityLabel(noiseMeter.isMeasuring ? "측정 일시정지" : "측정 시작")
    }

    private func handlePrimaryButtonTapped() {
        if noiseMeter.isMeasuring {
            noiseMeter.stopMetering()
        } else {
            beginRecognitionFlow()
        }
    }

    private func handleCloseTapped() {
        startTask?.cancel()
        noiseMeter.stopMetering()
        dismiss()
    }

    private func beginRecognitionFlow() {
        startTask?.cancel()
        noiseMeter.stopMetering()
        isPreparing = true
        startTask = Task {
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                isPreparing = false
            }
            await noiseMeter.startMetering()
        }
    }
}

private extension WatchVoicePitchView {
    static let watchBlue = Color(.sRGB, red: 0.30, green: 0.47, blue: 0.96, opacity: 1)
}

private struct WatchVolumeGauge: View {
    let decibels: Float
    let thresholds: VoiceVolumeThresholds
    let level: VoiceVolumeLevel

    private var fillRatio: Double {
        guard level != .idle else { return 0 }
        return Double(min(max(decibels / 120.0, 0.0), 1.0))
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.sRGB, red: 0.19, green: 0.20, blue: 0.25, opacity: 1))

                if fillRatio > 0 {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(level.gaugeGradient)
                        .frame(width: max(12, width * fillRatio))
                        .animation(.easeInOut(duration: 0.18), value: fillRatio)
                }

                HStack(spacing: 0) {
                    ForEach(1..<4, id: \.self) { index in
                        Spacer()
                        Rectangle()
                            .fill(Color(.sRGB, red: 0.28, green: 0.29, blue: 0.35, opacity: 1))
                            .frame(width: 1, height: height)
                        Spacer()
                    }
                }
                .padding(.horizontal, width / 8)
            }
        }
        .clipped()
    }
}

private struct WatchLoadingDots: View {
    @State private var activeIndex = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.18)) { context in
            let tick = Int(context.date.timeIntervalSinceReferenceDate / 0.18)

            HStack(spacing: 4) {
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(
                            Color(
                                .sRGB,
                                red: 0.30,
                                green: 0.47,
                                blue: 0.96,
                                opacity: index == tick % 6 ? 1 : 0.35
                            )
                        )
                        .frame(width: 7, height: 7)
                        .offset(y: index.isMultiple(of: 2) ? -2 : 2)
                }
            }
        }
    }
}

private extension VoiceVolumeLevel {
    var badgeSymbol: String {
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

    var gaugeGradient: LinearGradient {
        switch self {
        case .low:
            return LinearGradient(
                colors: [
                    Color(.sRGB, red: 1.0, green: 0.96, blue: 0.62, opacity: 1),
                    Color(.sRGB, red: 1.0, green: 0.95, blue: 0.36, opacity: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .medium:
            return LinearGradient(
                colors: [
                    Color(.sRGB, red: 0.24, green: 0.43, blue: 0.94, opacity: 1),
                    Color(.sRGB, red: 0.90, green: 0.93, blue: 1.0, opacity: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .high:
            return LinearGradient(
                colors: [
                    Color(.sRGB, red: 1.0, green: 0.27, blue: 0.32, opacity: 1),
                    Color(.sRGB, red: 1.0, green: 0.73, blue: 0.76, opacity: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .idle:
            return LinearGradient(
                colors: [
                    Color(.sRGB, red: 0.19, green: 0.20, blue: 0.25, opacity: 1),
                    Color(.sRGB, red: 0.19, green: 0.20, blue: 0.25, opacity: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

#Preview {
    WatchVoicePitchView()
}
