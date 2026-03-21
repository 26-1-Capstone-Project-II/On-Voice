//
//  DyanmicIslandExtensionBundle.swift
//  DyanmicIslandExtension
//
//  Created by Lee YunJi on 7/23/25.
//

import WidgetKit
import SwiftUI

@main
struct DyanmicIslandExtensionBundle: WidgetBundle {
    var body: some Widget {
        DyanmicIslandExtension()
        DyanmicIslandExtensionControl()
        DyanmicIslandExtensionLiveActivity()
    }
}
