//
//  MMDiscardChangesGuard.swift
//  movemork
//
//  @file Unsaved edits in a form sheet: swipe-down and Cancel ask "Discard changes?" (Keep editing /
//        Discard) instead of silently dropping what the renter typed. Native confirmation, no new visuals.
//  @domain design-system
//

import SwiftUI
import UIKit

extension View {
    /// Guards a sheet's unsaved edits.
    ///
    /// - While `hasChanges` (or `isBusy`) the sheet can't be swiped away; a swipe attempt with changes asks
    ///   "Discard changes?" instead.
    /// - The sheet's own Cancel/Close sets `isConfirming` when there are changes (see ``MMDiscardChanges/cancel``).
    /// - `onDiscard` dismisses the sheet.
    func mmDiscardChangesGuard(
        hasChanges: Bool,
        isBusy: Bool = false,
        isConfirming: Binding<Bool>,
        onDiscard: @escaping () -> Void
    ) -> some View {
        modifier(MMDiscardChangesGuardModifier(
            hasChanges: hasChanges, isBusy: isBusy, isConfirming: isConfirming, onDiscard: onDiscard
        ))
    }
}

enum MMDiscardChanges {
    /// Cancel/Close: closes at once when nothing was entered, otherwise asks first.
    static func cancel(hasChanges: Bool, isConfirming: Binding<Bool>, dismiss: () -> Void) {
        if hasChanges {
            isConfirming.wrappedValue = true
        } else {
            dismiss()
        }
    }
}

private struct MMDiscardChangesGuardModifier: ViewModifier {
    let hasChanges: Bool
    let isBusy: Bool
    @Binding var isConfirming: Bool
    let onDiscard: () -> Void

    func body(content: Content) -> some View {
        content
            .interactiveDismissDisabled(hasChanges || isBusy)
            .background {
                MMSheetDismissAttemptObserver {
                    if hasChanges && !isBusy { isConfirming = true }
                }
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
            }
            .confirmationDialog("Discard changes?", isPresented: $isConfirming, titleVisibility: .visible) {
                Button("Discard", role: .destructive) {
                    MMHaptics.warning()
                    onDiscard()
                }
                Button("Keep editing", role: .cancel) {}
            }
    }
}

/// Reports a blocked swipe-to-dismiss on the sheet that hosts it (`presentationControllerDidAttemptToDismiss`).
/// SwiftUI owns the presentation controller's delegate, so this wraps it and forwards everything else.
private struct MMSheetDismissAttemptObserver: UIViewControllerRepresentable {
    let onAttempt: () -> Void

    func makeUIViewController(context: Context) -> Controller {
        Controller(onAttempt: onAttempt)
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.onAttempt = onAttempt
        controller.installIfNeeded()
    }

    final class Controller: UIViewController {
        var onAttempt: () -> Void
        private var proxy: DelegateProxy?

        init(onAttempt: @escaping () -> Void) {
            self.onAttempt = onAttempt
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            installIfNeeded()
        }

        /// The sheet's presentation controller: the one presenting this controller's outermost ancestor.
        private var hostingSheetPresentation: UIPresentationController? {
            var root: UIViewController = self
            while let parent = root.parent { root = parent }
            guard root.presentingViewController != nil else { return nil }
            return root.presentationController
        }

        func installIfNeeded() {
            guard let presentation = hostingSheetPresentation else { return }
            if let proxy, presentation.delegate === proxy { return }
            let next = DelegateProxy(original: presentation.delegate) { [weak self] in self?.onAttempt() }
            proxy = next
            presentation.delegate = next
        }
    }

    /// Forwards every delegate call to SwiftUI's own delegate and adds the dismiss-attempt callback.
    final class DelegateProxy: NSObject, UIAdaptivePresentationControllerDelegate {
        nonisolated(unsafe) weak var original: UIAdaptivePresentationControllerDelegate?
        let onAttempt: () -> Void

        init(original: UIAdaptivePresentationControllerDelegate?, onAttempt: @escaping () -> Void) {
            self.original = original
            self.onAttempt = onAttempt
        }

        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
            original?.presentationControllerDidAttemptToDismiss?(presentationController)
            onAttempt()
        }

        nonisolated override func responds(to aSelector: Selector!) -> Bool {
            super.responds(to: aSelector) || (original?.responds(to: aSelector) ?? false)
        }

        nonisolated override func forwardingTarget(for aSelector: Selector!) -> Any? {
            if let original, original.responds(to: aSelector) { return original }
            return super.forwardingTarget(for: aSelector)
        }
    }
}
