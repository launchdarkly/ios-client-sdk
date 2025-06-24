import Foundation

/// Metadata used for annotating plugin implementations.
///
public class PluginMetadata {
    private let name: String
    
    ///
    public init(name: String) {
        self.name = name
    }
    
    ///
    public func getName() -> String {
        return name
    }
}
