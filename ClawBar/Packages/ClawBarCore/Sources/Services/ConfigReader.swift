import Foundation

public struct OpenClawConfig: Sendable {
    public let port: Int
    public let gatewayToken: String?
    public let configPath: String

    public init(port: Int, gatewayToken: String?, configPath: String) {
        self.port = port
        self.gatewayToken = gatewayToken
        self.configPath = configPath
    }
}

public enum ConfigReader {
    private static let defaultConfigPath = NSString("~/.openclaw/openclaw.json").expandingTildeInPath
    private static let defaultPort = 18789

    public static func readConfig(path: String? = nil) -> OpenClawConfig {
        let configPath = path ?? defaultConfigPath

        guard let data = FileManager.default.contents(atPath: configPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return OpenClawConfig(port: defaultPort, gatewayToken: nil, configPath: configPath)
        }

        let gateway = json["gateway"] as? [String: Any]

        // Port: gateway.port first, then top-level
        let port: Int
        if let gwPort = gateway?["port"] as? Int {
            port = gwPort
        } else if let topPort = json["port"] as? Int {
            port = topPort
        } else {
            port = defaultPort
        }

        // Gateway auth token
        let gatewayToken: String?
        if let auth = gateway?["auth"] as? [String: Any] {
            gatewayToken = auth["token"] as? String
        } else {
            gatewayToken = nil
        }

        return OpenClawConfig(port: port, gatewayToken: gatewayToken, configPath: configPath)
    }
}
