import UIKit
import Foundation
import Security

enum ScanError: LocalizedError {
    case invalidEndpoint
    case imagePreparation
    case unauthorized
    case server(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint: "Enter a valid HTTPS service URL in scanner settings."
        case .imagePreparation: "Could not prepare the image for scanning."
        case .unauthorized: "Scanner access denied. Check the access token in settings."
        case .server(let code): "Scanner service returned HTTP \(code). Try again."
        case .invalidResponse: "Scanner response could not be read. Try again."
        }
    }
}

enum ScanClient {
    static func analyze(image: UIImage, mode: ScanMode, endpoint: String, token: String) async throws -> FoodScanResponse {
        guard let url = URL(string: endpoint), url.scheme == "https", url.host != nil else {
            throw ScanError.invalidEndpoint
        }
        guard !token.isEmpty else { throw ScanError.unauthorized }
        let maxDim: CGFloat = 1400
        let ratio = min(1, maxDim / max(image.size.width, image.size.height))
        let targetSize = CGSize(width: max(1, image.size.width * ratio),
                                height: max(1, image.size.height * ratio))
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: targetSize)) }
        guard let jpeg = resized.jpegData(compressionQuality: 0.78), jpeg.count < 8_000_000 else {
            throw ScanError.imagePreparation
        }

        struct Request: Encodable {
            let mode: String
            let imageBase64: String
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 45
        request.httpBody = try JSONEncoder().encode(Request(mode: mode.rawValue.lowercased(),
                                                            imageBase64: jpeg.base64EncodedString()))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ScanError.invalidResponse }
        if http.statusCode == 401 || http.statusCode == 403 { throw ScanError.unauthorized }
        guard http.statusCode == 200 else { throw ScanError.server(http.statusCode) }
        do { return try JSONDecoder().decode(FoodScanResponse.self, from: data) }
        catch { throw ScanError.invalidResponse }
    }
}

enum KeychainStore {
    private static let service = "uk.primalmacro.private-scanner"
    private static let account = "scanner-access-token"

    static func readToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func saveToken(_ token: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        if token.isEmpty { return true }
        var attrs = query
        attrs[kSecValueData as String] = Data(token.utf8)
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(attrs as CFDictionary, nil) == errSecSuccess
    }
}
