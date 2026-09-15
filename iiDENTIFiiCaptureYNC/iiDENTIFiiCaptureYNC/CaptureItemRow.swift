//
//  CaptureItemRow.swift
//  iiDENTIFiiCaptureYNC
//
//  Created by Yi-Nain Chen on 2026/09/15.
//

import SwiftUI
import UIKit

struct CaptureItemRow: View {
    @ObservedObject var item: CaptureItem
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(item.createdAt ?? Date(), format: .dateTime.month().day().hour().minute())
                    .font(.subheadline)

                statusBadge

                if item.captureStatus == .failed, let lastError = item.lastError {
                    Text(lastError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if item.captureStatus == .failed {
                Button("Retry", action: onRetry)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = item.imageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.secondary.opacity(0.2))
                .frame(width: 48, height: 48)
        }
    }

    private var statusBadge: some View {
        Text(item.captureStatus.rawValue.capitalized)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch item.captureStatus {
        case .pending: .gray
        case .uploading: .blue
        case .uploaded: .green
        case .failed: .red
        }
    }
}
