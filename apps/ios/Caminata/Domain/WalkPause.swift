import Foundation

/// A stretch of a walk that was paused. An open pause -- no end yet -- is the
/// walk being paused right now.
struct WalkPause: Equatable, Codable, Sendable {
    var start: Date
    var end: Date?

    /// How much of this pause falls inside `range`, with an open pause running
    /// to the end of the range.
    func overlap(with range: ClosedRange<Date>) -> TimeInterval {
        let from = max(start, range.lowerBound)
        let to = min(end ?? range.upperBound, range.upperBound)
        return max(0, to.timeIntervalSince(from))
    }
}

extension Array where Element == WalkPause {
    /// True when a pause began between two consecutive fixes, which is what
    /// makes them belong to different stretches of the walk.
    func separates(_ earlier: Date, _ later: Date) -> Bool {
        contains { $0.start >= earlier && $0.start <= later }
    }

    func pausedTime(within range: ClosedRange<Date>) -> TimeInterval {
        reduce(0) { $0 + $1.overlap(with: range) }
    }
}
