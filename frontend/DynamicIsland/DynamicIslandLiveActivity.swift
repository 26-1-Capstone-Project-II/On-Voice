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
                                    .stroke(borderColor(for: context.state.level), lineWidth: 1)
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
                            .fill(fillColor(for: context.state.level))
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
                                        .stroke(borderColor(for: context.state.level), lineWidth: 1)
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
                        .foregroundStyle(fillColor(for: context.state.level))
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
                                .fill(fillColor(for: context.state.level))
                                .frame(width: geometry.size.width * CGFloat(context.state.progress) / 100, height: 29)
                        }
                    }
                    .padding(.bottom, 18)
                    .padding(.horizontal, 11)
                }
            } compactLeading: {
                HStack(alignment: .bottom, spacing: 1) {
                    Text("\(context.state.decibels)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 22)
                    Text("dB")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.bottom, 2)
                }
            } compactTrailing: {
                Image(systemName: symbolName(for: context.state.level))
                    .foregroundStyle(fillColor(for: context.state.level))
            } minimal: {
                HStack(alignment: .bottom, spacing: 1) {
                    Text(emoji(for: context.state.level))
                        .font(.caption)
                }
            }
            .keylineTint(fillColor(for: context.state.level))
        }
    }

    private func fillColor(for level: OnVoiceLiveActivityAttributes.Level) -> Color {
        switch level {
        case .low:
            return Color(red: 0.96, green: 0.74, blue: 0.23)
        case .medium:
            return Color(red: 0.31, green: 0.67, blue: 0.95)
        case .high:
            return Color(red: 0.91, green: 0.35, blue: 0.33)
        case .idle:
            return Color.gray
        }
    }

    private func borderColor(for level: OnVoiceLiveActivityAttributes.Level) -> Color {
        switch level {
        case .low:
            return Color(red: 0.98, green: 0.85, blue: 0.40)
        case .medium:
            return Color(red: 0.46, green: 0.76, blue: 0.98)
        case .high:
            return Color(red: 0.98, green: 0.52, blue: 0.49)
        case .idle:
            return Color.gray.opacity(0.6)
        }
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
}
