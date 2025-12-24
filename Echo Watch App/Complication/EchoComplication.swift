//
//  EchoComplication.swift
//  Echo Watch App
//
//  WidgetKit Complication - watchOS 9+
//  表盘快捷方式，点击直接进入录音
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct EchoComplicationProvider: TimelineProvider {

    func placeholder(in context: Context) -> EchoComplicationEntry {
        EchoComplicationEntry(date: Date(), pendingCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (EchoComplicationEntry) -> Void) {
        let entry = EchoComplicationEntry(date: Date(), pendingCount: 0)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EchoComplicationEntry>) -> Void) {
        let entry = EchoComplicationEntry(date: Date(), pendingCount: 0)
        // 静态 Complication，不需要更新
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

// MARK: - Timeline Entry

struct EchoComplicationEntry: TimelineEntry {
    let date: Date
    let pendingCount: Int
}

// MARK: - Complication Views

struct EchoComplicationEntryView: View {
    var entry: EchoComplicationProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            accessoryCircularView

        case .accessoryCorner:
            accessoryCornerView

        case .accessoryRectangular:
            accessoryRectangularView

        case .accessoryInline:
            accessoryInlineView

        default:
            defaultView
        }
    }

    // MARK: - Circular View

    private var accessoryCircularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.red)
        }
    }

    // MARK: - Corner View

    private var accessoryCornerView: some View {
        Image(systemName: "waveform.circle.fill")
            .font(.title)
            .foregroundColor(.red)
            .widgetLabel {
                Text("录音")
            }
    }

    // MARK: - Rectangular View

    private var accessoryRectangularView: some View {
        HStack {
            Image(systemName: "waveform.circle.fill")
                .font(.title2)
                .foregroundColor(.red)

            VStack(alignment: .leading) {
                Text("Echo")
                    .font(.headline)
                Text("点击录音")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if entry.pendingCount > 0 {
                Text("\(entry.pendingCount)")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }

    // MARK: - Inline View

    private var accessoryInlineView: some View {
        Label("Echo 录音", systemImage: "waveform.circle.fill")
    }

    // MARK: - Default View

    private var defaultView: some View {
        Image(systemName: "waveform.circle.fill")
            .font(.largeTitle)
            .foregroundColor(.red)
    }
}

// MARK: - Widget Definition
// NOTE: 需要将此文件移动到单独的 Widget Extension target
// 或者在 Xcode 中创建新的 "Echo Watch Complication" Widget Extension

struct EchoComplication: Widget {
    let kind: String = "com.echo.complication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EchoComplicationProvider()) { entry in
            EchoComplicationEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Echo 录音")
        .description("快速开始语音录音")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Preview

#Preview(as: .accessoryCircular) {
    EchoComplication()
} timeline: {
    EchoComplicationEntry(date: .now, pendingCount: 0)
    EchoComplicationEntry(date: .now, pendingCount: 3)
}
