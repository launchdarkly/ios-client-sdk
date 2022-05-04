import Foundation

struct FlagsUnchangedObserver {
    private(set) weak var owner: LDObserverOwner?
    let flagsUnchangedHandler: LDFlagsUnchangedHandler

    init(owner: LDObserverOwner, flagsUnchangedHandler: @escaping LDFlagsUnchangedHandler) {
        self.owner = owner
        self.flagsUnchangedHandler = flagsUnchangedHandler
    }
}
