import Foundation

// ---------- Keep only if you still need day bucketing for reports ----------
@usableFromInline @inline(__always)
internal func epochDayUTC(_ date: Date) -> Int32 {
    // floor makes pre-1970 safe too
    let s = date.timeIntervalSince1970
    return Int32(floor(s / 86_400.0))
}

@usableFromInline @inline(__always)
internal func dateAtUTCStartOfDay(_ day: Int32) -> Date {
    Date(timeIntervalSince1970: TimeInterval(day) * 86_400.0)
}
// ---------------------------------------------------------------------------


// Precise UTC seconds range for storage/API.
public struct EpochRange: Sendable, Hashable, Codable, CustomStringConvertible {
    public let startEpoch: Int64   // inclusive, seconds since 1970-01-01T00:00:00Z
    public let endEpoch:   Int64   // inclusive

    @inlinable
    public init(_ start: Date, _ end: Date) {
        precondition(start <= end, "Start must be <= end")
        // DatePicker is minute-granular; flooring keeps it stable.
        self.startEpoch = Int64(floor(start.timeIntervalSince1970))
        self.endEpoch   = Int64(floor(end.timeIntervalSince1970))
    }

    @inlinable
    public init(_ startEpoch: Int64, _ endEpoch: Int64) {
        precondition(startEpoch <= endEpoch, "Start must be <= end")
        self.startEpoch = startEpoch
        self.endEpoch   = endEpoch
    }

    @inlinable public var startDate: Date { Date(timeIntervalSince1970: TimeInterval(startEpoch)) }
    @inlinable public var endDate:   Date { Date(timeIntervalSince1970: TimeInterval(endEpoch)) }

    // Optional: quick day buckets when you need them
    @inlinable public var startDayUTC: Int32 { Int32(startEpoch / 86_400) }
    @inlinable public var endDayUTC:   Int32 { Int32(endEpoch   / 86_400) }

    public var description: String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.locale   = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return "\(f.string(from: startDate))_\(f.string(from: endDate))"
    }
}
