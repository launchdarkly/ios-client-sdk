import Foundation

/// Protocol for extending SDK functionality via plugins.
public protocol Plugin {
    func getMetadata() -> PluginMetadata
    
    func register(client: LDClient, metadata: EnvironmentMetadata)
    
    func getHooks(metadata: EnvironmentMetadata) -> [Hook]
}

public extension Plugin {
    func getHooks(metadata: EnvironmentMetadata) -> [Hook] {
        return []
    }
}
