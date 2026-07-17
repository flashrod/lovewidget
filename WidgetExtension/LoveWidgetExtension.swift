import WidgetKit
import SwiftUI
import LoveWidgetCore

// MARK: - LoveWidgetEntry

struct LoveWidgetEntry: TimelineEntry {
    let date: Date
    let drawing: Drawing
    let partnerName: String
    let lastUpdated: Date?
    let syncStatus: SyncStatus
}

// MARK: - Provider

struct Provider: TimelineProvider {

    private let storage = AppGroupStorage.shared

    func placeholder(in context: Context) -> LoveWidgetEntry {
        LoveWidgetEntry(
            date: Date(),
            drawing: .empty,
            partnerName: "Your Partner",
            lastUpdated: nil,
            syncStatus: .idle
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LoveWidgetEntry) -> Void) {
        let entry = currentEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LoveWidgetEntry>) -> Void) {
        let entry = currentEntry()
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(refresh))
        completion(timeline)
    }

    private func currentEntry() -> LoveWidgetEntry {
        let drawing = (try? storage.loadDrawing()) ?? .empty
        let pair = try? storage.loadPair()
        let defaults = UserDefaults(suiteName: StorageKeys.appGroupIdentifier)
        let lastSync = defaults?.object(forKey: StorageKeys.lastSyncTimestampKey) as? Date

        return LoveWidgetEntry(
            date: Date(),
            drawing: drawing,
            partnerName: pair?.partnerDisplayName ?? "Your Partner",
            lastUpdated: lastSync,
            syncStatus: pair?.isPaired == true ? .connected : .idle
        )
    }
}

// MARK: - LoveWidgetEntryView

struct LoveWidgetEntryView: View {

    var entry: LoveWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget

struct LoveWidget: Widget {

    let kind: String = "com.lovewidget.app.widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LoveWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("LoveWidget")
        .description("Your shared drawing canvas.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - WidgetBundle

struct LoveWidgetBundle: WidgetBundle {
    var body: some Widget {
        LoveWidget()
    }
}
