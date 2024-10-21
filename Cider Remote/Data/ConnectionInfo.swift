// Made by Lumaa

import Foundation

struct ConnectionInfo: Codable {
    let address: String
    let token: String
    let method: ConnectionMethod
    let initialData: InitialData
}

enum ConnectionMethod: String, Codable {
    case lan
    case tunnel
}

struct InitialData: Codable {
    let version: String
    let platform: String
    let os: String
    
    // We'll use CodingKeys to handle the missing 'arch' field
    enum CodingKeys: String, CodingKey {
        case version, platform, os
    }
    
    // Custom initializer to set a default value for 'arch'
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(String.self, forKey: .version)
        platform = try container.decode(String.self, forKey: .platform)
        os = try container.decode(String.self, forKey: .os)
    }
}
