import CryptoKit
import Foundation

/// MD5 + SHA-256 for the "Copy File Hash" action (Epic 5). `Insecure.MD5` is
/// CryptoKit's own name for it — MD5 is cryptographically broken, but it's
/// still what the doc asks for and what most "verify a download" workflows
/// still expect alongside SHA-256, so it's included deliberately, not by
/// oversight.
enum FileHashing {

    struct Digests: Equatable {
        let md5: String
        let sha256: String
    }

    static func digests(for data: Data) -> Digests {
        Digests(md5: hexString(Insecure.MD5.hash(data: data)), sha256: hexString(SHA256.hash(data: data)))
    }

    private static func hexString(_ digest: some Sequence<UInt8>) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}
