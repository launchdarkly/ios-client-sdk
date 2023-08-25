import Foundation

protocol ContextModifier {
    func modifyContext(_ context: LDContext) -> LDContext
}

class AutoEnvContextModifier {
    static let specVersion = "1.0"
    private let environmentReporter: EnvironmentReporting

    init(environmentReporter: EnvironmentReporting) {
        self.environmentReporter = environmentReporter
    }

    private func makeRecipeList() -> [ContextRecipe] {
        return [
            applicationRecipe(),
            deviceRecipe()
        ]
    }

    private func makeContextFromRecipe(_ recipe: ContextRecipe) -> Result<LDContext, ContextBuilderError> {
        var builder = LDContextBuilder()
        builder.kind(recipe.kind)
        builder.key(recipe.keyCallable())

        recipe.attributeCallables.forEach { (key, callable) in
            let succeess = builder.trySetValue(key, callable())
            if !succeess {
                Log.debug(self.typeName(and: #function) + " Failed setting value for key \(key)")
            }
        }

        return builder.build()
    }

    //
    // Begin recipe definition for ld_application kind
    //
    static let ldApplicationKind = "ld_application"
    static let attrId = "id"
    static let attrName = "name"
    static let attrVersion = "version"
    static let attrVersionName = "versionName"
    static let envAttributesVersion = "envAttributesVersion"

    private func applicationRecipe() -> ContextRecipe {
        let keyCallable: () -> (String) = {
            Util.sha256base64(
                (self.environmentReporter.applicationInfo.applicationId ?? "") + ":" +
                (self.environmentReporter.applicationInfo.applicationVersion ?? "")
            )
        }

        var callables: [String : () -> LDValue] = [:]
        callables[AutoEnvContextModifier.envAttributesVersion] = { () -> LDValue in AutoEnvContextModifier.specVersion.toLDValue() }
        callables[AutoEnvContextModifier.attrId] = { () -> LDValue in self.environmentReporter.applicationInfo.applicationId?.toLDValue() ?? LDValue.null }
        callables[AutoEnvContextModifier.attrName] = { () -> LDValue in self.environmentReporter.applicationInfo.applicationName?.toLDValue() ?? LDValue.null }
        callables[AutoEnvContextModifier.attrVersion] = { () -> LDValue in self.environmentReporter.applicationInfo.applicationVersion?.toLDValue() ?? LDValue.null }
        callables[AutoEnvContextModifier.attrVersionName] = { () -> LDValue in self.environmentReporter.applicationInfo.applicationVersionName?.toLDValue() ?? LDValue.null }
        callables[AutoEnvContextModifier.attrLocale] = { () -> LDValue in self.environmentReporter.locale.toLDValue() }

        return ContextRecipe(
            kind: AutoEnvContextModifier.ldApplicationKind,
            keyCallable: keyCallable,
            attributeCallables: callables
        )
    }

    //
    // Begin recipe definition for ld_device kind
    //
    static var ldDeviceKind = "ld_device"
    static var attrManufacturer = "manufacturer"
    static var attrModel = "model"
    static var attrLocale = "locale"
    static var attrOs = "os"
    static var attrFamily = "family"

    private func deviceRecipe() -> ContextRecipe {
        let keyCallable: () -> (String) = {
            LDContext.defaultKey(kind: Kind(AutoEnvContextModifier.ldDeviceKind)!)
        }

        var callables: [String : () -> LDValue] = [:]
        callables[AutoEnvContextModifier.envAttributesVersion] = { () -> LDValue in AutoEnvContextModifier.specVersion.toLDValue() }
        callables[AutoEnvContextModifier.attrManufacturer] = { () -> LDValue in self.environmentReporter.manufacturer.toLDValue() }
        callables[AutoEnvContextModifier.attrModel] = { () -> LDValue in self.environmentReporter.deviceModel.toLDValue() }
        callables[AutoEnvContextModifier.attrOs] = {() -> LDValue in LDValue(dictionaryLiteral:
            (AutoEnvContextModifier.attrFamily, self.environmentReporter.osFamily.toLDValue()),
            (AutoEnvContextModifier.attrName, SystemCapabilities.systemName.toLDValue()),
            (AutoEnvContextModifier.attrVersion, self.environmentReporter.systemVersion.toLDValue())
        )}

        return ContextRecipe(
            kind: AutoEnvContextModifier.ldDeviceKind,
            keyCallable: keyCallable,
            attributeCallables: callables
        )
    }
}

extension AutoEnvContextModifier: TypeIdentifying { }

extension AutoEnvContextModifier: ContextModifier {
    func modifyContext(_ context: LDContext) -> LDContext {
        var builder = LDMultiContextBuilder()
        builder.addContext(context)

        let contextKeys = context.contextKeys()
        for recipe in makeRecipeList() {
            if contextKeys[recipe.kind.description] != nil {
                Log.debug(self.typeName(and: #function) + " Unable to automatically add environment attributes for kind \(recipe.kind). It already exists.")
                continue
            }

            switch makeContextFromRecipe(recipe) {
            case .success(let ctx):
                builder.addContext(ctx)
            case .failure(let err):
                Log.debug(self.typeName(and: #function) + " Failed adding context of kind \(recipe.kind) with error \(err)")
            }
        }

        switch builder.build() {
        case .success(let newContext):
            return newContext
        case .failure(let err):
                Log.debug(self.typeName(and: #function) + " Failed adding telemetry context information with error \(err). Using customer context instead.")
            return context
        }
    }
}

// A ContextRecipe is a set of callables that will be executed for a given kind
// to generate the associated `LDContext`.  The reason this class exists is to not make
// platform API calls until the context kind is needed.
final class ContextRecipe {
    fileprivate let kind: String
    fileprivate let keyCallable: () -> String
    fileprivate let attributeCallables: [String: () -> LDValue]

    init(kind: String, keyCallable: @escaping () -> String, attributeCallables: [String : () -> LDValue]) {
        self.kind = kind
        self.keyCallable = keyCallable
        self.attributeCallables = attributeCallables
    }
}
