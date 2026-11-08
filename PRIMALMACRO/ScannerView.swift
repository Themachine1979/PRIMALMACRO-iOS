import SwiftUI
import PhotosUI
import UIKit

struct ScannerView: View {
    @EnvironmentObject private var store: AppStore
    @State private var scanMode: ScanMode = .food
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var isCameraShown = false
    @State private var isAnalyzing = false
    @State private var foods: [FoodEstimate] = []
    @State private var editing: FoodEstimate?
    @State private var errorMessage: String?

    private var configured: Bool { ScannerService.isReady }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 19) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PRIMAL VISION")
                            .font(.caption2.weight(.heavy)).tracking(2).foregroundStyle(PM.orange)
                        Text("SCAN YOUR FUEL")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                    }
                    Spacer()
                }
                .padding(.top, 20)

                HStack(spacing: 6) {
                    ForEach(ScanMode.allCases) { mode in
                        Button {
                            scanMode = mode; foods = []; errorMessage = nil
                        } label: {
                            Text(mode.rawValue)
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .foregroundStyle(scanMode == mode ? .white : PM.secondary)
                                .background(scanMode == mode ? PM.orange : PM.elevated,
                                            in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                Text(scanMode.explanation)
                    .font(.caption).foregroundStyle(PM.secondary)
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(PM.surface)
                        .frame(height: 290)
                    if let image {
                        Image(uiImage: image)
                            .resizable().scaledToFill()
                            .frame(maxWidth: .infinity).frame(height: 290)
                            .clipped().clipShape(RoundedRectangle(cornerRadius: 20))
                    } else {
                        VStack(spacing: 15) {
                            Image(systemName: "viewfinder")
                                .font(.system(size: 70, weight: .ultraLight))
                                .foregroundStyle(PM.orange)
                            Text("PHOTO YOUR FOOD")
                                .font(.title3.weight(.heavy))
                            Text("Use a clear, well-lit image")
                                .font(.caption).foregroundStyle(PM.secondary)
                        }
                    }
                    VStack {
                        HStack {
                            scanCorner(rotation: 0); Spacer(); scanCorner(rotation: 90)
                        }
                        Spacer()
                        HStack {
                            scanCorner(rotation: -90); Spacer(); scanCorner(rotation: 180)
                        }
                    }
                    .padding(18)
                }
                HStack(spacing: 12) {
                    Button { isCameraShown = true } label: {
                        Label("CAMERA", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .foregroundStyle(.white)
                            .background(PM.orange, in: RoundedRectangle(cornerRadius: 13))
                    }
                    .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("PHOTOS", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .foregroundStyle(.white)
                            .background(PM.elevated, in: RoundedRectangle(cornerRadius: 13))
                    }
                }
                .font(.subheadline.weight(.heavy))

                if !configured {
                    PMPanel {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("AI SCANNER OFFLINE", systemImage: "wifi.slash")
                                .foregroundStyle(PM.orange).font(.subheadline.weight(.heavy))
                            Text("PRIMALMACRO AI is not connected in this build yet. Please update the app when scanning becomes available. No account keys or scanner setup are required.")
                                .font(.caption).foregroundStyle(PM.secondary)
                        }
                    }
                }

                PMLargeButton(title: isAnalyzing ? "ANALYSING PHOTO..." : "ANALYSE WITH AI",
                              icon: "sparkles", enabled: image != nil && !isAnalyzing && configured) {
                    Task { await analyze() }
                }
                if isAnalyzing {
                    ProgressView("Identifying foods and nutritional information")
                        .tint(PM.orange).font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !foods.isEmpty {
                    PMSectionTitle(title: scanMode == .menu ? "Menu Options" : "Scan Results",
                                   subtitle: "Review before adding")
                    ForEach(foods) { food in
                        PMPanel {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(food.name).font(.headline.weight(.heavy))
                                        Text(food.serving).font(.caption).foregroundStyle(PM.secondary)
                                    }
                                    Spacer(minLength: 8)
                                    Text("\(food.calories) kcal")
                                        .font(.subheadline.weight(.heavy)).foregroundStyle(PM.orange)
                                }
                                HStack {
                                    Text("P \(food.proteinG.compactString)g")
                                    Text("C \(food.carbsG.compactString)g")
                                    Text("F \(food.fatG.compactString)g")
                                }
                                .font(.caption.weight(.bold)).foregroundStyle(PM.secondary)
                                Text("Confidence: \(food.confidence.capitalized) • \(food.notes)")
                                    .font(.caption2).foregroundStyle(PM.secondary)
                                Button {
                                    editing = food
                                } label: {
                                    Text("REVIEW & ADD TO DIARY")
                                        .font(.caption.weight(.heavy))
                                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                                        .background(PM.orange, in: RoundedRectangle(cornerRadius: 10))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                }
                PMPanel {
                    Label("CHECK THE NUMBERS", systemImage: "exclamationmark.shield.fill")
                        .font(.caption.weight(.heavy)).foregroundStyle(PM.orange)
                    Text("AI cannot reliably determine ingredients, cooking oils or portion size from an image. Menu items without published nutrition are rough estimates. Confirm before saving.")
                        .font(.caption).foregroundStyle(PM.secondary)
                        .padding(.top, 3)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 35)
        }
        .background(PM.background)
        .sheet(isPresented: $isCameraShown) {
            CameraCapture(image: $image) {
                foods = []; errorMessage = nil
            }
            .ignoresSafeArea()
        }
        .sheet(item: $editing) { estimate in
            FoodEditorView(initial: estimate, onSave: { entry in
                store.addFood(entry)
                editing = nil
            })
        }
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            Task {
                do {
                    guard let data = try await newItem.loadTransferable(type: Data.self),
                          let photo = UIImage(data: data) else {
                        errorMessage = "Unable to read selected photo."; return
                    }
                    image = photo; foods = []; errorMessage = nil
                } catch {
                    errorMessage = "Photo import failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func scanCorner(rotation: Double) -> some View {
        UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 0,
                               bottomTrailingRadius: 0, topTrailingRadius: 0)
        .trim(from: 0, to: 0.48)
        .stroke(PM.orangeLight, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        .frame(width: 30, height: 30)
        .rotationEffect(.degrees(rotation))
    }

    @MainActor
    private func analyze() async {
        guard let image else { return }
        isAnalyzing = true; foods = []; errorMessage = nil
        defer { isAnalyzing = false }
        do {
            let response = try await ScanClient.analyze(image: image, mode: scanMode)
            foods = response.foods
            if foods.isEmpty { errorMessage = "No readable nutrition data found. Try another photo." }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CameraCapture: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onCapture: () -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCapture
        init(_ parent: CameraCapture) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let photo = info[.originalImage] as? UIImage {
                parent.image = photo; parent.onCapture()
            }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
