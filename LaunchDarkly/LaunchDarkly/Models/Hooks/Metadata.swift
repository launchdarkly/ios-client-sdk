import Foundation

/// Metadata data class used for annotating hook implementations.
public class Metadata {
    private let name: String

    /// Initialize a new Metadata instance with the provided name.
    public init(name: String) {
        self.name = name
    }
}
