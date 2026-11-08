import UIKit
import Foundation

// The service URL is public; the OpenAI API key is NEVER bundled with the iPhone app.
// Codemagic injects the URL into the generated Info.plist at build time.
enum ScannerService {
    static var endpoint: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "PMScannerEndpoint") as? String,
              let url = URL(string: raw),
              url.scheme == "https",
              url.host != nil,
              url.path.hasSuffix("/scan") else { return nil }
        return url
    }

    static var isReady: Bool { endpoint != nil }
}

enum ScanError: LocalizedError {
    case serviceUnavailable
    case imagePreparation
    case rateLimited
    case server(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .serviceUnavailable: "AI scanning is temporarily unavailable."
        case .imagePreparation: "Could not prepare the photo."
        case .rateLimited: "Too many scans right now. Please try again shortly."
        case .server(let code): "AI service error \(code). Please try again."
        case .invalidResponse: "Could not read the nutrition analysis."
        }
    }
}

enum ScanClient {
    static func analyze(image: UIImage, mode: ScanMode) async throws -> FoodScanResponse {
        guard let url = ScannerService.endpoint else { throw ScanError.serviceUnavailable }
        let maxDim: CGFloat = 1400
        let ratio = min(1, maxDim / max(image.size.width, image.size.height))
        let targetSize = CGSize(width: max(1, image.size.width * ratio),
                                height: max(1, image.size.height * ratio))
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let jpeg = resized.jpegData(compressionQuality: 0.78),
              jpeg.count < 8_000_000 else { throw ScanError.imagePreparation }

        struct ScanRequest: Encodable {
            let mode: String
            let imageBase64: String
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45
        request.httpBody = try JSONEncoder().encode(
            ScanRequest(mode: mode.rawValue.lowercased(),
                        imageBase64: jpeg.base64EncodedString())
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ScanError.invalidResponse }
        if http.statusCode == 429 { throw ScanError.rateLimited }
        if http.statusCode == 503 { throw ScanError.serviceUnavailable }
        guard http.statusCode == 200 else { throw ScanError.server(http.statusCode) }
        do {
            return try JSONDecoder().decode(FoodScanResponse.self, from: data)
        } catch {
            throw ScanError.invalidResponse
        }
    }
}
