//
//  ShakeDetection.swift
//  iiDENTIFiiCaptureYNC
//
//  Created by Yi-Nain Chen on 2026/09/15.
//

import SwiftUI
import UIKit

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

struct ShakeViewModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content.onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
            action()
        }
    }
}

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        modifier(ShakeViewModifier(action: action))
    }
}
