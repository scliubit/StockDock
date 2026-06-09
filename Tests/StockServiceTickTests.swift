import Combine
import XCTest
@testable import StockDock

final class StockServiceTickTests: XCTestCase {
    @MainActor
    func testApplyTicksPublishesOnceForMultipleChangedSymbols() {
        let service = StockService.shared
        service.quotes = [:]

        var publishCount = 0
        let cancellable = service.objectWillChange.sink {
            publishCount += 1
        }

        let changed = service.applyTicks([
            tick(symbol: "AAPL", price: 100),
            tick(symbol: "MSFT", price: 200),
            tick(symbol: "AAPL", price: 101)
        ])

        XCTAssertEqual(changed, Set(["AAPL", "MSFT"]))
        XCTAssertEqual(service.quotes["AAPL"]?.price, 101)
        XCTAssertEqual(service.quotes["MSFT"]?.price, 200)
        XCTAssertEqual(publishCount, 1)

        cancellable.cancel()
    }

    @MainActor
    func testApplyTicksSkipsUnchangedQuote() {
        let service = StockService.shared
        service.quotes = ["AAPL": quote(symbol: "AAPL", price: 100)]

        var publishCount = 0
        let cancellable = service.objectWillChange.sink {
            publishCount += 1
        }

        let changed = service.applyTicks([
            tick(symbol: "AAPL", price: 100)
        ])

        XCTAssertTrue(changed.isEmpty)
        XCTAssertEqual(publishCount, 0)

        cancellable.cancel()
    }

    private func tick(symbol: String, price: Double) -> Yaticker {
        var ticker = Yaticker()
        ticker.id = symbol
        ticker.price = Float(price)
        ticker.change = 1
        ticker.changePercent = 1
        ticker.currency = "USD"
        ticker.shortName = symbol
        ticker.marketHours = .regularMarket
        return ticker
    }

    private func quote(symbol: String, price: Double) -> StockQuote {
        StockQuote(
            symbol: symbol,
            name: symbol,
            price: price,
            change: 1,
            changePercent: 1,
            currency: "USD",
            marketState: "REGULAR",
            dayHigh: nil,
            dayLow: nil,
            fiftyTwoWeekHigh: nil,
            fiftyTwoWeekLow: nil,
            preMarketPrice: nil,
            preMarketChange: nil,
            preMarketChangePercent: nil,
            postMarketPrice: nil,
            postMarketChange: nil,
            postMarketChangePercent: nil
        )
    }
}
