//
//  DateRangeCompact.swift
//  Rangle
//
//  Created by Anthony Guzzardo on 8/11/25.
//
/// Compact start+duration picker that derives `end` from `start + duration`.
import SwiftUI

/// Start → End picker with hh:mm; End is disabled until Start is picked.
/// Guarantees end >= start.
struct DateRangeCompact: View {
    @Binding var dttmStart  : Date
    @Binding var dttmEnd    : Date

    @State private var hasPickedStart = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // START
            VStack(alignment: .leading, spacing: 6)
            {
                Text("Start")
                    .font(.caption).foregroundStyle(UkiyoPalette.Semantic.metaText)

                DatePicker(
                    "",
                    selection: $dttmStart,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .onChange(of: dttmStart) { _, newVal in
                    hasPickedStart = true
                    if dttmEnd < newVal { dttmEnd = newVal }   // clamp
                }
            }
            // END
            VStack(alignment: .leading, spacing: 6)
            {
                Text("End")
                    .font(.caption).foregroundStyle(UkiyoPalette.Semantic.metaText)

                ZStack(alignment: .leading) {
                    // Keep layout stable, but non-interactive + virtually invisible until enabled
                    DatePicker(
                        "",
                        selection: $dttmEnd,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .opacity(hasPickedStart ? 1 : 0.001)          // 0 makes it lose layout in some cases
                    .allowsHitTesting(hasPickedStart)

                    if !hasPickedStart {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                            Text("Pick a start first")
                                .font(.footnote)
                                .foregroundStyle(UkiyoPalette.Semantic.metaText)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(UkiyoPalette.Semantic.cardWhiteBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(UkiyoPalette.Blues.blueGrey.opacity(0.25), lineWidth: 1)
                        )
                    }
                }
            }
            .onChange(of: dttmEnd) { _, newVal in
                if newVal < dttmStart { dttmEnd = dttmStart }
            }

        }
        .onAppear {
            // initialize: if end < start, align it; don't auto-enable until user touches start
            if dttmEnd < dttmStart { dttmEnd = dttmStart }
        }
    }
}
