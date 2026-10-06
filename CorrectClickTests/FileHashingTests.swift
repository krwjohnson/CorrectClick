import XCTest

final class FileHashingTests: XCTestCase {

    // Known test vectors — matches what `md5`/`shasum -a 256` on the CLI
    // produce for the same input, per the requirements doc's suggestion to
    // use those tools as a test oracle.

    func testKnownVectorABC() {
        let digests = FileHashing.digests(for: Data("abc".utf8))
        XCTAssertEqual(digests.md5, "900150983cd24fb0d6963f7d28e17f72")
        XCTAssertEqual(digests.sha256, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    func testEmptyData() {
        let digests = FileHashing.digests(for: Data())
        XCTAssertEqual(digests.md5, "d41d8cd98f00b204e9800998ecf8427e")
        XCTAssertEqual(digests.sha256, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    func testDigestsAreLowercaseHex() {
        let digests = FileHashing.digests(for: Data("test".utf8))
        XCTAssertEqual(digests.md5, digests.md5.lowercased())
        XCTAssertEqual(digests.md5.count, 32)
        XCTAssertEqual(digests.sha256, digests.sha256.lowercased())
        XCTAssertEqual(digests.sha256.count, 64)
    }

    func testDifferentInputsProduceDifferentDigests() {
        let a = FileHashing.digests(for: Data("a".utf8))
        let b = FileHashing.digests(for: Data("b".utf8))
        XCTAssertNotEqual(a.md5, b.md5)
        XCTAssertNotEqual(a.sha256, b.sha256)
    }
}
