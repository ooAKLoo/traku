//
//  ComplicationController.swift
//  Echo Watch App
//
//  表盘快捷方式 - Complication 点击直接进入录音
//

import ClockKit
import SwiftUI

class ComplicationController: NSObject, CLKComplicationDataSource {

    // MARK: - Complication Configuration

    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        let descriptors = [
            CLKComplicationDescriptor(
                identifier: "com.echo.recording",
                displayName: "Echo 录音",
                supportedFamilies: CLKComplicationFamily.allCases
            )
        ]
        handler(descriptors)
    }

    func handleSharedComplicationDescriptors(_ complicationDescriptors: [CLKComplicationDescriptor]) {
        // 处理共享的 Complication 描述符
    }

    // MARK: - Timeline Configuration

    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        // 静态 Complication，不需要时间线
        handler(nil)
    }

    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        // 显示占位符，保护隐私
        handler(.showOnLockScreen)
    }

    // MARK: - Timeline Population

    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        let template = makeTemplate(for: complication.family)
        if let template = template {
            let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
            handler(entry)
        } else {
            handler(nil)
        }
    }

    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // 静态 Complication，不提供未来条目
        handler(nil)
    }

    // MARK: - Sample Templates

    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        handler(makeTemplate(for: complication.family))
    }

    // MARK: - Template Creation

    private func makeTemplate(for family: CLKComplicationFamily) -> CLKComplicationTemplate? {
        switch family {
        case .modularSmall:
            return CLKComplicationTemplateModularSmallSimpleImage(
                imageProvider: CLKImageProvider(onePieceImage: UIImage(systemName: "waveform.circle.fill")!)
            )

        case .modularLarge:
            return CLKComplicationTemplateModularLargeStandardBody(
                headerImageProvider: CLKImageProvider(onePieceImage: UIImage(systemName: "waveform.circle.fill")!),
                headerTextProvider: CLKSimpleTextProvider(text: "Echo"),
                body1TextProvider: CLKSimpleTextProvider(text: "点击录音")
            )

        case .utilitarianSmall, .utilitarianSmallFlat:
            return CLKComplicationTemplateUtilitarianSmallSquare(
                imageProvider: CLKImageProvider(onePieceImage: UIImage(systemName: "waveform.circle.fill")!)
            )

        case .utilitarianLarge:
            return CLKComplicationTemplateUtilitarianLargeFlat(
                textProvider: CLKSimpleTextProvider(text: "Echo 录音"),
                imageProvider: CLKImageProvider(onePieceImage: UIImage(systemName: "waveform.circle.fill")!)
            )

        case .circularSmall:
            return CLKComplicationTemplateCircularSmallSimpleImage(
                imageProvider: CLKImageProvider(onePieceImage: UIImage(systemName: "waveform.circle.fill")!)
            )

        case .extraLarge:
            return CLKComplicationTemplateExtraLargeSimpleImage(
                imageProvider: CLKImageProvider(onePieceImage: UIImage(systemName: "waveform.circle.fill")!)
            )

        case .graphicCorner:
            return CLKComplicationTemplateGraphicCornerCircularImage(
                imageProvider: CLKFullColorImageProvider(fullColorImage: UIImage(systemName: "waveform.circle.fill")!)
            )

        case .graphicBezel:
            let circularTemplate = CLKComplicationTemplateGraphicCircularImage(
                imageProvider: CLKFullColorImageProvider(fullColorImage: UIImage(systemName: "waveform.circle.fill")!)
            )
            return CLKComplicationTemplateGraphicBezelCircularText(
                circularTemplate: circularTemplate,
                textProvider: CLKSimpleTextProvider(text: "Echo 录音")
            )

        case .graphicCircular:
            return CLKComplicationTemplateGraphicCircularImage(
                imageProvider: CLKFullColorImageProvider(fullColorImage: UIImage(systemName: "waveform.circle.fill")!)
            )

        case .graphicRectangular:
            return CLKComplicationTemplateGraphicRectangularStandardBody(
                headerImageProvider: CLKFullColorImageProvider(fullColorImage: UIImage(systemName: "waveform.circle.fill")!),
                headerTextProvider: CLKSimpleTextProvider(text: "Echo"),
                body1TextProvider: CLKSimpleTextProvider(text: "点击开始录音")
            )

        case .graphicExtraLarge:
            return CLKComplicationTemplateGraphicExtraLargeCircularImage(
                imageProvider: CLKFullColorImageProvider(fullColorImage: UIImage(systemName: "waveform.circle.fill")!)
            )

        @unknown default:
            return nil
        }
    }
}
