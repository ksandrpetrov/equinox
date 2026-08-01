import Foundation
import Security

enum SecureRandomBytes {
    enum GenerationError: Error, Equatable {
        case invalidCount
        case failed(OSStatus)
    }

    static func generate(count: Int) throws -> Data {
        guard count >= 0 else { throw GenerationError.invalidCount }

        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else {
            throw GenerationError.failed(status)
        }
        return Data(bytes)
    }
}
