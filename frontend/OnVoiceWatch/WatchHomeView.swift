import SwiftUI

struct WatchHomeView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.sRGB, red: 0.09, green: 0.10, blue: 0.14, opacity: 1)
                    .ignoresSafeArea()

                NavigationLink {
                    WatchVoicePitchView(autoStart: true)
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(.sRGB, red: 0.17, green: 0.19, blue: 0.25, opacity: 1))
                            .frame(width: 54, height: 54)

                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color(.sRGB, red: 0.30, green: 0.47, blue: 0.96, opacity: 1))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    WatchHomeView()
}
