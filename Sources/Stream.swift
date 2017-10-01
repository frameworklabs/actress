import Foundation

public extension Observable {
    
    /// Creates another `Observable` by mapping the value of the `Observer` to the generic type `T`.
    func map<T>(_ f: @escaping (Value) -> T) -> Signal<T> {
        
        let processor = Signal<T>(name: "MapProcessor", disposeOnLastDisconnect: true)
        
        connect(ClosureSlot(actor: processor) { value in
            processor.emit(f(value))
        }, queue: processor.actorQueue, cont: processor.disposeBag.add)
        
        return processor
    }
}
