//
//  MeetCreation.swift
//  Rangle
//
//  Created by Anthony Guzzardo on 8/1/25.
//
// Views/CreateMeet.swift
import SwiftUI
import Foundation
import SQLite3

public struct CreateMeet: View {
    let meetBatch: MeetBatch
    var onCreated: () -> Void = {}

    @State private var draft = CreateMeetDraft()
    @State private var categories: [MeetCategory] = []
    @State private var dbError: Error?

    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        CreateMeetCard(
            draft       : $draft,
            categories  : categories,
            onStart     : { createMeet() },
            onCancel    : { dismiss() }
        )
        .onAppear {
            // dynamic categories via your helper
            categories = DbRangle.loadCategories(DbManager.shared.database)

            // seed place name from batch
            if draft.placeName == nil {
                draft.placeName = meetBatch.LocationInfo?.Name ?? meetBatch.LocationInfo?.Locality
            }
            // if draft category empty, pick first available
            if draft.categoryName.isEmpty, let first = categories.first {
                draft.categoryName = first.Name
            }
            // normalize times
            if draft.dttmEnd <= draft.dttmStart {
                draft.dttmEnd = draft.dttmStart.addingTimeInterval(60 * 60)
            }
        }
    }

    private func createMeet() {
        // basic validation / normalization
        var name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if name.count > 40 { name = String(name.prefix(40)) }

        var desc = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if desc.count > 100 { desc = String(desc.prefix(100)) }

        let start = draft.dttmStart
        let end   = draft.dttmEnd
        guard end >= start else { return }

        let epochRange = EpochRange(start, end)

        let selectedCategory = categories.first { $0.Name.caseInsensitiveCompare(draft.categoryName) == .orderedSame }
                             ?? categories.first

        let selectedMeetCategoryId = selectedCategory?.MeetCategoryId ?? 0

        let meet = Meet(
            ChangeStamp: nil,
            Name: name,
            Description: desc.isEmpty ? nil : desc,
            ChangeReason: nil,
            MeetCategoryId: selectedMeetCategoryId,
            MaxCapacity: Int64(max(2, draft.capacity)),
            EpochRange: epochRange
        )

        meetBatch.Meet = meet
        let (ok, err) = DbRangle.tryProcInsertMeet(DbManager.shared.database, meetBatch: meetBatch)
        if ok {
            print("Successfully inserted meet (MeetID: \(meetBatch.MeetId ?? -1))")

            // remember the last category for next time
            UserDefaults.standard.set(draft.categoryName, forKey: "lastCategory")

            dismiss()
            onCreated()
        } else {
            print("Error inserting meet: \(err?.localizedDescription ?? "unknown")")
        }

    }
}
