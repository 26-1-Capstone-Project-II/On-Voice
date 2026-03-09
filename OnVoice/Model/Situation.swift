//
//  Situation.swift
//  OnVoice
//
//  Created by Lee YunJi on 7/23/25.
//


import SwiftUI

enum Situation {
    case quietTalking, loudTalking
    
    var title: String {
        switch self {
        case .quietTalking:
            "조용한 공간"
        case .loudTalking:
            "소음이 있는 공간"
        }
    }
    
//    var image: Image {
//        switch self {
//        case .quietTalking:
//            Image()
//        case .loudTalking:
//            Image()
//        }
//    }
    
    var decibels: (Int, Int) {
        switch self {
        case .quietTalking:
            (53, 75)
        case .loudTalking:
            (58, 80)
        }
    }
    
    var infoMessage: String {
        switch self {
        case .quietTalking, .loudTalking:
            "팔을 앞으로 쭉 편 후\n손이 위치하는 거리에 스마트폰을 놓아주세요."
        }
    }
}
