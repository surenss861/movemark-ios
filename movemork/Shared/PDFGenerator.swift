//
//  PDFGenerator.swift
//  movemork
//
//  MoveMark — PDF report generation.
//

import UIKit
import PDFKit

enum PDFGenerator {

    static func generateDisputeSummary(
        property: PropertyRecord,
        dispute: DisputeDraft,
        evidenceCount: Int,
        photoCount: Int,
        documentCount: Int,
        moveOutDate: Date? = nil,
        receivedItemized: Bool = false,
        chargeDate: Date? = nil
    ) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let margin: CGFloat = 50

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            let textColor = UIColor(red: 0.95, green: 0.93, blue: 0.90, alpha: 1.0)
            let bgColor = UIColor(red: 0.03, green: 0.03, blue: 0.04, alpha: 1.0)
            let accentColor = UIColor(red: 0.25, green: 0.66, blue: 0.45, alpha: 1.0)
            let secondaryColor = UIColor(red: 0.60, green: 0.57, blue: 0.54, alpha: 1.0)

            let titleFont = UIFont.systemFont(ofSize: 28, weight: .bold)
            let headingFont = UIFont.systemFont(ofSize: 20, weight: .semibold)
            let bodyFont = UIFont.systemFont(ofSize: 14, weight: .regular)
            let labelFont = UIFont.systemFont(ofSize: 12, weight: .medium)

