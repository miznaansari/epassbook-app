import WidgetKit
import SwiftUI

private let appGroupId = "group.com.fintrust.passbook.passbookApp"

struct WidgetData {
    let availableBalance: String
    let shareValue: String
    let sipValue: String
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), data: WidgetData(availableBalance: "$0.00", shareValue: "$0.00", sipValue: "$0.00"))
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), data: fetchWidgetData())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = SimpleEntry(date: Date(), data: fetchWidgetData())
        // Refresh every 15 minutes, or when updateWidget is called by Flutter
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
    
    private func fetchWidgetData() -> WidgetData {
        let defaults = UserDefaults(suiteName: appGroupId)
        let balance = defaults?.string(forKey: "availableBalance") ?? "--"
        let stocks = defaults?.string(forKey: "shareValue") ?? "--"
        let sips = defaults?.string(forKey: "sipValue") ?? "--"
        return WidgetData(availableBalance: balance, shareValue: stocks, sipValue: sips)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

struct PassbookWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            // Background
            Color(red: 0.10, green: 0.10, blue: 0.14)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 12) {
                // Header Title
                HStack {
                    Image(systemName: "banknote.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 0.53, green: 0.44, blue: 0.94))
                    Text("FINTRUST PORTFOLIO")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(Color(red: 0.56, green: 0.55, blue: 0.62))
                        .tracking(1.0)
                }
                .padding(.bottom, family == .systemMedium ? 4 : 0)

                if family == .systemMedium {
                    // Medium Widget Content: 3-column layout
                    HStack(spacing: 0) {
                        // Col 1: Balance
                        VStack(alignment: .center, spacing: 4) {
                            Text("BALANCE")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(Color(red: 0.56, green: 0.55, blue: 0.62))
                            Text(entry.data.availableBalance)
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundColor(Color(red: 0.06, green: 0.73, blue: 0.51)) // Emerald Green
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)

                        Divider()
                            .background(Color(red: 0.17, green: 0.16, blue: 0.24))

                        // Col 2: Stocks
                        VStack(alignment: .center, spacing: 4) {
                            Text("STOCKS")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(Color(red: 0.56, green: 0.55, blue: 0.62))
                            Text(entry.data.shareValue)
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundColor(Color(red: 0.02, green: 0.71, blue: 0.83)) // Cyan
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)

                        Divider()
                            .background(Color(red: 0.17, green: 0.16, blue: 0.24))

                        // Col 3: SIPs
                        VStack(alignment: .center, spacing: 4) {
                            Text("SAVINGS/SIP")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(Color(red: 0.56, green: 0.55, blue: 0.62))
                            Text(entry.data.sipValue)
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundColor(Color(red: 0.96, green: 0.62, blue: 0.04)) // Amber Gold
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    // Small Widget Content: Stacked display
                    VStack(alignment: .leading, spacing: 6) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("BALANCE")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(Color(red: 0.56, green: 0.55, blue: 0.62))
                            Text(entry.data.availableBalance)
                                .font(.system(size: 12, weight: .black))
                                .foregroundColor(Color(red: 0.06, green: 0.73, blue: 0.51))
                                .lineLimit(1)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("STOCKS")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(Color(red: 0.56, green: 0.55, blue: 0.62))
                            Text(entry.data.shareValue)
                                .font(.system(size: 12, weight: .black))
                                .foregroundColor(Color(red: 0.02, green: 0.71, blue: 0.83))
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}

@main
struct PassbookWidget: Widget {
    let kind: String = "PassbookWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            PassbookWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Fintrust Portfolio Widget")
        .description("Keep track of your Available Balance, Stocks, and SIP savings right from your Home screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct PassbookWidget_Previews: PreviewProvider {
    static var previews: some View {
        PassbookWidgetEntryView(entry: SimpleEntry(date: Date(), data: WidgetData(availableBalance: "$5,240.50", shareValue: "$12,450.00", sipValue: "$1,200.00")))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
