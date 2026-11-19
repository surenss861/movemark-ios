//
//  MMReceiptQAFixture.swift
//  movemork
//
//  DEBUG only: `-MMRichQA receipt-saved | receipt-partial | receipt-complete` renders the production
//  ProofSavedReceiptView (Living Room, Move-in) for simulator visual QA. The photo is read from the app's tmp
//  directory (`mm-qa-receipt.jpg`, copied in by the QA script); without it the receipt shows its no-photo state.
//
//  @file Debug-only fixture: the saved-proof receipt in its three states
//  @domain evidence
//  @status stable
//  @see [[ProofSavedReceiptView.swift]]
//

#if DEBUG
import SwiftUI

struct MMReceiptQAScreen: View {
    let screen: String

    private var model: ProofSavedReceiptModel {
        let photo = FileManager.default.temporaryDirectory.appendingPathComponent("mm-qa-receipt.jpg")
        let url = FileManager.default.fileExists(atPath: photo.path) ? photo : nil
        let savedAt = Calendar.current.date(bySettingHour: 15, minute: 18, second: 0, of: Date()) ?? Date()
        switch screen {
        case "receipt-partial":
            return ProofSavedReceiptModel(roomName: "Living Room", photoCount: 3, pendingCount: 1, issueCount: 1,
                                          savedAt: savedAt, imageURL: url, primaryActionLabel: "Retry 1 photo")
        case "receipt-device-time":
            // No server created_at came back: the time is labelled as this device's.
            return ProofSavedReceiptModel(roomName: "Living Room", photoCount: 4, issueCount: 1, savedAt: savedAt,
                                          savedAtFromServer: false, imageURL: url,
                                          primaryActionLabel: "Continue to next room")
        case "receipt-complete":
            return ProofSavedReceiptModel(roomName: "Living Room", photoCount: 4, savedAt: savedAt, imageURL: url,
                                          primaryActionLabel: "View move-in report")
        default:
            return ProofSavedReceiptModel(roomName: "Living Room", photoCount: 4, issueCount: 1, savedAt: savedAt,
                                          imageURL: url, primaryActionLabel: "Continue to next room")
        }
    }

    var body: some View {
        ProofSavedReceiptView(model: model, onPrimary: {}, onSecondary: {},
                              onAddMorePhotos: screen == "receipt-partial" ? nil : {})
            .preferredColorScheme(.dark)
    }
}
#endif
