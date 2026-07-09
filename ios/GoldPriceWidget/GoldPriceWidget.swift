import WidgetKit
import SwiftUI
import AppIntents

private let appGroupId = "group.com.goldsignal.goldsignal"

// MARK: - Model

struct MetalRow {
    let label: String
    let price: String
    let change: String
    let changePercent: String
    let positive: Bool
    let isGold: Bool
}

struct BoardEntry: TimelineEntry {
    let date: Date
    let currency: String
    let unitLabel: String
    let lastUpdated: String
    let gold: MetalRow?
    let silver: MetalRow?
}

// MARK: - Data loading

enum WidgetStore {
    static func load(date: Date) -> BoardEntry {
        let defaults = UserDefaults(suiteName: appGroupId)

        func row(_ prefix: String, isGold: Bool) -> MetalRow? {
            guard let defaults = defaults,
                  defaults.bool(forKey: "\(prefix)_present") else { return nil }
            return MetalRow(
                label: defaults.string(forKey: "\(prefix)_label") ?? "",
                price: defaults.string(forKey: "\(prefix)_price") ?? "--",
                change: defaults.string(forKey: "\(prefix)_change") ?? "",
                changePercent: defaults.string(forKey: "\(prefix)_change_pct") ?? "",
                positive: defaults.bool(forKey: "\(prefix)_positive"),
                isGold: isGold
            )
        }

        let currency = defaults?.string(forKey: "currency") ?? "USD"
        let unitLabel = defaults?.string(forKey: "unit_label") ?? "\(currency) / gram"

        return BoardEntry(
            date: date,
            currency: currency,
            unitLabel: unitLabel,
            lastUpdated: defaults?.string(forKey: "last_updated") ?? "",
            gold: row("gold", isGold: true),
            silver: row("silver", isGold: false)
        )
    }

    static var placeholder: BoardEntry {
        BoardEntry(
            date: Date(),
            currency: "USD",
            unitLabel: "USD / gram",
            lastUpdated: "19:53",
            gold: MetalRow(label: "24K Gold", price: "4,065.02", change: "-15.51",
                           changePercent: "-0.38%", positive: false, isGold: true),
            silver: MetalRow(label: "999 Silver", price: "58.77", change: "-0.36",
                             changePercent: "-0.62%", positive: false, isGold: false)
        )
    }
}

// MARK: - Timeline

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> BoardEntry { WidgetStore.placeholder }

    func getSnapshot(in context: Context, completion: @escaping (BoardEntry) -> Void) {
        completion(context.isPreview ? WidgetStore.placeholder : WidgetStore.load(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BoardEntry>) -> Void) {
        let entry = WidgetStore.load(date: Date())
        // Refresh roughly every 30 minutes; the app also reloads on data updates.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date) ?? entry.date
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Palette

private enum Palette {
    static let card = Color(red: 0.086, green: 0.086, blue: 0.094)      // #161618
    static let divider = Color(red: 0.165, green: 0.165, blue: 0.18)    // #2A2A2E
    static let muted = Color(red: 0.604, green: 0.604, blue: 0.635)     // #9A9AA2
    static let up = Color(red: 0.18, green: 0.741, blue: 0.522)         // #2EBD85
    static let down = Color(red: 0.965, green: 0.275, blue: 0.365)      // #F6465D
    static let gold = Color(red: 0.961, green: 0.702, blue: 0.004)      // #F5B301
    static let silver = Color(red: 0.725, green: 0.741, blue: 0.776)    // #B9BDC6
}

// MARK: - Views

struct RowView: View {
    let row: MetalRow
    let unitLabel: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(row.isGold ? Palette.gold : Palette.silver)
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.black.opacity(0.4))
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text(row.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(unitLabel)
                    .font(.system(size: 11))
                    .foregroundColor(Palette.muted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(row.price)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text("\(row.change)  \(row.changePercent)")
                    .font(.system(size: 11))
                    .foregroundColor(row.positive ? Palette.up : Palette.down)
            }
        }
    }
}

struct GoldPriceWidgetEntryView: View {
    var entry: BoardEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("GoldSignal")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text(entry.currency)
                    .font(.system(size: 11))
                    .foregroundColor(Palette.muted)
                Spacer()
                if !entry.lastUpdated.isEmpty {
                    Text(entry.lastUpdated)
                        .font(.system(size: 11))
                        .foregroundColor(Palette.muted)
                }
                if #available(iOS 17, *) {
                    Button(
                        intent: BackgroundIntent(
                            url: URL(string: "goldsignal://widget?action=refresh"),
                            appGroup: appGroupId
                        )
                    ) {
                        Image(systemName: "arrow.clockwise").font(.system(size: 13))
                            .foregroundColor(Palette.muted)
                    }
                    .buttonStyle(.plain)
                } else {
                    Link(destination: URL(string: "goldsignal://widget?homeWidget=true&action=refresh")!) {
                        Image(systemName: "arrow.clockwise").font(.system(size: 13))
                            .foregroundColor(Palette.muted)
                    }
                }
                Link(destination: URL(string: "goldsignal://widget?homeWidget=true&action=settings")!) {
                    Image(systemName: "gearshape").font(.system(size: 13))
                        .foregroundColor(Palette.muted)
                }
            }

            Divider().background(Palette.divider).padding(.vertical, 10)

            if let gold = entry.gold {
                RowView(row: gold, unitLabel: entry.unitLabel)
            }
            if family != .systemSmall, let silver = entry.silver {
                Spacer().frame(height: 12)
                RowView(row: silver, unitLabel: entry.unitLabel)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .widgetBackgroundCompat(Palette.card)
        // Small family can't host Links; the whole-widget tap opens the app.
        .widgetURL(URL(string: "goldsignal://widget?homeWidget=true&action=open"))
    }
}

// MARK: - Widget

struct GoldPriceWidget: Widget {
    let kind = "GoldPriceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            GoldPriceWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("GoldSignal Prices")
        .description("Live gold & silver prices per gram with 24h change.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Background compatibility (iOS 17 containerBackground)

extension View {
    @ViewBuilder
    func widgetBackgroundCompat(_ color: Color) -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(color, for: .widget)
        } else {
            background(color)
        }
    }
}
