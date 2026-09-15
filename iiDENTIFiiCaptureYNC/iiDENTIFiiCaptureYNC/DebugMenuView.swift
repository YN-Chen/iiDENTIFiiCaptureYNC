//
//  DebugMenuView.swift
//  iiDENTIFiiCaptureYNC
//
//  Created by Yi-Nain Chen on 2026/09/15.
//

import SwiftUI

// NOTES:
// QA only screen, revealed by shaking the device, lets a reviewer exercise the
// failed/retry path on demand to get server to respond with 500 without editing code or
// rebuilding.
struct DebugMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var forceFailure = AppEnvironment.shared.isForcingUploadFailure

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Force uploads to fail (500)", isOn: $forceFailure)
                        .onChange(of: forceFailure) { _, newValue in
                            AppEnvironment.shared.setForcingUploadFailure(newValue)
                        }
                } footer: {
                    Text("While on, the mock server responds to every upload with a 500 error, so a capture will land in Failed instead of Uploaded.")
                }
            }
            .navigationTitle("Debug Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
