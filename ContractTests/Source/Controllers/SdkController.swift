import Vapor
import LaunchDarkly

final class SdkController: RouteCollection {
    private var clients: [Int: LDClient] = [:]
    private var clientCounter = 0

    func boot(routes: RoutesBuilder) {
        routes.get("", use: status)
        routes.post("", use: createClient)
        routes.delete("", use: shutdown)

        let clientRoutes = routes.grouped("clients")
        clientRoutes.post(":id", use: executeCommand)
        clientRoutes.delete(":id", use: shutdownClient)
    }

    func status(_ req: Request) -> StatusResponse {
        let capabilities = [
            "client-side",
            "mobile",
            "service-endpoints",
            "strongly-typed",
            "tags",
            "auto-env-attributes",
            "context-comparison",
            "etag-caching",
            "inline-context",
            "anonymous-redaction"
        ]

        return StatusResponse(
            name: "ios-swift-client-sdk",
            capabilities: capabilities)
    }

    func createClient(_ req: Request) throws -> Response {
        let createInstance = try req.content.decode(CreateInstance.self)
        let mobileKey = createInstance.configuration.credential
        let autoEnvAttributes: AutoEnvAttributes = createInstance.configuration.clientSide.includeEnvironmentAttributes == true ? .enabled : .disabled
        var config = LDConfig(mobileKey: mobileKey, autoEnvAttributes: autoEnvAttributes)
        config.enableBackgroundUpdates = true
        config.isDebugMode = true

        if let streaming = createInstance.configuration.streaming {
            if let baseUri = streaming.baseUri {
                config.streamUrl = URL(string: baseUri)!
            }

            // TODO(mmk) Need to hook up initialRetryDelayMs
        } else if let polling = createInstance.configuration.polling {
            config.streamingMode = .polling
            if let baseUri = polling.baseUri {
                config.baseUrl = URL(string: baseUri)!
            }
        }

        if let events = createInstance.configuration.events {
            if let baseUri = events.baseUri {
                config.eventsUrl = URL(string: baseUri)!
            }

            if let capacity = events.capacity {
                config.eventCapacity = capacity
            }

            if let enable = events.enableDiagnostics {
                config.diagnosticOptOut = !enable
            }

            if let allPrivate = events.allAttributesPrivate {
                config.allContextAttributesPrivate = allPrivate
            }

            if let globalPrivate = events.globalPrivateAttributes {
                config.privateContextAttributes = globalPrivate.map { Reference($0) }
            }

            if let flushIntervalMs = events.flushIntervalMs {
                config.eventFlushInterval =  flushIntervalMs
            }
        }

        if let tags = createInstance.configuration.tags {
            var applicationInfo = ApplicationInfo()
            if let id = tags.applicationId {
                applicationInfo.applicationIdentifier(id)
            }

            if let name = tags.applicationName {
                applicationInfo.applicationName(name)
            }

            if let version = tags.applicationVersion {
                applicationInfo.applicationVersion(version)
            }

            if let versionName = tags.applicationVersionName {
                applicationInfo.applicationVersionName(versionName)
            }

            config.applicationInfo = applicationInfo
        }

        let clientSide = createInstance.configuration.clientSide

        if let evaluationReasons = clientSide.evaluationReasons {
            config.evaluationReasons = evaluationReasons
        }

        if let useReport = clientSide.useReport {
            config.useReport = useReport
        }

        let dispatchSemaphore = DispatchSemaphore(value: 0)
        let startWaitSeconds = (createInstance.configuration.startWaitTimeMs ?? 5_000) / 1_000

        LDClient.start(config: config, context: clientSide.initialContext, startWaitSeconds: startWaitSeconds) { _ in
            dispatchSemaphore.signal()
        }

        dispatchSemaphore.wait()

        let client = LDClient.get()!

        self.clientCounter += 1
        self.clients.updateValue(client, forKey: self.clientCounter)

        var headers = HTTPHeaders()
        headers.add(name: "Location", value: "/clients/\(self.clientCounter)")

        let response = Response()
        response.status = .ok
        response.headers = headers

        return response
    }

    func shutdownClient(_ req: Request) throws -> HTTPStatus {
        guard let id = req.parameters.get("id", as: Int.self)
        else { throw Abort(.badRequest) }

        guard let client = self.clients[id]
        else { return HTTPStatus.badRequest }

        client.close()
        clients.removeValue(forKey: id)

        return HTTPStatus.accepted
    }

