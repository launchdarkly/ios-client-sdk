import Foundation

/// Contextual information that will be provided to handlers during track series.
public class TrackSeriesContext {
    /// The key for the event being tracked.
    public let key: String
    /// The context associated with the track operation.
    public let context: LDContext
    /// The data associated with the track operation, if any.
    public let data: LDValue?
    /// The metric value associated with the track operation, if any.
    public let metricValue: Double?

    init(key: String, context: LDContext, data: LDValue?, metricValue: Double?) {
        self.key = key
        self.context = context
        self.data = data
        self.metricValue = metricValue
    }
}
