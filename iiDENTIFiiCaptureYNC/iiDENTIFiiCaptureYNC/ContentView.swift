//
//  ContentView.swift
//  iiDENTIFiiCaptureYNC
//
//  Created by Yi-Nain Chen on 2026/09/15.
//

import CoreData
import SwiftUI

struct ContentView: View {
    @FetchRequest(fetchRequest: CaptureItem.allItemsSortedByCreatedAt())
    private var items: FetchedResults<CaptureItem>

    @State private var isShowingSourcePicker = false
    @State private var activeSource: ImagePickerView.Source?

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView("No Captures Yet",
                                           systemImage: "camera",
                                           description: Text("Tap + to capture a document or selfie."))
                } else {
                    List(items) { item in
                        CaptureItemRow(item: item) {
                            Task { await AppEnvironment.shared.uploadManager?.retry(itemID: item.objectID) }
                        }
                    }
                }
            }
            .navigationTitle("Captures")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingSourcePicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .confirmationDialog("Add Capture",
                                isPresented: $isShowingSourcePicker,
                                titleVisibility: .visible) {
                if ImagePickerView.isCameraAvailable() {
                    Button("Take Photo") { activeSource = .camera }
                }
                Button("Choose from Library") { activeSource = .photoLibrary }
            }
            .sheet(item: $activeSource) { source in
                ImagePickerView(
                    source: source,
                    onImagePicked: { image in
                        activeSource = nil
                        Task { await handlePicked(image) }
                    },
                    onCancel: { activeSource = nil }
                )
                .ignoresSafeArea()
            }
        }
    }

    private func handlePicked(_ image: UIImage) async {
        guard let data = await ImageProcessor.process(image) else { return }

        let context = AppEnvironment.shared.persistenceController.backgroundContext
        await context.perform {
            CaptureItem.makeInsert(into: context, imageData: data)
            try? context.save()
        }

        await AppEnvironment.shared.uploadManager?.attemptAllPending()
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
