import SwiftUI
import PhotosUI
import AuthenticationServices
import UIKit

struct ScannerView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var member: AppleMemberSession
    @EnvironmentObject private var plans: MembershipPlans
    @State private var session: ScannerSession?
    @State private var nonce: String?
    @State private var challengeDate: Date?
    @AppStorage("primalmacro.ai.photoConsent") private var photoConsent = false
    @State private var showPhotoConsent = false
    @State private var confirming = false
    @State private var importingPhoto = false
    @State private var disclaimer: String?
    @State private var scanMode: ScanMode = .food
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var isCameraShown = false
    @State private var isAnalyzing = false
    @State private var foods: [FoodEstimate] = []
    @State private var editing: FoodEstimate?
    @State private var errorMessage: String?

    private var configured: Bool { ScannerService.endpoint != nil }
    private var canScan: Bool {
        guard let token = member.accountToken else { return false }
        return plans.scanTransaction(for: token) != nil
    }

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
                            scanMode = mode
                            resetResults()
                        } label: {
                            Text(mode.rawValue)
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(scanMode == mode ? .white : PM.secondary)
                                .background(scanMode == mode ? PM.orange : PM.elevated,
                                            in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .disabled(isAnalyzing)
                Text(scanMode.explanation)
                    .font(.caption).foregroundStyle(PM.secondary)
                RoundedRectangle(cornerRadius: 20)
                    .fill(PM.surface)
                    .frame(height: 290)
                    .overlay {
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
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
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay {
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
                        .allowsHitTesting(false)
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
                .disabled(isAnalyzing || importingPhoto)

                if !configured {
                    PMPanel {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("AI SCANNER OFFLINE", systemImage: "wifi.slash")
                                .foregroundStyle(PM.orange).font(.subheadline.weight(.heavy))
                            Text("AI scanning is temporarily unavailable. You can still add food manually in your diary.")
                                .font(.caption).foregroundStyle(PM.secondary)
                        }
                    }
                }

                if configured && !canScan {
                    Text(ScanError.subscriptionRequired.localizedDescription)
                        .font(.footnote).foregroundStyle(PM.secondary)
                } else if configured && session == nil {
                    if let nonce {
                        SignInWithAppleButton(.continue, onRequest: { request in
                            request.nonce = nonce
                        }, onCompletion: { result in
                            Task { await confirm(result, nonce: nonce) }
                        })
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 52)
                        .disabled(confirming)
                        Text("Confirm your Apple sign-in to unlock AI scanning.")
                            .font(.footnote).foregroundStyle(PM.secondary)
                    } else {
                        PMLargeButton(title: "ENABLE AI SCANNING", icon: "lock.open", enabled: !confirming) {
                            Task { await prepareSignIn() }
                        }
                    }
                } else if configured {
                    Text("Analyse with AI sends this photo to OpenAI for nutrition analysis.")
                        .font(.footnote).foregroundStyle(PM.secondary)
                    PMLargeButton(title: isAnalyzing ? "ANALYSING PHOTO..." : "ANALYSE WITH AI",
                                  icon: "sparkles", enabled: image != nil && !isAnalyzing && !importingPhoto) {
                        if photoConsent {
                            Task { await analyze() }
                        } else {
                            showPhotoConsent = true
                        }
                    }
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
                    if let disclaimer {
                        Text(disclaimer).font(.caption).foregroundStyle(PM.secondary)
                    }
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
        .alert("Send this photo to OpenAI?", isPresented: $showPhotoConsent) {
            Button("Allow and analyse") {
                photoConsent = true
                Task { await analyze() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("When you choose Analyse with AI, PRIMALMACRO shares the selected photo with OpenAI to estimate nutrition. You can add food manually at any time.")
        }
        .fullScreenCover(isPresented: $isCameraShown) {
            CameraCapture(image: $image, onCapture: resetResults)
        }
        .sheet(item: $editing) { estimate in
            FoodEditorView(initial: estimate, onSave: { entry in
                store.addFood(entry)
                editing = nil
            })
        }
        .task {
            session = ScannerSession.load()
        }
        .task(id: selectedPhoto) {
            guard let item = selectedPhoto else { return }
            importingPhoto = true
            defer { importingPhoto = false }
            resetResults()
            image = nil
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let photo = UIImage(data: data) else {
                    errorMessage = "Unable to read selected photo."
                    return
                }
                try Task.checkCancellation()
                image = photo
            } catch is CancellationError {
                return
            } catch {
                errorMessage = "Photo import failed. Please try another image."
            }
        }
    }

    private func resetResults() {
        foods = []
        disclaimer = nil
        errorMessage = nil
    }

    @MainActor
    private func prepareSignIn() async {
        guard !confirming else { return }
        confirming = true
        defer { confirming = false }
        errorMessage = nil
        do {
            nonce = try await ScanClient.challenge()
            challengeDate = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func confirm(_ result: Result<ASAuthorization, Error>, nonce: String) async {
        guard !confirming else { return }
        confirming = true
        defer { confirming = false }
        self.nonce = nil
        errorMessage = nil
        do {
            guard let challengeDate, Date().timeIntervalSince(challengeDate) < 300 else {
                throw ScanError.signInRequired
            }
            let authorization = try result.get()
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  credential.user == member.userID, let token = credential.identityToken,
                  let identityToken = String(data: token, encoding: .utf8) else {
                throw ScanError.signInRequired
            }
            let verified = try await ScanClient.session(identityToken: identityToken, nonce: nonce)
            guard member.signedIn, credential.user == member.userID else { return }
            try verified.save()
            session = verified
        } catch {
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
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
        guard !isAnalyzing, !importingPhoto, let image, let session,
              let token = member.accountToken else { return }
        guard let transaction = plans.scanTransaction(for: token) else {
            errorMessage = ScanError.subscriptionRequired.localizedDescription
            return
        }
        isAnalyzing = true
        resetResults()
        defer { isAnalyzing = false }
        do {
            let response = try await ScanClient.analyze(image: image, mode: scanMode,
                                                        transactionID: transaction.originalID, session: session)
            foods = response.foods
            disclaimer = response.disclaimer
            if foods.isEmpty { errorMessage = "No readable nutrition data found. Try another photo." }
        } catch ScanError.signInRequired {
            ScannerSession.clear()
            self.session = nil
            errorMessage = ScanError.signInRequired.localizedDescription
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
