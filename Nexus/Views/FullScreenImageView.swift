//
//  FullScreenImageView.swift
//  Nexus
//
//  Created by Codex on 09/23/25.
//

import SwiftUI
import Photos

struct FullScreenImageView: View {
    let uiImage: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var saving: Bool = false
    @State private var saveResult: String? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            GeometryReader { _ in
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(radius: 2)
                    }
                    Spacer()
                    Button {
                        Task { await saveToPhotos() }
                    } label: {
                        if saving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Label("Save", systemImage: "square.and.arrow.down")
                                .labelStyle(.titleAndIcon)
                                .foregroundStyle(.white.opacity(0.95))
                        }
                    }
                }
                .padding()
                Spacer()
            }

            if let msg = saveResult {
                Text(msg)
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .foregroundStyle(.white)
                    .padding(.bottom, 40)
                    .transition(.opacity)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .statusBar(hidden: true)
    }

    private func saveToPhotos() async {
        await MainActor.run { saving = true; saveResult = nil }

        let save: () async -> Void = {
            await withCheckedContinuation { cont in
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
                }) { success, error in
                    Task { @MainActor in
                        saving = false
                        if success { saveResult = "Saved to Photos" }
                        else { saveResult = "Couldn't save: \(error?.localizedDescription ?? "Unknown error")" }
                        // Auto-hide the toast
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                            withAnimation { saveResult = nil }
                        }
                        cont.resume()
                    }
                }
            }
        }

        if #available(iOS 14, *) {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            switch status {
            case .authorized, .limited: await save()
            default:
                await MainActor.run {
                    saving = false
                    saveResult = "Photos access denied"
                }
            }
        } else {
            // Fallback for older iOS versions
            PHPhotoLibrary.requestAuthorization { status in
                Task { await MainActor.run { saving = false } }
            }
        }
    }
}

