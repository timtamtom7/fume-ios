import SwiftUI
import PhotosUI

struct AddContentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AddContentViewModel()
    @State private var selectedTab: AddContentTab = .note
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    enum AddContentTab: String, CaseIterable {
        case note = "Note"
        case url = "URL"
        case voice = "Voice"
        case image = "Image"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FumeColors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Tab Picker
                    tabPicker

                    Divider()
                        .background(FumeColors.divider)

                    // Content
                    ScrollView {
                        VStack(spacing: 20) {
                            switch selectedTab {
                            case .note:
                                noteContent
                            case .url:
                                urlContent
                            case .voice:
                                voiceContent
                            case .image:
                                imageContent
                            }
                        }
                        .padding(16)
                    }

                    // Processing Overlay
                    if viewModel.isProcessing {
                        processingOverlay
                    }
                }
            }
            .navigationTitle("Add Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(FumeColors.textSecondary)
                }
            }
            .onChange(of: viewModel.didSave) { _, didSave in
                if didSave {
                    dismiss()
                }
            }
            .onChange(of: selectedPhotoItem) { _, item in
                if let item = item {
                    loadPhoto(from: item)
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraView { image in
                    Task {
                        await viewModel.processImage(image)
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }

    // MARK: - Tab Picker
    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(AddContentTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                        viewModel.reset()
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundStyle(selectedTab == tab ? FumeColors.accent : FumeColors.textSecondary)

                        Rectangle()
                            .fill(selectedTab == tab ? FumeColors.accent : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Note Content
    private var noteContent: some View {
        VStack(spacing: 16) {
            TextField("Title (optional)", text: $viewModel.noteTitle)
                .font(.system(size: 15))
                .foregroundStyle(FumeColors.textPrimary)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(FumeColors.surfaceRaised)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(FumeColors.border, lineWidth: 0.5)
                        )
                )

            TextEditor(text: $viewModel.noteText)
                .font(.system(size: 15))
                .foregroundStyle(FumeColors.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 200)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(FumeColors.surfaceRaised)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(FumeColors.border, lineWidth: 0.5)
                        )
                )
                .overlay(alignment: .topLeading) {
                    if viewModel.noteText.isEmpty {
                        Text("Write your note here...")
                            .font(.system(size: 15))
                            .foregroundStyle(FumeColors.textSecondary.opacity(0.6))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }

            saveButton(
                isEnabled: !viewModel.noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                Task { await viewModel.saveNote() }
            }
        }
    }

    // MARK: - URL Content
    private var urlContent: some View {
        VStack(spacing: 16) {
            TextField("Paste article URL...", text: $viewModel.urlText)
                .font(.system(size: 15))
                .foregroundStyle(FumeColors.textPrimary)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(FumeColors.surfaceRaised)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(FumeColors.border, lineWidth: 0.5)
                        )
                )

            Text("Fume will fetch and store the article content locally.")
                .font(.system(size: 13))
                .foregroundStyle(FumeColors.textSecondary)

            saveButton(
                isEnabled: !viewModel.urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                Task { await viewModel.saveURL() }
            }
        }
    }

    // MARK: - Voice Content
    private var voiceContent: some View {
        VStack(spacing: 24) {
            if viewModel.recognizedText.isEmpty {
                // Recording UI
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(FumeColors.surfaceRaised)
                            .frame(width: 120, height: 120)

                        Circle()
                            .fill(viewModel.isRecording ? FumeColors.accent.opacity(0.2) : FumeColors.surface)
                            .frame(width: viewModel.isRecording ? 140 : 120, height: viewModel.isRecording ? 140 : 120)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: viewModel.isRecording)

                        Image(systemName: viewModel.isRecording ? "waveform" : "mic.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(viewModel.isRecording ? FumeColors.accent : FumeColors.textSecondary)
                    }

                    VStack(spacing: 8) {
                        Text(viewModel.isRecording ? "Recording..." : "Tap to record")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(FumeColors.textPrimary)

                        Text(viewModel.isRecording ? "Tap again to stop" : "Your voice will be transcribed")
                            .font(.system(size: 14))
                            .foregroundStyle(FumeColors.textSecondary)
                    }

                    Button {
                        if viewModel.isRecording {
                            Task { await viewModel.stopRecording() }
                        } else {
                            Task { await viewModel.startRecording() }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                            Text(viewModel.isRecording ? "Stop" : "Start Recording")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FumeColors.background)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(viewModel.isRecording ? FumeColors.textSecondary : FumeColors.accent)
                        )
                    }

                    if viewModel.isRecording && !viewModel.recordingTranscript.isEmpty {
                        Text(viewModel.recordingTranscript)
                            .font(.system(size: 13))
                            .foregroundStyle(FumeColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 20)
            } else {
                // Review & Save UI
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(FumeColors.accent)
                        Text("Transcription Complete")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(FumeColors.textPrimary)
                    }

                    Text(viewModel.recognizedText)
                        .font(.system(size: 14))
                        .foregroundStyle(FumeColors.textSecondary)
                        .lineLimit(10)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(FumeColors.surfaceRaised)
                        )
                }

                HStack(spacing: 12) {
                    Button {
                        viewModel.recognizedText = ""
                    } label: {
                        Text("Discard")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(FumeColors.textSecondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .stroke(FumeColors.border, lineWidth: 1)
                            )
                    }

                    Button {
                        Task { await viewModel.saveVoiceMemo() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FumeColors.background)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(FumeColors.accent)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Image Content
    private var imageContent: some View {
        VStack(spacing: 20) {
            if let image = viewModel.capturedImage {
                // Review & OCR UI
                VStack(spacing: 16) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(16)

                    if !viewModel.recognizedText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "text.viewfinder")
                                    .foregroundStyle(FumeColors.accent)
                                Text("Recognized Text")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(FumeColors.textSecondary)
                            }

                            Text(viewModel.recognizedText)
                                .font(.system(size: 13))
                                .foregroundStyle(FumeColors.textPrimary)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(FumeColors.surfaceRaised)
                                )
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            viewModel.capturedImage = nil
                            viewModel.recognizedText = ""
                        } label: {
                            Text("Discard")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(FumeColors.textSecondary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .stroke(FumeColors.border, lineWidth: 1)
                                )
                        }

                        Button {
                            Task { await viewModel.saveOCRText() }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.down")
                                Text("Save")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(FumeColors.background)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(FumeColors.accent)
                            )
                        }
                    }
                }
            } else {
                // Capture Options
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        captureButton(
                            icon: "camera.fill",
                            label: "Camera"
                        ) {
                            showCamera = true
                        }

                        captureButton(
                            icon: "photo.fill",
                            label: "Photo Library"
                        ) {
                            showPhotoPicker = true
                        }
                    }
                }
                .padding(.top, 20)
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
    }

    // MARK: - Components
    private func captureButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(FumeColors.accent)

                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(FumeColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(FumeColors.glassOverlay)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(FumeColors.border, lineWidth: 0.5)
                    )
            )
        }
    }

    private func saveButton(isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.down")
                Text("Save")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(isEnabled ? FumeColors.background : FumeColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(isEnabled ? FumeColors.accent : FumeColors.surfaceRaised)
            )
        }
        .disabled(!isEnabled)
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .tint(FumeColors.accent)
                    .scaleEffect(1.2)

                Text(viewModel.processingMessage)
                    .font(.system(size: 14))
                    .foregroundStyle(FumeColors.textPrimary)
            }
            .padding(32)
            .glassCard()
        }
    }

    private func loadPhoto(from item: PhotosPickerItem) {
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await viewModel.processImage(image)
            }
        }
    }
}

// MARK: - Camera View
struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
