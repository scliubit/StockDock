import Foundation

enum WatchlistSortColumn: String, Codable {
    case symbol, price, change

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = WatchlistSortColumn(rawValue: rawValue) ?? .symbol
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

@MainActor
class StorageService: ObservableObject {
    static let shared = StorageService()

    @Published var watchlist: [String] = [] {
        didSet { scheduleSave() }
    }

    @Published var portfolios: [Portfolio] = [] {
        didSet { scheduleSave() }
    }

    @Published var preferredCurrency: String = "EUR" {
        didSet { scheduleSave() }
    }

    @Published var stockPriceCurrency: String = "" {
        didSet { scheduleSave() }
    }

    @Published var showExtendedHours: Bool = true {
        didSet { scheduleSave() }
    }

    @Published var liveUpdateInterval: Double = 1.0 {
        didSet { scheduleSave() }
    }

    // MARK: - Watchlist row display toggles
    @Published var showCompanyName: Bool = true {
        didSet { scheduleSave() }
    }
    @Published var showDayRange: Bool = true {
        didSet { scheduleSave() }
    }
    @Published var show52WeekBar: Bool = true {
        didSet { scheduleSave() }
    }
    @Published var showAbsoluteChange: Bool = true {
        didSet { scheduleSave() }
    }

    @Published var watchlistSortColumn: WatchlistSortColumn = .symbol {
        didSet { scheduleSave() }
    }

    @Published var watchlistSortAscending: Bool = true {
        didSet { scheduleSave() }
    }

    /// What to display in the menu bar: "pnl", "totalValue", "icon"
    @Published var menuBarDisplay: String = "pnl" {
        didSet { scheduleSave() }
    }

    /// Maps symbol → ISIN for watchlist filtering
    @Published var isinMap: [String: String] = [:] {
        didSet { scheduleSave() }
    }

    /// One-shot price alerts.
    @Published var alerts: [PriceAlert] = [] {
        didSet { scheduleSave() }
    }

    @Published var fontSizeLevel: Int = 9 {
        didSet {
            FontRegistration.sizeOffset = CGFloat(fontSizeLevel - 9)
            scheduleSave()
        }
    }

    @Published var fontFamily: String = "Inter Variable" {
        didSet {
            FontRegistration.familyName = fontFamily
            scheduleSave()
        }
    }

    func setISIN(_ isin: String, for symbol: String) {
        isinMap[symbol] = isin
    }

    // MARK: - Alerts

    func addAlert(_ alert: PriceAlert) {
        alerts.append(alert)
    }

    func removeAlert(id: UUID) {
        alerts.removeAll { $0.id == id }
    }

    func setAlertEnabled(id: UUID, enabled: Bool) {
        guard let i = alerts.firstIndex(where: { $0.id == id }) else { return }
        alerts[i].isEnabled = enabled
        if enabled { alerts[i].lastTriggeredAt = nil }
    }

    /// Marks an alert as fired: records the time and disables it (one-shot).
    func markAlertTriggered(id: UUID, at date: Date = Date()) {
        guard let i = alerts.firstIndex(where: { $0.id == id }) else { return }
        alerts[i].isEnabled = false
        alerts[i].lastTriggeredAt = date
    }

    func alerts(for symbol: String) -> [PriceAlert] {
        alerts.filter { $0.symbol == symbol }
    }

    var lastSelectedTab: String = "Watchlist"

    static let supportedCurrencies = ["USD", "EUR", "GBP", "JPY", "CHF", "CAD", "AUD", "HKD", "CNY", "SGD", "NZD", "SEK", "NOK", "DKK", "INR"]

    nonisolated static func currencySymbol(for code: String) -> String {
        switch code {
        case "EUR": return "€"
        case "USD": return "$"
        case "GBP": return "£"
        case "CHF": return "CHF"
        case "JPY": return "¥"
        case "CAD": return "C$"
        case "AUD": return "A$"
        case "HKD": return "HK$"
        case "CNY": return "CN¥"
        case "SGD": return "S$"
        case "NZD": return "NZ$"
        case "SEK", "NOK", "DKK": return "kr"
        case "INR": return "₹"
        default: return code
        }
    }

