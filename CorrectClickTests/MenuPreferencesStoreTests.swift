import XCTest

final class MenuPreferencesStoreTests: XCTestCase {

    private var fileURL: URL!
    private var store: MenuPreferencesStore!

    override func setUpWithError() throws {
        fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        store = MenuPreferencesStore(fileURL: fileURL)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testRegistryIDsAreUnique() {
        let ids = BuiltInMenuItems.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Duplicate id in BuiltInMenuItems.all")
    }

    func testLoadWithNoSavedFileDefaultsEveryItemEnabled() {
        let states = store.load()
        XCTAssertEqual(states.count, BuiltInMenuItems.all.count)
        XCTAssertTrue(states.allSatisfy(\.enabled))
    }

    func testSaveThenLoadRoundTrips() {
        var states = store.load()
        let firstID = states[0].id
        states[0].enabled = false
        store.save(states)

        let reloaded = store.load()
        XCTAssertEqual(reloaded.first { $0.id == firstID }?.enabled, false)
    }

    func testLoadMergesNewBuiltInItemsWithoutDisturbingSavedOrder() {
        // Simulates an older save file that predates newer built-in types.
        let subset = [
            MenuItemState(id: "html", enabled: true, sortIndex: 0),
            MenuItemState(id: "text", enabled: false, sortIndex: 1),
        ]
        store.save(subset)

        let reloaded = store.load()
        XCTAssertEqual(reloaded.first { $0.id == "text" }?.enabled, false)
        XCTAssertEqual(reloaded.first { $0.id == "html" }?.sortIndex, 0)
        // Types added later that weren't in the saved subset default to enabled.
        XCTAssertEqual(reloaded.first { $0.id == "json" }?.enabled, true)
    }

    func testLoadIgnoresUnknownSavedIDsWithoutCrashing() {
        let corrupted = [
            MenuItemState(id: "text", enabled: true, sortIndex: 0),
            MenuItemState(id: "text", enabled: false, sortIndex: 0), // duplicate id
            MenuItemState(id: "no-longer-exists", enabled: true, sortIndex: 5),
        ]
        store.save(corrupted)

        let reloaded = store.load()
        XCTAssertEqual(reloaded.count, BuiltInMenuItems.all.count)
        XCTAssertFalse(reloaded.contains { $0.id == "no-longer-exists" })
    }

    func testOrderedItemsSortsByCategoryAndSortIndex() {
        var states = store.load()
        let createIDs = BuiltInMenuItems.all.filter { $0.category == .create }.map(\.id)
        let reversed = Array(createIDs.reversed())
        for (index, id) in reversed.enumerated() {
            if let i = states.firstIndex(where: { $0.id == id }) {
                states[i].sortIndex = index
            }
        }

        let ordered = store.orderedItems(in: .create, from: states)
        XCTAssertEqual(ordered.map { $0.0.id }, reversed)
    }

    func testEnabledOrderedItemsExcludesDisabled() {
        var states = store.load()
        if let i = states.firstIndex(where: { $0.id == "text" }) {
            states[i].enabled = false
        }
        let enabled = store.enabledOrderedItems(in: .create, from: states)
        XCTAssertFalse(enabled.contains { $0.id == "text" })
    }
}
