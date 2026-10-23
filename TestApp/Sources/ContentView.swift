import LaunchDarkly
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var controller: ClientController

    var body: some View {
        NavigationStack {
            Form {
                ClientSection()
                FlagSection()
                EventsSection()
                EventLossSection()
                StressSection()
                StorageSection(mobileKey: controller.configuration.mobileKey)
                DedupeSection()
            }
            .compactForm()
            .navigationTitle(title)
            .inlineTitle()
        }
    }

    private var title: String {
        InstanceLauncher.isAvailable ? "LD Test App · pid \(InstanceLauncher.processId)" : "LD Test App"
    }
}

// MARK: - Sections

private struct ClientSection: View {
    @EnvironmentObject private var controller: ClientController

    var body: some View {
        Section {
            Text(controller.connectionStatus)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            if !controller.result.isEmpty {
                Text(controller.result)
                    .font(.caption)
                    .lineLimit(4)
                    .accessibilityIdentifier("result")
            }
            Picker("Persistence", selection: Binding(get: { controller.persistence },
                                                     set: { controller.setPersistence($0) })) {
                ForEach(EventPersistence.choices, id: \.rawValue) { Text($0.name).tag($0) }
            }
            .segmentedWherePossible()
            .disabled(controller.isRestarting)
            .accessibilityIdentifier("persistence_picker")
            #if os(tvOS) || os(watchOS)
            offlineToggle
            #endif
            ButtonRow {
                ActionButton("Restart", id: "restart_client_button") { controller.restart() }
                    .disabled(controller.isRestarting || controller.configuration.isMissingMobileKey)
                ActionButton("Flush", id: "flush_button") { controller.client?.flush() }
                ActionButton("Flush+Wait", id: "flush_and_wait_button") { flushAndWait() }
            }
        } header: {
            HStack {
                Text("Client · \(controller.configuration.environmentName)")
                #if !os(tvOS) && !os(watchOS)
                Spacer()
                offlineToggle
                    .textCase(nil)
                #endif
            }
        }
    }

    private var offlineToggle: some View {
        Toggle("Offline", isOn: Binding(get: { controller.isOffline }, set: { controller.setOffline($0) }))
            .fixedSize()
            .accessibilityIdentifier("offline_toggle")
    }

    /// Off the main thread, since it blocks for as long as the delivery takes, up to the timeout.
    private func flushAndWait() {
        guard let client = controller.client
        else { return }
        let controller = self.controller
        controller.result = "Flushing…"
        DispatchQueue.global(qos: .userInitiated).async {
            let started = Date()
            let delivered = client.flushAndWait(timeout: 5)
            let elapsed = Date().timeIntervalSince(started)
            Task { @MainActor in
                controller.result = String(format: "flushAndWait: %@ in %.2f s", delivered ? "delivered" : "not delivered", elapsed)
            }
        }
    }
}

private struct FlagSection: View {
    enum FlagType: String, CaseIterable, Identifiable {
        case bool = "Bool"
        case int = "Int"
        case double = "Double"
        case string = "String"
        case json = "JSON"

        var id: String { rawValue }
    }

    @EnvironmentObject private var controller: ClientController
    @State private var flagKey = ""
    @State private var type = FlagType.bool

