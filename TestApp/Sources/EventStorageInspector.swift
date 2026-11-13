import CryptoKit
import Foundation

/// What the SDK has left in this app's event directory: the logs live processes append to and the batches waiting to
/// be delivered.
///
/// Read from the file names and sizes alone, and never opened, so looking cannot change what it looks at: a lock taken
/// to see whether a log is held would stop another instance's recovery from claiming it.
@MainActor
final class EventStorageInspector: ObservableObject {
    struct Entry: Identifiable, Equatable {
        enum Kind: String {
            /// `pending-`: a log a process appends to, or one a dead process left for recovery.
            case log
            /// `new-`: a log being created.
            case opening
            /// `ready-<payloadId>.<count>`: a batch closed for delivery.
            case batch
            case other
        }

        let name: String
        let kind: Kind
        let bytes: Int
        let modified: Date?
        /// What a batch's name says it holds.
        let events: Int?

        var id: String { name }
    }

    @Published private(set) var entries: [Entry] = []
    @Published private(set) var directoryExists = false

    let directory: URL
    private var timer: Timer?

    init(mobileKey: String) {
        directory = Self.directory(mobileKey: mobileKey)
    }

    var summary: String {
        guard directoryExists
        else { return "Nothing stored yet" }
        let logs = entries.filter { $0.kind == .log }.count
        let batches = entries.filter { $0.kind == .batch }
        let events = batches.compactMap(\.events).reduce(0, +)
        return "\(logs) log(s), \(batches.count) batch(es) holding \(events) event(s)"
    }

    func startWatching() {
        refresh()
        guard timer == nil
        else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stopWatching() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        guard let contents = try? FileManager.default.contentsOfDirectory(at: directory,
                                                                          includingPropertiesForKeys: keys,
                                                                          options: [.skipsHiddenFiles])
        else {
            directoryExists = false
            entries = []
            return
        }
        directoryExists = true
        entries = contents.map { url in
            let values = try? url.resourceValues(forKeys: Set(keys))
            let name = url.lastPathComponent
            return Entry(name: name, kind: Self.kind(of: name), bytes: values?.fileSize ?? 0,
                         modified: values?.contentModificationDate, events: Self.events(inBatchNamed: name))
        }
        .sorted { ($0.modified ?? .distantPast, $0.name) < ($1.modified ?? .distantPast, $1.name) }
    }

    private static func kind(of name: String) -> Entry.Kind {
        if name.hasPrefix("pending-") { return .log }
        if name.hasPrefix("new-") { return .opening }
        if name.hasPrefix("ready-") { return .batch }
        return .other
    }

    private static func events(inBatchNamed name: String) -> Int? {
        guard name.hasPrefix("ready-")
        else { return nil }
        let fields = name.dropFirst("ready-".count).split(separator: ".", omittingEmptySubsequences: false)
        return fields.count > 1 ? Int(fields[1]) : nil
    }

    /// Where the SDK keeps events for this application and mobile key: the same path `EventDirectory.defaultUrl`
    /// works out, which is internal to the SDK.
    private static func directory(mobileKey: String) -> URL {
        #if os(tvOS)
        let searchPath = FileManager.SearchPathDirectory.cachesDirectory
        #else
        let searchPath = FileManager.SearchPathDirectory.applicationSupportDirectory
        #endif
        let root = FileManager.default.urls(for: searchPath, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        var keyComponent = hash(mobileKey)
        if let bundleId = Bundle.main.bundleIdentifier {
            keyComponent = "\(hash(bundleId)).\(keyComponent)"
        }
        return root
            .appendingPathComponent("com.launchdarkly.events", isDirectory: true)
            .appendingPathComponent(keyComponent, isDirectory: true)
    }

    private static func hash(_ value: String) -> String {
        Data(SHA256.hash(data: Data(value.utf8))).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
    }
}
