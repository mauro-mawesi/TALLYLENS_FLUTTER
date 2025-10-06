import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ReceiptEntry {
        ReceiptEntry(date: Date(), monthlyTotal: "$0.00", receiptCount: 0, lastMerchant: "No receipts", lastAmount: "$0.00")
    }

    func getSnapshot(in context: Context, completion: @escaping (ReceiptEntry) -> ()) {
        let entry = ReceiptEntry(
            date: Date(),
            monthlyTotal: getWidgetData(key: "monthly_total", defaultValue: "$0.00"),
            receiptCount: getWidgetData(key: "receipt_count", defaultValue: 0),
            lastMerchant: getWidgetData(key: "last_merchant", defaultValue: "No receipts"),
            lastAmount: getWidgetData(key: "last_amount", defaultValue: "$0.00")
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = ReceiptEntry(
            date: Date(),
            monthlyTotal: getWidgetData(key: "monthly_total", defaultValue: "$0.00"),
            receiptCount: getWidgetData(key: "receipt_count", defaultValue: 0),
            lastMerchant: getWidgetData(key: "last_merchant", defaultValue: "No receipts"),
            lastAmount: getWidgetData(key: "last_amount", defaultValue: "$0.00")
        )

        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    func getWidgetData<T>(key: String, defaultValue: T) -> T {
        let sharedDefaults = UserDefaults(suiteName: "group.com.recibos.app")
        if let value = sharedDefaults?.value(forKey: key) as? T {
            return value
        }
        return defaultValue
    }
}

struct ReceiptEntry: TimelineEntry {
    let date: Date
    let monthlyTotal: String
    let receiptCount: Int
    let lastMerchant: String
    let lastAmount: String
}

struct ReceiptsWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    var entry: ReceiptEntry

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.31, green: 0.27, blue: 0.90), Color(red: 0.20, green: 0.16, blue: 0.60)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(entry.receiptCount)")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("This Month")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    Text(entry.monthlyTotal)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            .padding()
        }
        .widgetURL(URL(string: "receipts://scan"))
    }
}

struct MediumWidgetView: View {
    var entry: ReceiptEntry

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.31, green: 0.27, blue: 0.90), Color(red: 0.20, green: 0.16, blue: 0.60)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(spacing: 16) {
                // Left side - Monthly summary
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                        Text("\(entry.receiptCount) receipts")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("This Month")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))

                        Text(entry.monthlyTotal)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }

                    Spacer()
                }

                Divider()
                    .background(Color.white.opacity(0.3))

                // Right side - Last receipt
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last Receipt")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.lastMerchant)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(entry.lastAmount)
                            .font(.headline)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Button(intent: ScanReceiptIntent()) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Scan")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }

            }
            .padding()
        }
    }
}

// Intent for interactive button
struct ScanReceiptIntent: AppIntent {
    static var title: LocalizedStringResource = "Scan Receipt"

    func perform() async throws -> some IntentResult {
        // Open app to scan screen
        guard let url = URL(string: "receipts://scan") else {
            throw NSError(domain: "WidgetError", code: 1, userInfo: nil)
        }
        await UIApplication.shared.open(url)
        return .result()
    }
}

@main
struct ReceiptsWidget: Widget {
    let kind: String = "ReceiptsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ReceiptsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Receipts Summary")
        .description("View your monthly spending and quick scan receipts.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ReceiptsWidget_Previews: PreviewProvider {
    static var previews: some View {
        ReceiptsWidgetEntryView(entry: ReceiptEntry(
            date: Date(),
            monthlyTotal: "$450.75",
            receiptCount: 12,
            lastMerchant: "Whole Foods",
            lastAmount: "$45.20"
        ))
        .previewContext(WidgetPreviewContext(family: .systemSmall))

        ReceiptsWidgetEntryView(entry: ReceiptEntry(
            date: Date(),
            monthlyTotal: "$450.75",
            receiptCount: 12,
            lastMerchant: "Whole Foods",
            lastAmount: "$45.20"
        ))
        .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