    var body: some View {
        Section("Flag") {
            ButtonRow {
                TextField("flag key", text: $flagKey)
                    .plainKeyEntry()
                    .accessibilityIdentifier("flag_key_field")
                Picker("Type", selection: $type) {
                    ForEach(FlagType.allCases) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                ActionButton("Eval", id: "eval_button") { evaluate() }
            }
        }
    }

    private func evaluate() {
        let key = flagKey.trimmingCharacters(in: .whitespaces)
        guard let client = controller.client, !key.isEmpty
        else { return }
        let controller = self.controller
        controller.countEvaluation()
        controller.result = "\(key) = \(describe(client, key))"
        client.observe(key: key, owner: controller) { [weak controller] changed in
            Task { @MainActor in
                guard let controller, let client = controller.client
                else { return }
                controller.countEvaluation()
                controller.result = "\(changed.key) changed to \(describe(client, changed.key))"
            }
        }
    }

    private func describe(_ client: LDClient, _ key: String) -> String {
        switch type {
        case .bool: return String(client.boolVariation(forKey: key, defaultValue: false))
        case .int: return String(client.intVariation(forKey: key, defaultValue: 0))
        case .double: return String(client.doubleVariation(forKey: key, defaultValue: 0))
        case .string: return client.stringVariation(forKey: key, defaultValue: "default")
        case .json: return String(describing: client.jsonVariation(forKey: key, defaultValue: .null))
        }
    }
}

private struct EventsSection: View {
    @EnvironmentObject private var controller: ClientController
    @State private var userKey = ""

    var body: some View {
        Section("Events") {
            ButtonRow {
                TextField(ClientController.defaultUserKey, text: $userKey)
                    .plainKeyEntry()
                    .accessibilityIdentifier("user_key_field")
                ActionButton("Identify", id: "identify_button") { controller.identify(key: userKey) }
                ActionButton("Track", id: "track_button") { controller.client?.track(key: "Apple event name") }
            }
        }
    }
}

private struct EventLossSection: View {
    @EnvironmentObject private var controller: ClientController
    @State private var flagKey = Scenarios.defaultKillFlag

    var body: some View {
        Section {
            TextField(Scenarios.defaultKillFlag, text: $flagKey)
                .plainKeyEntry()
                .accessibilityIdentifier("kill_flag_key_field")
            ButtonRow {
                ActionButton("Kill 5s", tint: .red, id: "kill_unsent_button") {
                    Scenarios.evalTrackFlushThenKill(controller.client, flagKey: killFlag)
                }
                ActionButton("Kill now", tint: .red, id: "kill_now_button") {
                    Scenarios.evalTrackThenKillNow(controller.client, flagKey: killFlag)
                }
                ActionButton("Fatal now", tint: .red, id: "fatal_now_button") {
                    Scenarios.evalTrackThenFatalErrorNow(controller.client, flagKey: killFlag)
                }
            }
        } header: {
            Text("Event loss · eval + track, then")
        } footer: {
            Text("Kill 5s flushes first: arrives this launch. Kill now and Fatal now: next launch only.")
        }
    }

    private var killFlag: String {
        let key = flagKey.trimmingCharacters(in: .whitespaces)
        return key.isEmpty ? Scenarios.defaultKillFlag : key
    }
}

private struct StressSection: View {
    @EnvironmentObject private var controller: ClientController

    var body: some View {
        Section("Stress") {
            ButtonRow {
                ActionButton("Over-refresh", tint: .orange, id: "over_refresh_button") {
                    let capacity = controller.config?.eventCapacity ?? 0
                    if let result = Scenarios.overRefreshEval(controller.client, eventCapacity: capacity) {
                        controller.result = result
                    }
                }
                ActionButton("Fill 3 batches", tint: .orange, id: "fill_batches_button") {
                    if let result = Scenarios.fillBatches(controller.client) {
                        controller.result = result
                    }
                }
            }
        }
    }
}

private struct StorageSection: View {
    @EnvironmentObject private var controller: ClientController
    @StateObject private var inspector: EventStorageInspector

    init(mobileKey: String) {
        _inspector = StateObject(wrappedValue: EventStorageInspector(mobileKey: mobileKey))
    }

