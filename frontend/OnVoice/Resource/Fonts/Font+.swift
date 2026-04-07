//
//  Font+.swift
//  OnVoice
//
//  Created by Lee YunJi on 7/23/25.
//
import SwiftUI

enum OnVoiceTextStyle {
    case head1
    case head2
    case title1
    case title2
    case body1
    case body2
    case body3
    case body4
    case body5
    case caption1

    var font: Font {
        switch self {
        case .head1:
            return .Pretendard.Bold.size32
        case .head2:
            return .Pretendard.Bold.size28
        case .title1:
            return .Pretendard.Medium.size24
        case .title2:
            return .Pretendard.Medium.size20
        case .body1:
            return .Pretendard.SemiBold.size18
        case .body2:
            return .Pretendard.Medium.size18
        case .body3:
            return .Pretendard.SemiBold.size16
        case .body4:
            return .Pretendard.Medium.size16
        case .body5:
            return .Pretendard.Medium.size14
        case .caption1:
            return .Pretendard.SemiBold.size12
        }
    }
}

private struct OnVoiceTextStyleModifier: ViewModifier {
    let style: OnVoiceTextStyle
    let color: Color?

    func body(content: Content) -> some View {
        let styledContent = content.font(style.font)
        if let color {
            styledContent.foregroundColor(color)
        } else {
            styledContent
        }
    }
}

extension Font{
    static func onVoice(_ style: OnVoiceTextStyle) -> Font {
        style.font
    }

    enum Pretendard {
        ///font-weight : 700
        enum Bold {
            static let size8: Font = .custom("Pretendard-Bold", size: 8)
            static let size10: Font = .custom("Pretendard-Bold", size: 10)
            static let size12: Font = .custom("Pretendard-Bold", size: 12)
            static let size14: Font = .custom("Pretendard-Bold", size: 14)
            static let size16: Font = .custom("Pretendard-Bold", size: 16)
            static let size18: Font = .custom("Pretendard-Bold", size: 18)
            static let size20: Font = .custom("Pretendard-Bold", size: 20)
            static let size22: Font = .custom("Pretendard-Bold", size: 22)
            static let size24: Font = .custom("Pretendard-Bold", size: 24)
            static let size26: Font = .custom("Pretendard-Bold", size: 26)
            static let size28: Font = .custom("Pretendard-Bold", size: 28)
            static let size32: Font = .custom("Pretendard-Bold", size: 32)
        }
        
        /// font-wight : 600
        enum SemiBold {
            static let size8: Font = .custom("Pretendard-SemiBold", size: 8)
            static let size10: Font = .custom("Pretendard-SemiBold", size: 10)
            static let size12: Font = .custom("Pretendard-SemiBold", size: 12)
            static let size14: Font = .custom("Pretendard-SemiBold", size: 14)
            static let size16: Font = .custom("Pretendard-SemiBold", size: 16)
            static let size17: Font = .custom("Pretendard-SemiBold", size: 17)
            static let size18: Font = .custom("Pretendard-SemiBold", size: 18)
            static let size20: Font = .custom("Pretendard-SemiBold", size: 20)
            static let size22: Font = .custom("Pretendard-SemiBold", size: 22)
            static let size24: Font = .custom("Pretendard-SemiBold", size: 24)
            static let size26: Font = .custom("Pretendard-SemiBold", size: 26)
            static let size28: Font = .custom("Pretendard-SemiBold", size: 28)
            static let size40: Font = .custom("Pretendard-SemiBold", size: 40)
        }
        
        /// font-wight : 500
        enum Medium {
            static let size8: Font = .custom("Pretendard-Medium", size: 8)
            static let size10: Font = .custom("Pretendard-Medium", size: 10)
            static let size12: Font = .custom("Pretendard-Medium", size: 12)
            static let size14: Font = .custom("Pretendard-Medium", size: 14)
            static let size16: Font = .custom("Pretendard-Medium", size: 16)
            static let size18: Font = .custom("Pretendard-Medium", size: 18)
            static let size20: Font = .custom("Pretendard-Medium", size: 20)
            static let size22: Font = .custom("Pretendard-Medium", size: 22)
            static let size24: Font = .custom("Pretendard-Medium", size: 24)
            static let size26: Font = .custom("Pretendard-Medium", size: 26)
            static let size28: Font = .custom("Pretendard-Medium", size: 28)
        }
        
        /// font-wight : 400
        enum Regular {
            static let size8: Font = .custom("Pretendard-Regular", size: 8)
            static let size10: Font = .custom("Pretendard-Regular", size: 10)
            static let size12: Font = .custom("Pretendard-Regular", size: 12)
            static let size14: Font = .custom("Pretendard-Regular", size: 14)
            static let size16: Font = .custom("Pretendard-Regular", size: 16)
            static let size17: Font = .custom("Pretendard-Regular", size: 17)
            static let size18: Font = .custom("Pretendard-Regular", size: 18)
            static let size20: Font = .custom("Pretendard-Regular", size: 20)
            static let size22: Font = .custom("Pretendard-Regular", size: 22)
            static let size24: Font = .custom("Pretendard-Regular", size: 24)
            static let size26: Font = .custom("Pretendard-Regular", size: 26)
            static let size28: Font = .custom("Pretendard-Regular", size: 28)
        }
    }
}

extension View {
    func onVoiceTextStyle(_ style: OnVoiceTextStyle, color: Color? = nil) -> some View {
        modifier(OnVoiceTextStyleModifier(style: style, color: color))
    }
}
