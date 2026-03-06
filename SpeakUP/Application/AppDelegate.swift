//
//  AppDelegate.swift
//  SpeakUP
//
//  Created by Lee YunJi on 7/23/25.
//

import SwiftUI

class AppDelegate: UIResponder, UIApplicationDelegate {
    
    // 앱이 종료될때 실행
    func applicationWillTerminate(_ application: UIApplication) {
        print(#function)
        NoiseMeter.shared.endLiveActivity()
        print("[앱 강제종료 됨 : endLiveActivity Done]")
    }
}
