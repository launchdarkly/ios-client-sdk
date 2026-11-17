import Foundation

/// A batch the filesystem would not take, kept where the SDK used to keep all of them.
struct HeldBatch {
    let payloadId: String
    let body: Data
    let eventCount: Int
    /// How many of `eventCount` are summaries.
    let summaries: Int
}

/// Everything staged, taken out of the buffers in one step: the full events, then the summaries.
struct StagedFrames {
    let frames: Data
    /// Where in `frames` the summaries start.
    let summariesFrom: Int
    /// Every frame in `frames`, summaries included.
    let events: Int
    let summaries: Int

    /// How many of the frames from `start` up to `end` are summaries.
    func summaries(from start: Int, to end: Int) -> Int {
        end <= summariesFrom ? 0 : EventLogFormat.frameCount(in: frames, from: max(start, summariesFrom), to: end)
    }
}
