import XCTest
@testable import equinox

final class AppBridgeEventContractTests: XCTestCase {
    func testBridgeAndGUIJoinURLDetectionShareWebURL() {
        let location = "https://zoom.us/j/123456789"
        let url = JoinURLDetection.detectJoinURL(location: location, url: nil, notes: nil)
        XCTAssertEqual(url?.absoluteString, "https://zoom.us/j/123456789")
    }

    func testBridgeFiltersDeclinedGUIShowsDimmed() {
        XCTAssertTrue(AppBridgeEventContract.bridgeFiltersDeclinedInvitations)
        XCTAssertTrue(AppBridgeEventContract.guiShowsDeclinedInvitationsDimmed)
    }

    func testMultiDayLayoutDiffersBySurface() {
        XCTAssertTrue(AppBridgeEventContract.bridgeUsesFlatEvents)
        XCTAssertTrue(AppBridgeEventContract.guiUsesEventLayoutDaySlots)
    }

    func testJoinURLNativeRewriteIsGUIOnly() {
        XCTAssertTrue(AppBridgeEventContract.bridgeJoinURLIsWebOnly)
        XCTAssertTrue(AppBridgeEventContract.guiJoinURLMayRewriteToNative)
        let web = URL(string: "https://zoom.us/j/123")!
        XCTAssertNotNil(NativeJoinURL.nativeURLString(from: web))
    }

    func testCalendarFilterAndCRUDContract() {
        XCTAssertTrue(AppBridgeEventContract.bridgeListsAllDisplayableCalendarsByDefault)
        XCTAssertTrue(AppBridgeEventContract.guiRespectsCalendarSelectionStorage)
        XCTAssertTrue(AppBridgeEventContract.bridgeSupportsUpdateEvent)
        XCTAssertFalse(AppBridgeEventContract.guiSupportsUpdateEvent)
        XCTAssertFalse(AppBridgeEventContract.bridgeSupportsRSVPWrite)
        XCTAssertTrue(AppBridgeEventContract.guiSupportsRSVPWrite)
    }
}
