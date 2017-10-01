import Foundation

public protocol Disposable {
    func dispose()
}

public class DisposeBag {
    
    private var disposables: [Disposable] = []
    
    public func add(_ disposable: Disposable) {
        disposables.append(disposable)
    }
    
    public func dispose() {
        let disposablesCopy = disposables
        disposables.removeAll()
        
        for disposable in disposablesCopy {
            disposable.dispose()
        }
    }
    
    deinit {
        while !disposables.isEmpty {
            dispose()
        }
    }
}
