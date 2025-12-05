import Foundation
import OSLog

extension LDClient {
    private struct IdentifyHookState {
        let seriesContext: IdentifySeriesContext
        let seriesData: [EvaluationSeriesData]
    }
    
    func executeWithIdentifyHooks(context: LDContext, work: @escaping ((@escaping () -> Void)) -> Void) {
        let state = executeBeforeIdentifyHooks(context: context)
        work() {
            guard let state else {
                return
            }
            self.executeAfterIdentifyHooks(context: context, state: state)
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
    
    private func executeAfterIdentifyHooks(context: LDContext, state: IdentifyHookState) {
        guard !self.hooks.isEmpty else {
            return
        }
        
        // Invoke hooks in reverse order and give them back the series data they gave us.
        zip(self.hooks, state.seriesData).reversed().forEach { (hook, data) in
            _ = hook.afterIdentify(seriesContext: state.seriesContext, seriesData: data, result: .complete)
        }
    }
}
