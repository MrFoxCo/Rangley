import Foundation

public enum DateFormatters {
    public static let yyyyMMddUTC: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.locale   = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    public static let yyyyMMddHHmmssZ: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.locale   = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        return f
    }()
}

public enum DateMath {
    /// Combine a calendar *date* and a *time-of-day* into a single Date.
    /// - Defaults to UTC. Pass a TZ if you want local semantics (e.g., "America/Chicago").
    /// - Returns nil if the time doesn't exist (DST spring-forward gap) under `.strict` policy.
    @inlinable
    public static func combineDateAndTime(
        date: Date,
        time: Date,
        tz: TimeZone = TimeZone(secondsFromGMT: 0)!,
        matchingPolicy: Calendar.MatchingPolicy = .strict,
        repeatedPolicy: Calendar.RepeatedTimePolicy = .first,
        direction: Calendar.SearchDirection = .forward
    ) -> Date? {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = tz

        // Pull just the time-of-day components (cheap)
        let t = cal.dateComponents([.hour, .minute, .second], from: time)
        guard let h = t.hour, let m = t.minute else { return nil }

        // Let Calendar do the heavy lifting (DST-safe, optimized)
        return cal.date(
            bySettingHour: h,
            minute: m,
            second: t.second ?? 0,
            of: date,
            matchingPolicy: matchingPolicy,
            repeatedTimePolicy: repeatedPolicy,
            direction: direction
        )
    }

    /// Convenience: a non-optional version that "finds the next valid time" if the exact time is invalid.
    /// Useful in UI flows during DST transitions.
    @inlinable
    public static func combineDateAndTimeLenient(
        date: Date,
        time: Date,
        tz: TimeZone = TimeZone(secondsFromGMT: 0)!
    ) -> Date {
        // .nextTime will skip over gaps; .first takes first occurrence on repeated hours (fall-back)
        combineDateAndTime(
            date: date,
            time: time,
            tz: tz,
            matchingPolicy: .nextTime,
            repeatedPolicy: .first,
            direction: .forward
        )!
    }
}

public enum MeetStatusId: Int {
    case NULL_VALUE = 0
    case Active
    case Cancelled
    case Postponed
    case Completed
    case Draft
    case Full
    case Deleted
}

