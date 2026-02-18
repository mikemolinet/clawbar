import CryptoKit
import Foundation
import Security

public struct DeviceIdentity: Sendable {
    public let deviceId: String
    public let publicKeyBase64: String
    public let privateKey: Curve25519.Signing.PrivateKey

    public init(deviceId: String, publicKeyBase64: String, privateKey: Curve25519.Signing.PrivateKey) {
        self.deviceId = deviceId
        self.publicKeyBase64 = publicKeyBase64
        self.privateKey = privateKey
    }

    /// Sign a message with the device's private key, returning base64-encoded signature
    public func sign(_ message: String) throws -> String {
        let data = Data(message.utf8)
        let signature = try privateKey.signature(for: data)
        // signature is Data in Swift 6 CryptoKit
        return (signature as AnyObject as? Data ?? Data(signature)).base64EncodedString()
    }

    /// Build the challenge signing message per OpenClaw protocol
    public func buildSigningMessage(
        nonce: String,
        timestamp: Int64,
        token: String? = nil
    ) -> String {
        let scopes = "operator.admin,operator.approvals,operator.pairing"
        let tokenStr = token ?? ""
        return "v2|\(deviceId)|openclaw-macos|webchat|operator|\(scopes)|\(timestamp)|\(tokenStr)|\(nonce)"
    }
}

public enum DeviceIdentityManager {
    private static let keychainService = "com.vector.clawbar.device-identity"
    private static let keychainAccount = "device-key"

    /// Load or create a persistent device identity
    public static func loadOrCreate() throws -> DeviceIdentity {
        if let existing = try? loadFromKeychain() {
            return existing
        }
        let identity = try createNew()
        try saveToKeychain(identity)
        return identity
    }

    /// Delete stored identity (for re-pairing)
    public static func deleteIdentity() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func createNew() throws -> DeviceIdentity {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        let publicKeyBytes = publicKey.rawRepresentation
        let publicKeyBase64 = publicKeyBytes.base64EncodedString()

        // Device ID = hex-encoded SHA-256 of public key bytes
        let hash = SHA256.hash(data: publicKeyBytes)
        let deviceId = hash.map { String(format: "%02x", $0) }.joined()

        return DeviceIdentity(
            deviceId: deviceId,
            publicKeyBase64: publicKeyBase64,
            privateKey: privateKey
        )
    }

    private static func loadFromKeychain() throws -> DeviceIdentity {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw ClawBarError.openClawNotPaired
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let privateKeyBase64 = json["privateKey"] as? String,
              let publicKeyBase64 = json["publicKey"] as? String,
              let deviceId = json["deviceId"] as? String,
              let privateKeyData = Data(base64Encoded: privateKeyBase64)
        else {
            throw ClawBarError.openClawAuthFailed("Corrupted device identity")
        }

        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData)

        return DeviceIdentity(
            deviceId: deviceId,
            publicKeyBase64: publicKeyBase64,
            privateKey: privateKey
        )
    }

    private static func saveToKeychain(_ identity: DeviceIdentity) throws {
        let json: [String: Any] = [
            "deviceId": identity.deviceId,
            "publicKey": identity.publicKeyBase64,
            "privateKey": identity.privateKey.rawRepresentation.base64EncodedString(),
        ]

        let data = try JSONSerialization.data(withJSONObject: json)

        // Delete any existing
        deleteIdentity()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw ClawBarError.openClawAuthFailed("Failed to save device identity to Keychain")
        }
    }
}
