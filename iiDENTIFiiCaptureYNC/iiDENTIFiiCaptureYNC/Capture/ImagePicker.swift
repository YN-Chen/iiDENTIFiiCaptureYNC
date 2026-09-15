//
//  ImagePicker.swift
//  iiDENTIFiiCaptureYNC
//
//  Created by Yi-Nain Chen on 2026/09/15.
//

import PhotosUI
import SwiftUI
import UIKit

// NOTES:
// Wrap the image picker view in UIViewControllerRepresentable to work for SwiftUI
struct ImagePickerView: UIViewControllerRepresentable {
    enum Source: Identifiable, Hashable {
        case camera
        case photoLibrary

        var id: Self { self }
    }

    let source: Source
    let onImagePicked: (UIImage) -> Void
    let onCancel: () -> Void

    static func isCameraAvailable() -> Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        switch source {
        case .camera:
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = context.coordinator
            return picker
        case .photoLibrary:
            var configuration = PHPickerConfiguration()
            configuration.filter = .images
            configuration.selectionLimit = 1
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = context.coordinator
            return picker
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate {
        private let onImagePicked: (UIImage) -> Void
        private let onCancel: () -> Void

        init(onImagePicked: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImagePicked = onImagePicked
            self.onCancel = onCancel
        }

// MARK: UIImagePickerController for Camera
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }

// MARK: PHPickerViewController for Photo Library
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
                onCancel()
                return
            }

            provider.loadObject(ofClass: UIImage.self) { [onImagePicked, onCancel] object, _ in
                DispatchQueue.main.async {
                    if let image = object as? UIImage {
                        onImagePicked(image)
                    } else {
                        onCancel()
                    }
                }
            }
        }
    }
}
