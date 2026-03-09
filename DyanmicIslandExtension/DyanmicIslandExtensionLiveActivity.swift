//
//  DyanmicIslandExtensionLiveActivity.swift
//  DyanmicIslandExtension
//
//  Created by Lee YunJi on 7/23/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct DyanmicIslandExtensionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct DyanmicIslandExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DyanmicIslandExtensionAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension DyanmicIslandExtensionAttributes {
    fileprivate static var preview: DyanmicIslandExtensionAttributes {
        DyanmicIslandExtensionAttributes(name: "World")
    }
}

extension DyanmicIslandExtensionAttributes.ContentState {
    fileprivate static var smiley: DyanmicIslandExtensionAttributes.ContentState {
        DyanmicIslandExtensionAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: DyanmicIslandExtensionAttributes.ContentState {
         DyanmicIslandExtensionAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: DyanmicIslandExtensionAttributes.preview) {
   DyanmicIslandExtensionLiveActivity()
} contentStates: {
    DyanmicIslandExtensionAttributes.ContentState.smiley
    DyanmicIslandExtensionAttributes.ContentState.starEyes
}
