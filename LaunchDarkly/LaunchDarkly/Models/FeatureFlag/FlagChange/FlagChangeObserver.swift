import Foundation

struct FlagChangeObserver {
    private(set) weak var owner: LDObserverOwner?
    let flagKeys: [LDFlagKey]
    let flagChangeHandler: LDFlagChangeHandler?
    let flagCollectionChangeHandler: LDFlagCollectionChangeHandler?

    init(key: LDFlagKey, owner: LDObserverOwner, flagChangeHandler: @escaping LDFlagChangeHandler) {
        self.flagKeys = [key]
        self.owner = owner
        self.flagChangeHandler = flagChangeHandler
        self.flagCollectionChangeHandler = nil
    }

    init(keys: [LDFlagKey], owner: LDObserverOwner, flagCollectionChangeHandler: @escaping LDFlagCollectionChangeHandler) {
        self.flagKeys = keys
        self.owner = owner
        self.flagChangeHandler = nil
        self.flagCollectionChangeHandler = flagCollectionChangeHandler
    }
}
