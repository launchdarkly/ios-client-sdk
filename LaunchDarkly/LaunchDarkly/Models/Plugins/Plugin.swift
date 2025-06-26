import Foundation

/// Protocol for extending SDK functionality via plugins.
///
/// Plugins provide a way to extend the functionality of the LaunchDarkly SDK. A plugin can register hooks
/// that are called during flag evaluation, and can perform initialization when registered with a client instance.
///
/// Plugin implementations should be thread-safe as they may be called concurrently from multiple threads.
///
/// ## Usage Example
///
/// ```swift
/// class MyPlugin: Plugin {
///     func getMetadata() -> PluginMetadata {
///         return PluginMetadata(name: "MyPlugin")
///     }
///
///     func register(client: LDClient, metadata: EnvironmentMetadata) {
///         // Perform plugin initialization
///     }
///
///     func getHooks(metadata: EnvironmentMetadata) -> [Hook] {
///         return [MyHook()]
///     }
/// }
///
/// let config = LDConfig.Builder(mobileKey: "your-mobile-key")
///     .plugins([MyPlugin()])
///     .build()
/// ```
public protocol Plugin {
    /// Get metadata about the plugin implementation.
    ///
    /// - Returns: The plugin metadata containing identifying information about the plugin.
    func getMetadata() -> PluginMetadata

    /// Register the plugin with a client instance.
    ///
    /// This method is called once for each client instance when the SDK is initialized. If
    /// the SDK is configured with multiple environments, this method will be called once for each
    /// environment with the respective credential. Use the metadata to distinguish environments.
    ///
    /// - Parameters:
    ///   - client: The client instance for the plugin to use
    ///   - metadata: Metadata about the environment where the plugin is running
    func register(client: LDClient, metadata: EnvironmentMetadata)

    /// Get hooks that should be registered with the SDK.
    ///
    /// This method is called during SDK initialization to collect hooks from all plugins. If
    /// the SDK is configured with multiple environments, this method will be called once for each
    /// environment. Use the metadata to distinguish environments.
    ///
    /// - Parameter metadata: Metadata about the environment where the plugin is running
    /// - Returns: An array of hooks to be registered with the SDK
    func getHooks(metadata: EnvironmentMetadata) -> [Hook]
}

public extension Plugin {
    /// Get hooks that should be registered with the SDK.
    ///
    /// Default implementation returns an empty array. Override this method to provide hooks.
    ///
    /// - Parameter metadata: Metadata about the environment where the plugin is running
    /// - Returns: An empty array of hooks by default
    func getHooks(metadata: EnvironmentMetadata) -> [Hook] {
        return []
    }
}
