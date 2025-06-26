import Foundation

/// Metadata used for annotating plugin implementations.
///
/// This class provides identifying information about a plugin, primarily used
/// for logging and debugging purposes.
public class PluginMetadata {
    /// The name of the plugin.
    private let name: String

    /// Initialize plugin metadata.
    ///
    /// - Parameter name: The name of the plugin for identification purposes
    public init(name: String) {
        self.name = name
    }

    /// Get the name of the plugin.
    ///
    /// - Returns: The name of the plugin for identification purposes
    public func getName() -> String {
        return name
    }
}
