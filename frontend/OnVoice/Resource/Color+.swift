//
//  Color+.swift
//  OnVoice
//
//  Created by Lee YunJi on 7/23/25.
//


import SwiftUI
import UIKit

private enum OnVoicePalette {
    static let main = UIColor(red: 61 / 255, green: 100 / 255, blue: 189 / 255, alpha: 1)
    static let sub = UIColor(red: 221 / 255, green: 232 / 255, blue: 253 / 255, alpha: 1)
    static let bg = UIColor(red: 21 / 255, green: 22 / 255, blue: 28 / 255, alpha: 1)
    static let gray1 = UIColor(red: 240 / 255, green: 240 / 255, blue: 243 / 255, alpha: 1)
    static let gray2 = UIColor(red: 218 / 255, green: 219 / 255, blue: 224 / 255, alpha: 1)
    static let gray3 = UIColor(red: 185 / 255, green: 187 / 255, blue: 197 / 255, alpha: 1)
    static let gray4 = UIColor(red: 156 / 255, green: 158 / 255, blue: 173 / 255, alpha: 1)
    static let gray5 = UIColor(red: 130 / 255, green: 133 / 255, blue: 151 / 255, alpha: 1)
    static let gray6 = UIColor(red: 106 / 255, green: 109 / 255, blue: 129 / 255, alpha: 1)
    static let gray7 = UIColor(red: 84 / 255, green: 87 / 255, blue: 104 / 255, alpha: 1)
    static let gray8 = UIColor(red: 64 / 255, green: 67 / 255, blue: 80 / 255, alpha: 1)
    static let gray9 = UIColor(red: 46 / 255, green: 48 / 255, blue: 58 / 255, alpha: 1)
    static let gray10 = UIColor(red: 29 / 255, green: 30 / 255, blue: 38 / 255, alpha: 1)
    static let absent = UIColor(red: 1, green: 160 / 255, blue: 160 / 255, alpha: 1)
}

extension UIColor {
    static let main = OnVoicePalette.main
    static let sub = OnVoicePalette.sub
    static let bg = OnVoicePalette.bg
    static let gray1 = OnVoicePalette.gray1
    static let gray2 = OnVoicePalette.gray2
    static let gray3 = OnVoicePalette.gray3
    static let gray4 = OnVoicePalette.gray4
    static let gray5 = OnVoicePalette.gray5
    static let gray6 = OnVoicePalette.gray6
    static let gray7 = OnVoicePalette.gray7
    static let gray8 = OnVoicePalette.gray8
    static let gray9 = OnVoicePalette.gray9
    static let gray10 = OnVoicePalette.gray10
    static let absent = OnVoicePalette.absent
}

extension Color {
    static let main = Color(uiColor: .main)
    static let sub = Color(uiColor: .sub)
    static let bg = Color(uiColor: .bg)
    static let gray1 = Color(uiColor: .gray1)
    static let gray2 = Color(uiColor: .gray2)
    static let gray3 = Color(uiColor: .gray3)
    static let gray4 = Color(uiColor: .gray4)
    static let gray5 = Color(uiColor: .gray5)
    static let gray6 = Color(uiColor: .gray6)
    static let gray7 = Color(uiColor: .gray7)
    static let gray8 = Color(uiColor: .gray8)
    static let gray9 = Color(uiColor: .gray9)
    static let gray10 = Color(uiColor: .gray10)
    static let absent = Color(uiColor: .absent)

    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >>  8) & 0xFF) / 255.0
        let b = Double((rgb >>  0) & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