    nonisolated static func currencyAmount(_ amount: Double, code: String, signed: Bool = false, fractionDigits: Int = 2) -> String {
        let symbol = currencySymbol(for: code)
        let sign = signed ? (amount >= 0 ? "+" : "-") : (amount < 0 ? "-" : "")
        let digits = max(0, fractionDigits)
        let number = String(format: "%.\(digits)f", abs(amount))

        if symbol.count > 1 && !symbol.contains("$") {
            return "\(sign)\(symbol) \(number)"
        }
        return "\(sign)\(symbol)\(number)"
    }

    private let fileURL: URL
    private var isLoading = false
    private var saveTask: Task<Void, Never>?

    private init() {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            let fallback = FileManager.default.temporaryDirectory
            self.fileURL = fallback.appendingPathComponent("StockDock_data.json")
            return
        }
        let dirName = "StockDock"
        let dir = appSupport.appendingPathComponent(dirName, isDirectory: true)
        let oldDir = appSupport.appendingPathComponent("StockBar", isDirectory: true)
        if FileManager.default.fileExists(atPath: oldDir.path) && !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.moveItem(at: oldDir, to: dir)
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("data.json")
        isLoading = true
        load()
        isLoading = false
    }

    func addToWatchlist(_ symbol: String) {
        guard !watchlist.contains(symbol) else { return }
        watchlist.append(symbol)
    }

    func removeFromWatchlist(_ symbol: String) {
        watchlist.removeAll { $0 == symbol }
    }

    func moveWatchlistItem(from source: IndexSet, to destination: Int) {
        watchlist.move(fromOffsets: source, toOffset: destination)
    }

    func addPortfolio(name: String) {
        portfolios.append(Portfolio(name: name))
    }

    func renamePortfolio(id: UUID, name: String) {
        guard let index = portfolios.firstIndex(where: { $0.id == id }) else { return }
        portfolios[index].name = name
    }

    func deletePortfolio(at offsets: IndexSet) {
        portfolios.remove(atOffsets: offsets)
    }

    func deletePortfolio(id: UUID) {
        portfolios.removeAll { $0.id == id }
    }

    func addHolding(to portfolioId: UUID, symbol: String, quantity: Double, avgPrice: Double, avgPriceCurrency: String? = nil, purchaseDate: Date? = nil) {
        guard let index = portfolios.firstIndex(where: { $0.id == portfolioId }) else { return }
        let holding = Holding(symbol: symbol, quantity: quantity, avgPrice: avgPrice, avgPriceCurrency: normalizedCurrency(avgPriceCurrency), purchaseDate: purchaseDate)
        portfolios[index].holdings.append(holding)
    }

    func removeHolding(from portfolioId: UUID, holdingId: UUID) {
        guard let pIndex = portfolios.firstIndex(where: { $0.id == portfolioId }) else { return }
        portfolios[pIndex].holdings.removeAll { $0.id == holdingId }
    }

    func updateHolding(in portfolioId: UUID, holdingId: UUID, quantity: Double, avgPrice: Double, avgPriceCurrency: String? = nil, purchaseDate: Date? = nil) {
        guard let pIndex = portfolios.firstIndex(where: { $0.id == portfolioId }),
              let hIndex = portfolios[pIndex].holdings.firstIndex(where: { $0.id == holdingId })
        else { return }
        portfolios[pIndex].holdings[hIndex].quantity = quantity
        portfolios[pIndex].holdings[hIndex].avgPrice = avgPrice
        portfolios[pIndex].holdings[hIndex].avgPriceCurrency = normalizedCurrency(avgPriceCurrency)
        portfolios[pIndex].holdings[hIndex].purchaseDate = purchaseDate
    }

    private func normalizedCurrency(_ currency: String?) -> String? {
        guard let currency, !currency.isEmpty else { return nil }
        return currency
    }

    func resetToDefaults() {
        preferredCurrency = "EUR"
        stockPriceCurrency = ""
        showExtendedHours = true
        liveUpdateInterval = 1.0
        showCompanyName = true
        showDayRange = true
        show52WeekBar = true
        showAbsoluteChange = true
        watchlistSortColumn = .symbol
        watchlistSortAscending = true
        menuBarDisplay = "pnl"
        fontSizeLevel = 9
        fontFamily = "Inter Variable"
        lastSelectedTab = "Watchlist"
    }