    func executeCommand(_ req: Request) throws -> CommandResponse {
        guard let id = req.parameters.get("id", as: Int.self)
        else { throw Abort(.badRequest) }

        let commandParameters = try req.content.decode(CommandParameters.self)
        guard let client = self.clients[id] else {
            throw Abort(.badRequest)
        }

        switch commandParameters.command {
        case "evaluate":
            let result: EvaluateFlagResponse = try self.evaluate(client, commandParameters.evaluate!)
            return CommandResponse.evaluateFlag(result)
        case "evaluateAll":
            let result: EvaluateAllFlagsResponse = try self.evaluateAll(client, commandParameters.evaluateAll!)
            return CommandResponse.evaluateAll(result)
        case "identifyEvent":
            let semaphore = DispatchSemaphore(value: 0)
            client.identify(context: commandParameters.identifyEvent!.context) {
                semaphore.signal()
            }
            semaphore.wait()
        case "customEvent":
            let event = commandParameters.customEvent!
            client.track(key: event.eventKey, data: event.data, metricValue: event.metricValue)
        case "flushEvents":
            client.flush()
        case "contextBuild":
            let contextBuild = commandParameters.contextBuild!

            do {
                if let singleParams = contextBuild.single {
                    let context = try SdkController.buildSingleContextFromParams(singleParams)

                    let encoder = JSONEncoder()
                    let output = try encoder.encode(context)

                    let response = ContextBuildResponse(output: String(data: Data(output), encoding: .utf8))
                    return CommandResponse.contextBuild(response)
                }

                if let multiParams = contextBuild.multi {
                    var multiContextBuilder = LDMultiContextBuilder()
                    try multiParams.forEach {
                        multiContextBuilder.addContext(try SdkController.buildSingleContextFromParams($0))
                    }

                    let context = try multiContextBuilder.build().get()
                    let encoder = JSONEncoder()
                    let output = try encoder.encode(context)

                    let response = ContextBuildResponse(output: String(data: Data(output), encoding: .utf8))
                    return CommandResponse.contextBuild(response)
                }
            } catch {
                let response = ContextBuildResponse(output: nil, error: error.localizedDescription)
                return CommandResponse.contextBuild(response)
            }
        case "contextConvert":
            let convertRequest = commandParameters.contextConvert!
            do {
                let decoder = JSONDecoder()
                let context: LDContext = try decoder.decode(LDContext.self, from: Data(convertRequest.input.utf8))

                let encoder = JSONEncoder()
                let output = try encoder.encode(context)

                let response = ContextBuildResponse(output: String(data: Data(output), encoding: .utf8))
                return CommandResponse.contextBuild(response)
            } catch {
                let response = ContextBuildResponse(output: nil, error: error.localizedDescription)
                return CommandResponse.contextBuild(response)
            }
        case "contextComparison":
            let params = commandParameters.contextComparison!
            let context1 = try SdkController.buildContextForComparison(params.context1)
            let context2 = try SdkController.buildContextForComparison(params.context2)

            let response = ContextComparisonResponse(equals: context1 == context2)
            return CommandResponse.contextComparison(response)
        default:
            throw Abort(.badRequest)
        }

        return CommandResponse.ok
    }

    static func buildContextForComparison(_ params: ContextComparisonParameters) throws -> LDContext {
        if let single = params.single {
            return try buildSingleKindContextForComparison(single)
        } else if let multi = params.multi {
            var builder = LDMultiContextBuilder()
            for param in multi {
                builder.addContext(try buildSingleKindContextForComparison(param))
            }

            return try builder.build().get()
        }

        throw Abort(.badRequest)
    }

    static func buildSingleKindContextForComparison(_ params: ContextComparisonSingleParams) throws -> LDContext {
        var builder = LDContextBuilder(key: params.key)
        builder.kind(params.kind)

        if let attributes = params.attributes {
            for attribute in attributes {
                builder.trySetValue(attribute.name, attribute.value)
            }
        }

        if let attributes = params.privateAttributes {
            for attribute in attributes {
                if attribute.literal {
                    builder.addPrivateAttribute(Reference(literal: attribute.value))
                } else {
                    builder.addPrivateAttribute(Reference(attribute.value))
                }
            }
        }

        return try builder.build().get()
    }

