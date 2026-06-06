import ServiceManagement
import Sparkle
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var storageService: StorageService
    @EnvironmentObject var stockService: StockService
    @EnvironmentObject var updaterViewModel: UpdaterViewModel
    @State private var showResetAlert = false
    @State private var launchAtLoginStatus = SMAppService.mainApp.status
    @State private var launchAtLoginErrorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // MARK: - Stock Price Currency
                VStack(alignment: .leading, spacing: 6) {
                    Text("Stock Price Currency")
                        .font(.inter(13, weight: .bold, relativeTo: .headline))
                    Picker("Price currency", selection: $storageService.stockPriceCurrency) {
                        Text("Original").tag("")
                        ForEach(StorageService.supportedCurrencies, id: \.self) { code in
                            Text("\(StorageService.currencySymbol(for: code)) \(code)")
                                .tag(code)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: storageService.stockPriceCurrency) {
                        stockService.exchangeRates.removeAll()
                        Task {
                            await stockService.refreshAll(storageService: storageService)
                        }
                    }
                    Text(storageService.stockPriceCurrency.isEmpty
                         ? "Prices shown in their native currency"
                         : "All prices converted to \(storageService.stockPriceCurrency)")
                        .font(.inter(10, relativeTo: .caption))
                        .foregroundColor(.secondary)
                }

                Divider()

                // MARK: - Portfolio Currency
                VStack(alignment: .leading, spacing: 6) {
                    Text("Portfolio Currency")
                        .font(.inter(13, weight: .bold, relativeTo: .headline))
                    Picker("Portfolio currency", selection: $storageService.preferredCurrency) {
                        ForEach(StorageService.supportedCurrencies, id: \.self) { code in
                            Text("\(StorageService.currencySymbol(for: code)) \(code)")
                                .tag(code)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: storageService.preferredCurrency) {
                        stockService.exchangeRates.removeAll()
                        Task {
                            await stockService.refreshAll(storageService: storageService)
                        }
                    }
                    Text("Portfolio totals and P&L converted to \(storageService.preferredCurrency)")
                        .font(.inter(10, relativeTo: .caption))
                        .foregroundColor(.secondary)
                }

                Divider()

                // MARK: - Extended Hours
                VStack(alignment: .leading, spacing: 6) {
                    Text("Market Hours")
                        .font(.inter(13, weight: .bold, relativeTo: .headline))
                    Toggle("Show extended hours (Pre/Post)", isOn: $storageService.showExtendedHours)
                        .toggleStyle(.switch)
                    Text("Show pre-market and after-hours prices")
                        .font(.inter(10, relativeTo: .caption))
                        .foregroundColor(.secondary)
                }

                Divider()

                // MARK: - System
                VStack(alignment: .leading, spacing: 6) {
                    Text("System")
                        .font(.inter(13, weight: .bold, relativeTo: .headline))
                    Toggle("Launch at login", isOn: launchAtLoginBinding)
                        .toggleStyle(.switch)
                        .disabled(launchAtLoginUnavailable)
                    Text(launchAtLoginDescription)
                        .font(.inter(10, relativeTo: .caption))
                        .foregroundColor(launchAtLoginErrorMessage == nil ? .secondary : .red)
                }

                Divider()

                // MARK: - Refresh Rate
                VStack(alignment: .leading, spacing: 6) {
                    Text("Refresh Rate")
                        .font(.inter(13, weight: .bold, relativeTo: .headline))
                    Slider(value: $storageService.liveUpdateInterval, in: 0.25...5.0, step: 0.25)
                    Text("Live menu bar refresh: \(storageService.liveUpdateInterval, specifier: "%.2f")s")
                        .font(.inter(10, relativeTo: .caption))
                        .foregroundColor(.secondary)
                }

                Divider()

                // MARK: - Watchlist Display
                VStack(alignment: .leading, spacing: 6) {
                    Text("Watchlist Display")
                        .font(.inter(13, weight: .bold, relativeTo: .headline))
                    Toggle("Company name", isOn: $storageService.showCompanyName)
                        .toggleStyle(.switch)
                    Toggle("Day range (low – high)", isOn: $storageService.showDayRange)
                        .toggleStyle(.switch)
                    Toggle("52-week range bar", isOn: $storageService.show52WeekBar)
                        .toggleStyle(.switch)
                    Toggle("Absolute change value", isOn: $storageService.showAbsoluteChange)
                        .toggleStyle(.switch)
                    Text("Choose which details appear in each watchlist row")
                        .font(.inter(10, relativeTo: .caption))
                        .foregroundColor(.secondary)
                }

                Divider()

                // MARK: - Menu Bar Display
                VStack(alignment: .leading, spacing: 6) {
                    Text("Menu Bar Display")
                        .font(.inter(13, weight: .bold, relativeTo: .headline))
                    Picker("Display", selection: $storageService.menuBarDisplay) {
                        Text("P&L (\(StorageService.currencyAmount(321.09, code: storageService.preferredCurrency, signed: true)))").tag("pnl")
                        Text("P&L % (+2.3%)").tag("pnlPercent")
                        Text("P&L + % (\(StorageService.currencyAmount(321.09, code: storageService.preferredCurrency, signed: true)) +2.3%)").tag("pnlFull")
                        Text("Total Value (\(StorageService.currencyAmount(14396.67, code: storageService.preferredCurrency)))").tag("totalValue")
                        Text("Best Stock (▲ AAPL +1.2%)").tag("bestStock")
                        Text("Worst Stock (▼ TSLA -0.8%)").tag("worstStock")
                        Text("Best & Worst").tag("bestWorst")
                        Text("Portfolio (\(StorageService.currencyAmount(14396.67, code: storageService.preferredCurrency)) +1.2%)").tag("portfolioRecap")
                        Text("Ticker (cycle watchlist)").tag("ticker")
                        Text("Icon Only").tag("icon")
                    }
                    .pickerStyle(.menu)
                    Text("Choose what to show in the menu bar")
                        .font(.inter(10, relativeTo: .caption))
                        .foregroundColor(.secondary)
                }
                Divider()

                // MARK: - Price Alerts
                VStack(alignment: .leading, spacing: 6) {
                    Text("Price Alerts")
                        .font(.inter(13, weight: .bold, relativeTo: .headline))
                    if storageService.alerts.isEmpty {
                        Text("No alerts. Right-click a stock in the watchlist to add one.")
                            .font(.inter(10, relativeTo: .caption))
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(storageService.alerts) { alert in
                            AlertRow(alert: alert)
                        }
                    }
                }

                Divider()

                // MARK: - Font
                VStack(alignment: .leading, spacing: 6) {
                    Text("Font")
                        .font(.inter(13, weight: .bold, relativeTo: .headline))
                    Picker("Font family", selection: $storageService.fontFamily) {
                        ForEach(FontRegistration.availableFonts, id: \.family) { font in
                            Text(font.label)
                                .font(.custom(font.family, size: 13))
                                .tag(font.family)
                        }
                    }
                    .pickerStyle(.menu)
                    HStack {
                        Text("A")
                            .font(.inter(10, relativeTo: .caption))
                            .foregroundColor(.secondary)
                        Slider(value: Binding(
                            get: { Double(storageService.fontSizeLevel) },
                            set: { storageService.fontSizeLevel = Int($0) }
                        ), in: 7...13, step: 1)
                        Text("A")
                            .font(.inter(18, weight: .bold, relativeTo: .title2))
                            .foregroundColor(.secondary)
                    }
                    Text("Size: \(storageService.fontSizeLevel)")
                        .font(.inter(10, relativeTo: .caption))
                        .foregroundColor(.secondary)
                }

                Divider()

                // MARK: - Updates
                VStack(alignment: .leading, spacing: 6) {
                    Text("Updates")
                        .font(.inter(13, weight: .bold, relativeTo: .headline))
                    Button("Check for Updates...") {
                        NSApp.setActivationPolicy(.regular)
                        NSApp.activate(ignoringOtherApps: true)
                        updaterViewModel.checkForUpdates()
                    }
                    .disabled(!updaterViewModel.canCheckForUpdates)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Reset")
                        .font(.inter(13, weight: .bold, relativeTo: .headline))
                    Button("Reset to Default Settings") {
                        showResetAlert = true
                    }
                    .foregroundColor(.red)
                    Text("This will not erase your portfolios or watchlist")
                        .font(.inter(10, relativeTo: .caption))
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
        }
        .onAppear {
            refreshLaunchAtLoginStatus()
        }
        .alert("Reset Settings", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                storageService.resetToDefaults()
                Task {
                    stockService.exchangeRates.removeAll()
                    await stockService.refreshAll(storageService: storageService)
                }
            }
        } message: {
            Text("This will reset all settings to their defaults. Your portfolios and watchlist will not be affected.")
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLoginRequested },
            set: { setLaunchAtLogin($0) }
        )
    }

    private var launchAtLoginRequested: Bool {
        switch launchAtLoginStatus {
        case .enabled, .requiresApproval:
            return true
        case .notRegistered, .notFound:
            return false
        @unknown default:
            return false
        }
    }

    private var launchAtLoginUnavailable: Bool {
        switch launchAtLoginStatus {
        case .notFound:
            return true
        case .enabled, .requiresApproval, .notRegistered:
            return false
        @unknown default:
            return true
        }
    }

    private var launchAtLoginDescription: String {
        if let launchAtLoginErrorMessage {
            return launchAtLoginErrorMessage
        }

        switch launchAtLoginStatus {
        case .enabled:
            return "StockDock opens automatically when you log in"
        case .requiresApproval:
            return "Approve StockDock in System Settings > Login Items to finish setup"
        case .notRegistered:
            return "Start StockDock automatically when you log in"
        case .notFound:
            return "Launch at login is unavailable for this build"
        @unknown default:
            return "Launch at login status is unavailable"
        }
    }

    private func refreshLaunchAtLoginStatus() {
        launchAtLoginStatus = SMAppService.mainApp.status
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if !launchAtLoginRequested {
                    try SMAppService.mainApp.register()
                }
            } else if launchAtLoginRequested {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginErrorMessage = nil
        } catch {
            launchAtLoginErrorMessage = error.localizedDescription
        }

        refreshLaunchAtLoginStatus()
    }
}

