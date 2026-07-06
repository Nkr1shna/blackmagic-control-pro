import SwiftUI

@main
struct BlackmagicControlApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Blackmagic Control")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
        }
    }
}
