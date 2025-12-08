import Foundation

extension LDClient {
    private struct IdentifyHookState {
        let seriesContext: IdentifySeriesContext
        let seriesData: [IdentifySeriesData]
        let hooksSnapshot: [Hook]
    }
    
    private func executeWithIdentifyHooks(context: LDContext, work: @escaping ((@escaping (IdentifyResult) -> Void)) -> Void) {
        let state = executeBeforeIdentifyHooks(context: context)
        work() { [weak self] result in
            guard let state else {
                return
            }
            self?.executeAfterIdentifyHooks(state: state, result: result)
        }
    }
    
    private func executeBeforeIdentifyHooks(context: LDContext) -> IdentifyHookState? {
        guard !hooks.isEmpty else {
            return nil
        }
        
        let hooksSnapshot = self.hooks
        let seriesContext = IdentifySeriesContext(context: context, methodName: "identify")
        let seriesData = hooksSnapshot.map { hook in
            hook.beforeIdentify(seriesContext: seriesContext, seriesData: EvaluationSeriesData())
        }
        return IdentifyHookState(seriesContext: seriesContext, seriesData: seriesData, hooksSnapshot: hooksSnapshot)
    }
    
    private func executeAfterIdentifyHooks(state: IdentifyHookState, result: IdentifyResult) {
        guard !state.hooksSnapshot.isEmpty else {
            return
        }
        
        // Invoke hooks in reverse order and give them back the series data they gave us.
        zip(state.hooksSnapshot, state.seriesData).reversed().forEach { (hook, data) in
            _ = hook.afterIdentify(seriesContext: state.seriesContext, seriesData: data, result: result)
        }
    }
    
    func _identifyHooked(context: LDContext, sheddable: Bool, useCache: IdentifyCacheUsage, timeout: TimeInterval, completion: @escaping (_ result: IdentifyResult) -> Void) {
        if timeout > 0 {
            executeWithIdentifyHooks(context: context) { hooksCompletion in
                TimeoutExecutor.run(
                    timeout: timeout,
                    queue: .global(),
                    operation: { [weak self] done in
                        self?._identify(context: context, sheddable: sheddable, useCache: useCache) { result in
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
            executeWithIdentifyHooks(context: context) { [weak self] hooksCompletion in
                self?._identify(context: context, sheddable: sheddable, useCache: useCache) { result in
                    completion(result)
                    hooksCompletion(result)
                }
            }
        }
    }
}