/// A single alert row in Settings: enable/re-arm toggle, description and delete.
private struct AlertRow: View {
    @EnvironmentObject var storageService: StorageService
    let alert: PriceAlert

    private var currencyCode: String {
        StockService.shared.quotes[alert.symbol]?.currency ?? storageService.preferredCurrency
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: alert.condition.systemImage)
                .font(.inter(10, relativeTo: .caption))
                .foregroundColor(alert.isEnabled ? .accentColor : .secondary)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(alert.symbol)
                    .font(.inter(12, weight: .semibold, relativeTo: .body))
                Text(AlertEvaluator.describe(alert, currencyCode: currencyCode))
                    .font(.inter(9, relativeTo: .caption2))
                    .foregroundColor(.secondary)
            }
            Spacer()
            if !alert.isEnabled {
                Text("triggered")
                    .font(.inter(8, weight: .semibold, relativeTo: .caption2))
                    .foregroundColor(.orange)
            }
            Toggle("", isOn: Binding(
                get: { alert.isEnabled },
                set: { storageService.setAlertEnabled(id: alert.id, enabled: $0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
            .help(alert.isEnabled ? "Enabled" : "Re-arm alert")
            Button(action: { storageService.removeAlert(id: alert.id) }) {
                Image(systemName: "trash")
                    .font(.inter(10, relativeTo: .caption))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }
}
