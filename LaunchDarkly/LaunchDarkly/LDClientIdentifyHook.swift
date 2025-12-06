import Foundation
import OSLog

extension LDClient {
    private struct IdentifyHookState {
        let seriesContext: IdentifySeriesContext
        let seriesData: [EvaluationSeriesData]
    }
    
    func executeWithIdentifyHooks(context: LDContext, work: @escaping ((@escaping (IdentifyResult) -> Void)) -> Void) {
        let state = executeBeforeIdentifyHooks(context: context)
        work() { result in
            guard let state else {
                return
            }
            self.executeAfterIdentifyHooks(context: context, state: state, result: result)
        }
    }
    
    private func executeBeforeIdentifyHooks(context: LDContext) -> IdentifyHookState? {
        guard !self.hooks.isEmpty else {
            return nil
        }
        
        let seriesContext = IdentifySeriesContext(context: context, methodName: "identify")
        let seriesData = self.hooks.map { hook in
            hook.beforeIdentify(seriesContext: seriesContext, seriesData: EvaluationSeriesData())
        }
        return IdentifyHookState(seriesContext: seriesContext, seriesData: seriesData)
    }
    
    private func executeAfterIdentifyHooks(context: LDContext, state: IdentifyHookState, result: IdentifyResult) {
        guard !self.hooks.isEmpty else {
            return
        }
        
        // Invoke hooks in reverse order and give them back the series data they gave us.
        zip(self.hooks, state.seriesData).reversed().forEach { (hook, data) in
            _ = hook.afterIdentify(seriesContext: state.seriesContext, seriesData: data, result: result)
        }
    }
    
    func _identifyHooked(context: LDContext, sheddable: Bool, useCache: IdentifyCacheUsage, timeout: TimeInterval, completion: @escaping (_ result: IdentifyResult) -> Void) {
        if timeout > 0 {
            self.executeWithIdentifyHooks(context: context) { hooksCompletion in
                TimeoutExecutor.run(
                    timeout: timeout,
                    queue: .global(),
                    operation: { done in
                        self._identify(context: context, sheddable: sheddable, useCache: useCache) { result in
                            done(result)
                        }
                    },
                    timeoutValue: .timeout,
                    completion: { result in
                        completion(result)
                        hooksCompletion(result)
                    }
                )
            }
        } else {
            self.executeWithIdentifyHooks(context: context) { hooksCompletion in
                self._identify(context: context, sheddable: sheddable, useCache: useCache) { result in
                    completion(result)
                    hooksCompletion(result)
                }
            }
        }
    }
}
