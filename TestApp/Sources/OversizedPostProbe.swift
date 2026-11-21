import Foundation
import LaunchDarkly

/// Posts one analytics payload of `targetBytes` straight to the events service, with the headers the SDK's sender
/// uses, and reports what came back. Through a session of its own rather than the SDK, so neither the event store, the
/// batch size limit nor the retry state is involved: one request, one answer.
///
/// The events are valid custom events, so a service that takes the payload records them.
enum OversizedPostProbe {
    static let targetBytes = 20 * 1024 * 1024

    private static let path = "mobile/events/bulk"
    private static let eventDataChars = 900
    private static let responseBodyShown = 2_000

    #if os(macOS)
    private static let systemName = "macOS"
    #elseif os(tvOS)
    private static let systemName = "tvOS"
    #elseif os(watchOS)
    private static let systemName = "watchOS"
    #else
    private static let systemName = "iOS"
    #endif

    static func run(configuration: TestAppConfiguration) async -> String {
        var config = LDConfig(mobileKey: configuration.mobileKey, autoEnvAttributes: .disabled)
        configuration.applyEndpoints(to: &config)
        let url = config.eventsUrl.appendingPathComponent(path)
        let payloadId = UUID().uuidString
        let creationDate = Int64(Date().timeIntervalSince1970 * 1000)
        let event = Data(("{\"kind\":\"custom\",\"key\":\"oversized-post-probe\",\"creationDate\":\(creationDate),"
            + "\"context\":{\"kind\":\"user\",\"key\":\"oversized-post-probe\"},"
            + "\"data\":\"\(String(repeating: "x", count: eventDataChars))\"}").utf8)
        let eventCount = (targetBytes - 1) / (event.count + 1)
        let body = makeBody(event: event, count: eventCount)

        var report = "POST \(url.absoluteString)\n\(eventCount) events, \(body.count.formatted()) bytes\n"
            + "Payload ID \(payloadId)\n\n"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("api_key \(configuration.mobileKey)", forHTTPHeaderField: "Authorization")
        request.setValue("\(systemName)/oversized-post-probe", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("4", forHTTPHeaderField: "X-LaunchDarkly-Event-Schema")
        request.setValue(payloadId, forHTTPHeaderField: "X-LaunchDarkly-Payload-ID")

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        // Long enough for 20 MB to go up over a slow connection before the answer.
        sessionConfiguration.timeoutIntervalForRequest = 180
        let session = URLSession(configuration: sessionConfiguration)
        defer { session.finishTasksAndInvalidate() }

        let started = Date()
        do {
            let (data, response) = try await session.upload(for: request, from: body)
            report += String(format: "Answered after %.1f s\n\n", Date().timeIntervalSince(started))
            guard let http = response as? HTTPURLResponse
            else { return report + "Not an HTTP response: \(response)\n" }
            report += "HTTP \(http.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: http.statusCode))\n"
            for (name, value) in http.allHeaderFields.map({ ("\($0.key)", "\($0.value)") }).sorted(by: { $0.0 < $1.0 }) {
                report += "\(name): \(value)\n"
            }
            if !data.isEmpty {
                let text = String(decoding: data.prefix(responseBodyShown), as: UTF8.self)
                report += "\n\(text)\(data.count > responseBodyShown ? "…" : "")\n"
            }
        } catch {
            report += String(format: "No answer after %.1f s: %@\n", Date().timeIntervalSince(started),
                             String(describing: error))
        }
        return report
    }

    private static func makeBody(event: Data, count: Int) -> Data {
        var body = Data(capacity: 2 + count * event.count + max(0, count - 1))
        body.append(UInt8(ascii: "["))
        for index in 0..<count {
            if index > 0 {
                body.append(UInt8(ascii: ","))
            }
            body.append(event)
        }
        body.append(UInt8(ascii: "]"))
        return body
    }
}
