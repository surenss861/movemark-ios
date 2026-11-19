//
//  LegalAgeBandHandoffTests.swift
//  movemorkTests
//
//  P0 regression (2026-11-18): on the agreement screen, "18 or older" reached the server as '13_17'. The screen
//  computed `.adult`, but the value arrived in the `onAccept` closure as `.teen`. The band is handed from the
//  screen to the session through that stored async closure; this pins that every answer arrives unchanged.
//

import Foundation
import Testing
@testable import MoveMark

@MainActor
struct LegalAgeBandHandoffTests {
    private final class Box { var received: [LegalAgeBand?] = [] }

    @Test(arguments: [LegalAgeBand?.some(.adult), .some(.teen), .none])
    func theScreenHandsTheChosenBandToAcceptUnchanged(_ band: LegalAgeBand?) async {
        let box = Box()
        let screen = LegalAcceptanceScreen(termsURL: nil, privacyURL: nil, age: .ageRangeQuebec,
                                           onAccept: { received in
                                               box.received.append(received)
                                               return nil
                                           })
        _ = await screen.onAccept(band)
        #expect(box.received == [band])
    }

    @Test func anAdultAnswerOnTheScreenIsSentAsEighteenPlus() async {
        let box = Box()
        let screen = LegalAcceptanceScreen(termsURL: nil, privacyURL: nil, age: .ageRangeQuebec,
                                           onAccept: { received in
                                               box.received.append(received)
                                               return nil
                                           },
                                           livesInQuebec: false, ageChoice: .adult)
        #expect(screen.chosenBand == .adult)
        _ = await screen.onAccept(screen.chosenBand)
        #expect(box.received == [.adult])
        #expect(box.received.first??.rawValue == "18_plus")
    }

    /// The same hand-off shape elsewhere: Edit evidence passes the chosen condition through a stored async closure.
    @Test(arguments: RoomRecord.ConditionRating.allCases)
    func editEvidenceHandsTheChosenConditionToSaveUnchanged(_ condition: RoomRecord.ConditionRating) async {
        final class Seen { var conditions: [RoomRecord.ConditionRating] = []; var titles: [String] = [] }
        let seen = Seen()
        let evidence = EvidenceRecord(title: "Walls", notes: "", issueTags: [], condition: .good, createdAt: .now,
                                      photoCount: 1, photos: [], stage: .moveIn)
        let sheet = EditEvidenceSheet(evidence: evidence, roomName: "Kitchen",
                                      onSave: { title, _, _, chosen in
                                          seen.titles.append(title)
                                          seen.conditions.append(chosen)
                                          return nil
                                      },
                                      onDismiss: {})
        _ = await sheet.onSave("Walls", "", [], condition)
        #expect(seen.conditions == [condition])
        #expect(seen.titles == ["Walls"])
    }

    /// Control for the same shape with a String argument (Account › Edit name).
    @Test func editNameHandsTheTypedNameToSaveUnchanged() async throws {
        final class Seen { var names: [String] = [] }
        let seen = Seen()
        let sheet = EditNameSheet(currentName: "Alex", onSave: { name in seen.names.append(name) })
        try await sheet.onSave("Alex Rivera")
        #expect(seen.names == ["Alex Rivera"])
    }
}
