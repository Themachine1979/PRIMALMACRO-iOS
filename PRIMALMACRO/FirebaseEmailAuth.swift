import Foundation
import Security

// Firebase Authentication REST API handles email verification, password hashing,
// brute-force protection and password reset. No password is stored on the device.
enum EmailAuthFailure: LocalizedError {
    case notConfigured
    case invalidCredentials
    case notVerified
    case weakPassword
    case network
    case keychain

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Email accounts aren't available yet. Please use Sign in with Apple."
        case .invalidCredentials: "Email sign-in failed. Check your email and password."
        case .notVerified: "Please verify your email using the link we sent, then sign in again."
        case .weakPassword: "Use a password with at least 12 characters."
        case .network: "The sign-in service is temporarily unavailable. Please try again."
        case .keychain: "Couldn't securely save the sign-in. Please try again."
        }
    }
}

struct FirebaseCredential: Decodable {
    let idToken: String
    let refreshToken: String
    let localId: String
}

struct StoredEmailCredential: Codable {
    let userID: String
    let refreshToken: String
}

enum EmailCredentialVault {
    private static let service = "uk.themachine1979.primalmacro.email-auth"
    private static let account = "firebase-refresh"
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
    static func load() -> StoredEmailCredential? {
        var q = query
        q[kSecReturnData as String] = true
        var output: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &output) == errSecSuccess,
              let data = output as? Data else { return nil }
        return try? JSONDecoder().decode(StoredEmailCredential.self, from: data)
    }
    static func save(_ credentials: FirebaseCredential) throws {
        let stored = StoredEmailCredential(userID: credentials.localId,
                                           refreshToken: credentials.refreshToken)
        guard let data = try? JSONEncoder().encode(stored) else { throw EmailAuthFailure.keychain }
        clear()
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
            throw EmailAuthFailure.keychain
        }
    }
    static func clear() {
        SecItemDelete(query as CFDictionary)
    }
}

enum FirebaseEmailAuth {
    static var apiKey: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "PMFirebaseAPIKey") as? String,
              value.count >= 15, !value.contains("PLACEHOLDER"),
              !value.contains("$("), !value.contains("/") else { return nil }
        return value
    }
    static var isConfigured: Bool { apiKey != nil }

    private struct FirebaseProblem: Decodable {
        struct Detail: Decodable { let message: String? }
        let error: Detail?
    }
    private struct LookupResult: Decodable {
        struct User: Decodable { let emailVerified: Bool? }
        let users: [User]?
    }
    private struct RefreshResult: Decodable {
        let id_token: String
        let refresh_token: String
        let user_id: String
    }

    private static func request<Response: Decodable>(_ action: String, data: [String: Any]) async throws -> Response {
        guard let key = apiKey,
              let url = URL(string: "https://identitytoolkit.googleapis.com/v1/" + action + "?key=" + key),
              let json = try? JSONSerialization.data(withJSONObject: data) else {
            throw EmailAuthFailure.notConfigured
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = json
        req.timeoutInterval = 20
        let payload: Data
        let response: URLResponse
        do {
            (payload, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw EmailAuthFailure.network
        }
        guard let status = (response as? HTTPURLResponse)?.statusCode else { throw EmailAuthFailure.network }
        if status != 200 {
            let code = (try? JSONDecoder().decode(FirebaseProblem.self, from: payload))?.error?.message ?? ""
            switch code {
            case "WEAK_PASSWORD": throw EmailAuthFailure.weakPassword
            case "INVALID_PASSWORD", "EMAIL_NOT_FOUND", "INVALID_LOGIN_CREDENTIALS", "USER_DISABLED":
                throw EmailAuthFailure.invalidCredentials
            default: throw EmailAuthFailure.network
            }
        }
        guard let result = try? JSONDecoder().decode(Response.self, from: payload) else {
            throw EmailAuthFailure.network
        }
        return result
    }

    static func register(email: String, password: String) async throws {
        guard password.count >= 12 else { throw EmailAuthFailure.weakPassword }
        let credential: FirebaseCredential = try await request("accounts:signUp",
            data: ["email": email, "password": password, "returnSecureToken": true])
        let _: LookupResult = try await request("accounts:sendOobCode",
            data: ["requestType": "VERIFY_EMAIL", "idToken": credential.idToken])
    }

    static func resendVerification(email: String, password: String) async throws {
        let credential: FirebaseCredential = try await request("accounts:signInWithPassword",
            data: ["email": email, "password": password, "returnSecureToken": true])
        let _: LookupResult = try await request("accounts:sendOobCode",
            data: ["requestType": "VERIFY_EMAIL", "idToken": credential.idToken])
    }

    static func login(email: String, password: String) async throws -> FirebaseCredential {
        let credential: FirebaseCredential = try await request("accounts:signInWithPassword",
            data: ["email": email, "password": password, "returnSecureToken": true])
        try await requireVerified(idToken: credential.idToken)
        return credential
    }

    static func requireVerified(idToken: String) async throws {
        let info: LookupResult = try await request("accounts:lookup",
            data: ["idToken": idToken])
        guard info.users?.first?.emailVerified == true else { throw EmailAuthFailure.notVerified }
    }

    static func sendPasswordReset(email: String) async {
        // Deliberately don't reveal whether an email address is registered.
        let _: LookupResult? = try? await request("accounts:sendOobCode",
            data: ["requestType": "PASSWORD_RESET", "email": email])
    }

    static func refresh(_ stored: StoredEmailCredential) async throws -> FirebaseCredential {
        guard let key = apiKey,
              let url = URL(string: "https://securetoken.googleapis.com/v1/token?key=" + key) else {
            throw EmailAuthFailure.notConfigured
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let encoded = stored.refreshToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        request.httpBody = Data("grant_type=refresh_token&refresh_token=\(encoded)".utf8)
        request.timeoutInterval = 20
        let (data, response): (Data, URLResponse)
        do { (data, response) = try await URLSession.shared.data(for: request) }
        catch { throw EmailAuthFailure.network }
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let refreshed = try? JSONDecoder().decode(RefreshResult.self, from: data),
              refreshed.user_id == stored.userID else { throw EmailAuthFailure.invalidCredentials }
        try await requireVerified(idToken: refreshed.id_token)
        return FirebaseCredential(idToken: refreshed.id_token,
                                  refreshToken: refreshed.refresh_token,
                                  localId: refreshed.user_id)
    }

    static func deleteAccount(idToken: String) async throws {
        struct Empty: Decodable {}
        let _: Empty = try await request("accounts:delete", data: ["idToken": idToken])
    }
}