    // MARK: - Export / Import

    struct PortfolioExport: Codable {
        var version: Int = 1
        var exportDate: Date
        var portfolios: [Portfolio]
    }

    func exportPortfolios(_ portfoliosToExport: [Portfolio]) -> Data? {
        let export = PortfolioExport(exportDate: Date(), portfolios: portfoliosToExport)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(export)
    }

    func importPortfolios(from data: Data) -> [Portfolio]? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let export = try? decoder.decode(PortfolioExport.self, from: data) else { return nil }
        return export.portfolios
    }

    func mergeImportedPortfolios(_ imported: [Portfolio]) {
        for var portfolio in imported {
            portfolio.id = UUID()
            for i in portfolio.holdings.indices {
                portfolio.holdings[i].id = UUID()
            }
            let baseName = portfolio.name
            var name = baseName
            var counter = 2
            while portfolios.contains(where: { $0.name == name }) {
                name = "\(baseName) (\(counter))"
                counter += 1
            }
            portfolio.name = name
            portfolios.append(portfolio)
        }
    }

    // MARK: - Persistence

    private struct AppData: Codable {
        var watchlist: [String]
        var portfolios: [Portfolio]
        var preferredCurrency: String?
        var stockPriceCurrency: String?
        var showExtendedHours: Bool?
        var liveUpdateInterval: Double?
        var menuBarDisplay: String?
        var isinMap: [String: String]?
        var fontSizeLevel: Int?
        var fontFamily: String?
        var alerts: [PriceAlert]?
        var showCompanyName: Bool?
        var showDayRange: Bool?
        var show52WeekBar: Bool?
        var showAbsoluteChange: Bool?
        var watchlistSortColumn: WatchlistSortColumn?
        var watchlistSortAscending: Bool?
    }

    private func scheduleSave() {
        guard !isLoading else { return }
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard !Task.isCancelled else { return }
            self.performSave()
        }
    }

    private func performSave() {
        let data = AppData(watchlist: watchlist, portfolios: portfolios, preferredCurrency: preferredCurrency, stockPriceCurrency: stockPriceCurrency, showExtendedHours: showExtendedHours, liveUpdateInterval: liveUpdateInterval, menuBarDisplay: menuBarDisplay, isinMap: isinMap, fontSizeLevel: fontSizeLevel, fontFamily: fontFamily, alerts: alerts, showCompanyName: showCompanyName, showDayRange: showDayRange, show52WeekBar: show52WeekBar, showAbsoluteChange: showAbsoluteChange, watchlistSortColumn: watchlistSortColumn, watchlistSortAscending: watchlistSortAscending)
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: fileURL, options: .atomic)
        } catch {
            // Error saving is non-fatal; data will be retried on next change
        }
    }

    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        performSave()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(AppData.self, from: data)
            watchlist = decoded.watchlist
            portfolios = decoded.portfolios
            preferredCurrency = decoded.preferredCurrency ?? "EUR"
            stockPriceCurrency = decoded.stockPriceCurrency ?? ""
            showExtendedHours = decoded.showExtendedHours ?? true
            liveUpdateInterval = min(max(decoded.liveUpdateInterval ?? 1.0, 0.25), 5.0)
            menuBarDisplay = decoded.menuBarDisplay ?? "pnl"
            isinMap = decoded.isinMap ?? [:]
            alerts = decoded.alerts ?? []
            showCompanyName = decoded.showCompanyName ?? true
            showDayRange = decoded.showDayRange ?? true
            show52WeekBar = decoded.show52WeekBar ?? true
            showAbsoluteChange = decoded.showAbsoluteChange ?? true
            watchlistSortColumn = decoded.watchlistSortColumn ?? .symbol
            watchlistSortAscending = decoded.watchlistSortAscending ?? true
            fontSizeLevel = decoded.fontSizeLevel ?? 9
            fontFamily = decoded.fontFamily ?? "Inter Variable"
            FontRegistration.familyName = fontFamily
            FontRegistration.sizeOffset = CGFloat(fontSizeLevel - 9)
        } catch {
            // First launch or corrupted file — defaults are used
        }
    }
}
