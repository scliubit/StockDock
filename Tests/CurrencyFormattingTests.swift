import XCTest
@testable import StockDock

final class CurrencyFormattingTests: XCTestCase {

    func testUSDUsesSymbolBeforeSignedAmount() {
        XCTAssertEqual(StorageService.currencyAmount(321.09, code: "USD", signed: true), "+$321.09")
        XCTAssertEqual(StorageService.currencyAmount(-321.09, code: "USD", signed: true), "-$321.09")
    }

    func testUSDUsesSymbolBeforeUnsignedAmount() {
        XCTAssertEqual(StorageService.currencyAmount(14_396.67, code: "USD"), "$14396.67")
    }

    func testEURUsesSymbolBeforeSignedAmount() {
        XCTAssertEqual(StorageService.currencyAmount(321.09, code: "EUR", signed: true), "+€321.09")
    }

    func testCHFUsesCodeBeforeAmount() {
        XCTAssertEqual(StorageService.currencyAmount(321.09, code: "CHF"), "CHF 321.09")
    }

    func testZeroFractionDigits() {
        XCTAssertEqual(StorageService.currencyAmount(321.09, code: "USD", fractionDigits: 0), "$321")
    }
}
