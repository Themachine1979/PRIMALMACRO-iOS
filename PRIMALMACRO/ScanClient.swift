import Foundation
import Security
import UIKit

enum ScannerService {
    static var endpoint: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "PMScannerEndpoint") as? String,
              let url = URL(string: raw), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil, url.path == "/scan",
              url.query == nil, url.fragment == nil else { return nil }
        return url
    }
}

struct ScannerSession: Codable {
    let token: String
    let expiresAt: TimeInterval

    private static let key: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "uk.themachine1979.primalmacro.scanner",
        kSecAttrAccount as String: "session"
    ]

    static func load() -> Self? {
        var query = key
        query[kSecReturnData as String] = true
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let session = try? JSONDecoder().decode(Self.self, from: data),
              session.expiresAt > Date().timeIntervalSince1970 else { return nil }
        return session
    }

    func save() throws {
        Self.clear()
        var item = Self.key
        item[kSecValueData as String] = try JSONEncoder().encode(self)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
            throw ScanError.sessionStorage
        }
    }

    static func clear() {
        SecItemDelete(key as CFDictionary)
    }
}

enum ScanError: LocalizedError {
    case serviceUnavailable
    case imagePreparation
    case rateLimited
    case signInRequired
    case subscriptionRequired
    case sessionStorage
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .serviceUnavailable: "AI scanning is temporarily unavailable. Please try again later."
        case .imagePreparation: "Could not prepare the photo. Try a different image."
        case .rateLimited: "The scan limit has been reached. Please try again later."
        case .signInRequired: "Confirm your Apple sign-in to continue scanning."
        case .subscriptionRequired: "AI scanning needs an active PRIMALMACRO subscription linked to this Apple sign-in."
        case .sessionStorage: "Could not save your scanner sign-in. Please try again."
        case .invalidResponse: "Could not read the nutrition analysis. Please try again."
        }
    }
}

enum ScanClient {
    private struct Challenge: Decodable { let nonce: String }

    static func challenge() async throws -> String {
        let response: Challenge = try await post("challenge", body: nil)
        return response.nonce
    }

    static func session(identityToken: String, nonce: String) async throws -> ScannerSession {
        try await post("session", body: JSONEncoder().encode(["identityToken": identityToken, "nonce": nonce]))
    }

    @MainActor
    static func analyze(image: UIImage, mode: ScanMode, transactionID: UInt64,
                        session: ScannerSession) async throws -> FoodScanResponse {
        let maxDim: CGFloat = 1400
        let ratio = min(1, maxDim / max(image.size.width, image.size.height))
        let targetSize = CGSize(width: max(1, (image.size.width * ratio).rounded(.down)),
                                height: max(1, (image.size.height * ratio).rounded(.down)))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let jpeg = resized.jpegData(compressionQuality: 0.78),
              jpeg.count <= 2_000_000 else { throw ScanError.imagePreparation }

        let body = try JSONEncoder().encode([
            "mode": mode.rawValue.lowercased(),
            "imageBase64": jpeg.base64EncodedString(),
            "transactionID": String(transactionID)
        ])
        return try await post("scan", body: body, token: session.token)
    }

    private static func post<Response: Decodable>(_ route: String, body: Data?,
                                                   token: String? = nil) async throws -> Response {
        guard let url = ScannerService.endpoint else { throw ScanError.serviceUnavailable }
        var request = URLRequest(url: url.deletingLastPathComponent().appendingPathComponent(route))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.timeoutInterval = 55
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        switch (response as? HTTPURLResponse)?.statusCode {
        case 200:
            do { return try JSONDecoder().decode(Response.self, from: data) }
            catch { throw ScanError.invalidResponse }
        case 401: throw ScanError.signInRequired
        case 403: throw ScanError.subscriptionRequired
        case 429: throw ScanError.rateLimited
        default: throw ScanError.serviceUnavailable
        }
    }
}
