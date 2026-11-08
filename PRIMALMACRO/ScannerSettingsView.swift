import SwiftUI

struct ScannerSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("scannerURL") private var storedURL = ""
    @State private var url = ""
    @State private var accessToken = ""
    @State private var showToken = false
    @State private var saveFailed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PMPanel {
                        VStack(alignment: .leading, spacing: 9) {
                            Label("SECURE SCANNING", systemImage: "lock.shield.fill")
                                .font(.headline).foregroundStyle(PM.orange)
                            Text("To recognise food, deploy the included Cloudflare Worker and enter its HTTPS endpoint and private access token here. The OpenAI API key must stay on the Worker, never in the iOS app.")
                                .font(.subheadline).foregroundStyle(PM.secondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        Text("SCANNER URL").font(.caption.weight(.bold)).foregroundStyle(PM.secondary)
                        TextField("https://your-worker.workers.dev/scan", text: $url)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(13)
                            .background(PM.elevated, in: RoundedRectangle(cornerRadius: 12))
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        Text("PRIVATE ACCESS TOKEN").font(.caption.weight(.bold)).foregroundStyle(PM.secondary)
                        HStack {
                            Group {
                                if showToken { TextField("Access token", text: $accessToken) }
                                else { SecureField("Access token", text: $accessToken) }
                            }
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            Button { showToken.toggle() } label: {
                                Image(systemName: showToken ? "eye.slash" : "eye")
                            }
                        }
                        .padding(13)
                        .background(PM.elevated, in: RoundedRectangle(cornerRadius: 12))
                    }
                    Text("The token is stored in the iOS Keychain. Do not reuse your Apple, Cloudflare or OpenAI password as this token.")
                        .font(.caption).foregroundStyle(PM.secondary)
                    PMLargeButton(title: "SAVE SCANNER SETTINGS", icon: "checkmark.shield", enabled: isValid) {
                        if KeychainStore.saveToken(accessToken.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            storedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
                            dismiss()
                        } else { saveFailed = true }
                    }
                }
                .padding(18)
            }
            .background(PM.background)
            .navigationTitle("AI scanner settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
            .alert("Could not save token", isPresented: $saveFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The iOS Keychain did not accept the token.")
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { url = storedURL; accessToken = KeychainStore.readToken() ?? "" }
    }

    private var isValid: Bool {
        guard let parsed = URL(string: url), parsed.scheme == "https", parsed.host != nil else { return false }
        return !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
