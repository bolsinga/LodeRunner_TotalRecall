import LodeRunner
import SwiftUI

/// SwiftUI `@main` entry for the shipped game. Everything gameplay-related
/// lives in the `LodeRunner` package; this target just opens a `WindowGroup`
/// on the pack chooser.
@main
struct LodeRunnerApp: App {
    var body: some Scene {
        WindowGroup {
            PackChooserView()
        }
    }
}