    var body: some View {
        Section {
            Text(inspector.summary)
                .font(.callout)
                .accessibilityIdentifier("storage_summary")
            ForEach(inspector.entries) { entry in
                HStack(spacing: 6) {
                    Image(systemName: symbol(for: entry.kind))
                        .foregroundStyle(entry.kind == .batch ? Color.accentColor : .secondary)
                    Text(entry.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 4)
                    Text(describe(entry))
                        .foregroundStyle(.secondary)
                }
                .font(.caption.monospaced())
            }
        } header: {
            HStack {
                Text("Event storage")
                if InstanceLauncher.isAvailable {
                    Spacer()
                    Button("New instance") { controller.result = InstanceLauncher.launchAnother() }
                        .textCase(nil)
                        .accessibilityIdentifier("launch_instance_button")
                }
            }
        } footer: {
            Text(inspector.directory.path)
                .selectableWherePossible()
        }
        .onAppear { inspector.startWatching() }
        .onDisappear { inspector.stopWatching() }
    }

    private func symbol(for kind: EventStorageInspector.Entry.Kind) -> String {
        switch kind {
        case .log: return "pencil.line"
        case .opening: return "doc.badge.plus"
        case .batch: return "shippingbox"
        case .other: return "doc"
        }
    }

    private func describe(_ entry: EventStorageInspector.Entry) -> String {
        var parts: [String] = []
        if let events = entry.events {
            parts.append("\(events) ev")
        }
        parts.append(ByteCountFormatter.string(fromByteCount: Int64(entry.bytes), countStyle: .file))
        if let modified = entry.modified {
            parts.append(modified.formatted(date: .omitted, time: .shortened))
        }
        return parts.joined(separator: " · ")
    }
}

private struct DedupeSection: View {
    @EnvironmentObject private var controller: ClientController

    var body: some View {
        Section("Exposure dedupe · before/after") {
            Text(controller.dedupeStatus)
                .font(.caption.monospaced())
                .accessibilityIdentifier("dedupe_status")
        }
    }
}

// MARK: - Building blocks

/// Controls side by side, or one under another where the row is too narrow for them, as on a watch.
private struct ButtonRow<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { content() }
            VStack(alignment: .leading, spacing: 6) { content() }
        }
    }
}

/// A short, filled button. Filled buttons also keep a row's taps apart: in a form row, plain buttons side by side all
/// fire together.
private struct ActionButton: View {
    let title: String
    let tint: Color
    let id: String
    let action: () -> Void

    init(_ title: String, tint: Color = .accentColor, id: String, action: @escaping () -> Void) {
        self.title = title
        self.tint = tint
        self.id = id
        self.action = action
    }

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.borderedProminent)
            .tint(tint)
            .smallControl()
            .accessibilityIdentifier(id)
    }
}

private extension View {
    /// Keys are typed exactly: no capitalization or correction.
    func plainKeyEntry() -> some View {
        #if os(macOS)
        return autocorrectionDisabled()
        #else
        return autocorrectionDisabled().textInputAutocapitalization(.never)
        #endif
    }

    /// Selectable where the platform lets text be selected, so a path can be copied.
    func selectableWherePossible() -> some View {
        #if os(iOS) || os(macOS)
        return textSelection(.enabled)
        #else
        return self
        #endif
    }

    func segmentedWherePossible() -> some View {
        #if os(watchOS)
        return self
        #else
        return pickerStyle(.segmented)
        #endif
    }

    func smallControl() -> some View {
        #if os(tvOS)
        return self
        #else
        return controlSize(.small)
        #endif
    }

    func inlineTitle() -> some View {
        #if os(iOS) || os(watchOS)
        return navigationBarTitleDisplayMode(.inline)
        #else
        return self
        #endif
    }

    /// Rows only as tall as what is in them, and sections close together.
    @ViewBuilder
    func compactForm() -> some View {
        #if os(macOS)
        formStyle(.grouped)
        #elseif os(iOS)
        if #available(iOS 17.0, *) {
            environment(\.defaultMinListRowHeight, 0).listSectionSpacing(.compact)
        } else {
            environment(\.defaultMinListRowHeight, 0)
        }
        #else
        self
        #endif
    }
}