    static func buildSingleContextFromParams(_ params: SingleContextParameters) throws -> LDContext {
        var contextBuilder = LDContextBuilder(key: params.key)

        if let kind = params.kind {
            contextBuilder.kind(kind)
        }

        if let name = params.name {
            contextBuilder.name(name)
        }

        if let anonymous = params.anonymous {
            contextBuilder.anonymous(anonymous)
        }

        if let privateAttributes = params.privateAttribute {
            privateAttributes.forEach { contextBuilder.addPrivateAttribute(Reference($0)) }
        }

        if let custom = params.custom {
            custom.forEach { contextBuilder.trySetValue($0.key, $0.value) }
        }

        return try contextBuilder.build().get()
    }

    func evaluate(_ client: LDClient, _ params: EvaluateFlagParameters) throws -> EvaluateFlagResponse {
        switch params.valueType {
        case "bool":
            if case let LDValue.bool(defaultValue) = params.defaultValue {
                if params.detail {
                    let result = client.boolVariationDetail(forKey: params.flagKey, defaultValue: defaultValue)
                    return EvaluateFlagResponse(value: LDValue.bool(result.value), variationIndex: result.variationIndex, reason: result.reason)
                }

                let result = client.boolVariation(forKey: params.flagKey, defaultValue: defaultValue)
                return EvaluateFlagResponse(value: LDValue.bool(result))
            }
            throw Abort(.badRequest, reason: "Failed to convert \(params.valueType) to bool")
        case "int":
            if case let LDValue.number(defaultValue) = params.defaultValue {
                if params.detail {
                    let result = client.intVariationDetail(forKey: params.flagKey, defaultValue: Int(defaultValue))
                    return EvaluateFlagResponse(value: LDValue.number(Double(result.value)), variationIndex: result.variationIndex, reason: result.reason)
                }

                let result = client.intVariation(forKey: params.flagKey, defaultValue: Int(defaultValue))
                return EvaluateFlagResponse(value: LDValue.number(Double(result)))
            }
            throw Abort(.badRequest, reason: "Failed to convert \(params.valueType) to int")
        case "double":
            if case let LDValue.number(defaultValue) = params.defaultValue {
                if params.detail {
                    let result = client.doubleVariationDetail(forKey: params.flagKey, defaultValue: defaultValue)
                    return EvaluateFlagResponse(value: LDValue.number(result.value), variationIndex: result.variationIndex, reason: result.reason)
                }

                let result = client.doubleVariation(forKey: params.flagKey, defaultValue: defaultValue)
                return EvaluateFlagResponse(value: LDValue.number(result), variationIndex: nil, reason: nil)
            }
            throw Abort(.badRequest, reason: "Failed to convert \(params.valueType) to bool")
        case "string":
            if case let LDValue.string(defaultValue) = params.defaultValue {
                if params.detail {
                    let result = client.stringVariationDetail(forKey: params.flagKey, defaultValue: defaultValue)
                    return EvaluateFlagResponse(value: LDValue.string(result.value), variationIndex: result.variationIndex, reason: result.reason)
                }

                let result = client.stringVariation(forKey: params.flagKey, defaultValue: defaultValue)
                return EvaluateFlagResponse(value: LDValue.string(result), variationIndex: nil, reason: nil)
            }
            throw Abort(.badRequest, reason: "Failed to convert \(params.valueType) to string")
        default:
            if params.detail {
                let result = client.jsonVariationDetail(forKey: params.flagKey, defaultValue: params.defaultValue)
                return EvaluateFlagResponse(value: result.value, variationIndex: result.variationIndex, reason: result.reason)
            }

            let result = client.jsonVariation(forKey: params.flagKey, defaultValue: params.defaultValue)
            return EvaluateFlagResponse(value: result, variationIndex: nil, reason: nil)
        }
    }

    func evaluateAll(_ client: LDClient, _ params: EvaluateAllFlagsParameters) throws -> EvaluateAllFlagsResponse {
        let result = client.allFlags

        return EvaluateAllFlagsResponse(state: result)
    }

    func shutdown(_ req: Request) -> HTTPStatus {
        exit(0)
        return HTTPStatus.accepted
    }
}