            let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: textColor]
            let headingAttrs: [NSAttributedString.Key: Any] = [.font: headingFont, .foregroundColor: textColor]
            let bodyAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: textColor]
            let labelAttrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: secondaryColor]

            let contentWidth = pageRect.width - margin * 2

            // Page 1 — Cover
            context.beginPage()
            bgColor.setFill()
            UIRectFill(pageRect)

            var y: CGFloat = margin + 40
            "MoveMark — Dispute Summary".draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
            y += 44

            accentColor.setFill()
            UIRectFill(CGRect(x: margin, y: y, width: 40, height: 3))
            y += 20

            "Property".draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)
            y += 18
            property.addressLine1.draw(at: CGPoint(x: margin, y: y), withAttributes: bodyAttrs)
            y += 22
            if !property.addressLine2.isEmpty {
                property.addressLine2.draw(at: CGPoint(x: margin, y: y), withAttributes: bodyAttrs)
                y += 22
            }

            y += 10
            "Dispute Type".draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)
            y += 18
            dispute.type.rawValue.draw(at: CGPoint(x: margin, y: y), withAttributes: bodyAttrs)
            y += 22

            "Deposit Amount".draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)
            y += 18
            property.depositAmount.draw(at: CGPoint(x: margin, y: y), withAttributes: bodyAttrs)
            y += 22

            if let moveOutDate = moveOutDate {
                y += 10
                "Move-out date".draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)
                y += 18
                DateFormatter.localizedString(from: moveOutDate, dateStyle: .medium, timeStyle: .none).draw(at: CGPoint(x: margin, y: y), withAttributes: bodyAttrs)
                y += 22
            }
            y += 10
            "Itemized charges received".draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)
            y += 18
            (receivedItemized ? "Yes" : "No").draw(at: CGPoint(x: margin, y: y), withAttributes: bodyAttrs)
            y += 22
            if let chargeDate = chargeDate {
                "Charge date".draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)
                y += 18
                DateFormatter.localizedString(from: chargeDate, dateStyle: .medium, timeStyle: .none).draw(at: CGPoint(x: margin, y: y), withAttributes: bodyAttrs)
                y += 22
            }

            let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none)
            y += 10
            "Generated".draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)
            y += 18
            dateStr.draw(at: CGPoint(x: margin, y: y), withAttributes: bodyAttrs)

            // Page 2 — Summary
            context.beginPage()
            bgColor.setFill()
            UIRectFill(pageRect)

            y = margin + 20
            "Dispute Summary".draw(at: CGPoint(x: margin, y: y), withAttributes: headingAttrs)
            y += 34

            let summaryText = dispute.summary.isEmpty ? "No summary provided." : dispute.summary
            let summaryRect = CGRect(x: margin, y: y, width: contentWidth, height: 400)
            (summaryText as NSString).draw(in: summaryRect, withAttributes: bodyAttrs)

            // Page 3 — Evidence summary
            context.beginPage()
            bgColor.setFill()
            UIRectFill(pageRect)

            y = margin + 20
            "Evidence Summary".draw(at: CGPoint(x: margin, y: y), withAttributes: headingAttrs)
            y += 34

            let rows: [(String, String)] = [
                ("Total evidence entries", "\(evidenceCount)"),
                ("Total photos", "\(photoCount)"),
                ("Documents attached", "\(documentCount)"),
                ("Rooms documented", "\(property.rooms.count)")
            ]

            for (label, value) in rows {
                label.draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)
                value.draw(at: CGPoint(x: pageRect.width - margin - 80, y: y), withAttributes: bodyAttrs)
                y += 24
            }

            y += 16
            for room in property.rooms {
                let moveIn = room.evidence.count
                let moveOut = room.moveOutEvidence.count
                room.name.draw(at: CGPoint(x: margin, y: y), withAttributes: bodyAttrs)
                "In: \(moveIn)  Out: \(moveOut)".draw(at: CGPoint(x: pageRect.width - margin - 120, y: y), withAttributes: labelAttrs)
                y += 22
                if y > pageRect.height - margin { break }
            }

            // Page 4 — Landlord info
            context.beginPage()
            bgColor.setFill()
            UIRectFill(pageRect)

            y = margin + 20
            "Landlord & Property Details".draw(at: CGPoint(x: margin, y: y), withAttributes: headingAttrs)
            y += 34

            let details: [(String, String)] = [
                ("Landlord", property.landlordName.isEmpty ? "Not provided" : property.landlordName),
                ("Email", property.landlordEmail.isEmpty ? "Not provided" : property.landlordEmail),
                ("Phone", property.landlordPhone.isEmpty ? "Not provided" : property.landlordPhone),
                ("Deposit", property.depositAmount)
            ]

            for (label, value) in details {
                label.draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)
                y += 18
                value.draw(at: CGPoint(x: margin, y: y), withAttributes: bodyAttrs)
                y += 26
            }
        }

        return data
    }

    static func generateMoveInReport(property: PropertyRecord, rooms: [RoomRecord]) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 50
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { context in
            let textColor = UIColor(red: 0.95, green: 0.93, blue: 0.90, alpha: 1.0)
            let bgColor = UIColor(red: 0.03, green: 0.03, blue: 0.04, alpha: 1.0)
            let bodyFont = UIFont.systemFont(ofSize: 14, weight: .regular)
            let headingFont = UIFont.systemFont(ofSize: 20, weight: .semibold)
            let titleFont = UIFont.systemFont(ofSize: 28, weight: .bold)
            let labelFont = UIFont.systemFont(ofSize: 12, weight: .medium)
            let secondaryColor = UIColor(red: 0.60, green: 0.57, blue: 0.54, alpha: 1.0)

            let bodyAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: textColor]
            let headingAttrs: [NSAttributedString.Key: Any] = [.font: headingFont, .foregroundColor: textColor]
            let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: textColor]
            let labelAttrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: secondaryColor]

            context.beginPage()
            bgColor.setFill()
            UIRectFill(pageRect)

            var y: CGFloat = margin + 40
            "Move-In Report".draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
            y += 44
            property.addressLine1.draw(at: CGPoint(x: margin, y: y), withAttributes: bodyAttrs)
            y += 30

            for room in rooms {
                if y > pageRect.height - 100 {
                    context.beginPage()
                    bgColor.setFill()
                    UIRectFill(pageRect)
                    y = margin + 20
                }

                room.name.draw(at: CGPoint(x: margin, y: y), withAttributes: headingAttrs)
                y += 28
                "Evidence entries: \(room.evidence.count)".draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)
                y += 20

                for evidence in room.evidence {
                    if y > pageRect.height - 60 {
                        context.beginPage()
                        bgColor.setFill()
                        UIRectFill(pageRect)
                        y = margin + 20
                    }
                    "• \(evidence.title) — \(evidence.condition.rawValue) — \(evidence.photoCount) photos".draw(
                        at: CGPoint(x: margin + 16, y: y),
                        withAttributes: bodyAttrs
                    )
                    y += 20
                }
                y += 12
            }
        }
    }

    static func generateMoveOutReport(property: PropertyRecord, rooms: [RoomRecord]) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 50
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { context in
            let textColor = UIColor(red: 0.95, green: 0.93, blue: 0.90, alpha: 1.0)
            let bgColor = UIColor(red: 0.03, green: 0.03, blue: 0.04, alpha: 1.0)
            let bodyFont = UIFont.systemFont(ofSize: 14, weight: .regular)
            let headingFont = UIFont.systemFont(ofSize: 20, weight: .semibold)
            let titleFont = UIFont.systemFont(ofSize: 28, weight: .bold)
            let labelFont = UIFont.systemFont(ofSize: 12, weight: .medium)
            let secondaryColor = UIColor(red: 0.60, green: 0.57, blue: 0.54, alpha: 1.0)

            let bodyAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: textColor]
            let headingAttrs: [NSAttributedString.Key: Any] = [.font: headingFont, .foregroundColor: textColor]
            let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: textColor]
            let labelAttrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: secondaryColor]

            context.beginPage()
            bgColor.setFill()
            UIRectFill(pageRect)

            var y: CGFloat = margin + 40
            "Move-Out Report".draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
            y += 44
            property.addressLine1.draw(at: CGPoint(x: margin, y: y), withAttributes: bodyAttrs)
            y += 30

            for room in rooms {
                if y > pageRect.height - 120 {
                    context.beginPage()
                    bgColor.setFill()
                    UIRectFill(pageRect)
                    y = margin + 20
                }

                room.name.draw(at: CGPoint(x: margin, y: y), withAttributes: headingAttrs)
                y += 28
                "Before: \(room.evidence.count) entries  |  After: \(room.moveOutEvidence.count) entries".draw(
                    at: CGPoint(x: margin, y: y),
                    withAttributes: labelAttrs
                )
                y += 24

                for evidence in room.moveOutEvidence {
                    if y > pageRect.height - 60 {
                        context.beginPage()
                        bgColor.setFill()
                        UIRectFill(pageRect)
                        y = margin + 20
                    }
                    "• \(evidence.title) — \(evidence.condition.rawValue) — \(evidence.photoCount) photos".draw(
                        at: CGPoint(x: margin + 16, y: y),
                        withAttributes: bodyAttrs
                    )
                    y += 20
                }
                y += 12
            }
        }
    }
}
