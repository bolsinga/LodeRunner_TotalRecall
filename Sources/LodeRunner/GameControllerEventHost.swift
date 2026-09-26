#if os(tvOS)
    import GameController
    import SwiftUI

    /// Wraps a SwiftUI view in a `GCEventViewController`, letting `GameView`
    /// switch tvOS input delivery between the focus engine (menus, overlays)
    /// and raw `GCController`/`GCMicroGamepad` profiles (live gameplay) —
    /// per Apple's docs, tvOS can't process both at once for the same view.
    ///
    /// Scoped to just `GameView`'s own subtree rather than the app's actual
    /// root view controller: `PackChooserView` renders `gameLayer` and any
    /// open `overlay` as ZStack siblings, so an overlay's own buttons never
    /// sit inside this wrapper and keep working with ordinary focus
    /// navigation regardless of this view controller's state.
    struct GameControllerEventHost<Content: View>: UIViewControllerRepresentable {
        var controllerUserInteractionEnabled: Bool
        @ViewBuilder let content: Content

        func makeUIViewController(context: Context) -> GameControllerHostingViewController {
            let controller = GameControllerHostingViewController(
                rootView: AnyView(content.environment(\.self, context.environment)))
            controller.controllerUserInteractionEnabled = controllerUserInteractionEnabled
            return controller
        }

        func updateUIViewController(_ uiViewController: GameControllerHostingViewController, context: Context) {
            uiViewController.controllerUserInteractionEnabled = controllerUserInteractionEnabled
            uiViewController.hostingController.rootView = AnyView(
                content.environment(\.self, context.environment))
        }
    }

    /// The `GCEventViewController` itself. Hosts the SwiftUI content as a
    /// child `UIHostingController` so its `controllerUserInteractionEnabled`
    /// governs input delivery for that content — `false` routes D-pad/button
    /// input to `GamepadInput`'s `GCExtendedGamepad`/`GCMicroGamepad`
    /// handlers instead of the focus engine.
    final class GameControllerHostingViewController: GCEventViewController {
        let hostingController: UIHostingController<AnyView>

        init(rootView: AnyView) {
            hostingController = UIHostingController(rootView: rootView)
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            addChild(hostingController)
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(hostingController.view)
            NSLayoutConstraint.activate([
                hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
            hostingController.didMove(toParent: self)
        }
    }
#endif
