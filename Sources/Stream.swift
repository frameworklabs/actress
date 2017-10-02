import Foundation

public extension Observable {
    
    /// Creates another `Observable` by mapping the value of the `Observer` to the generic type `T`.
    func map<T>(_ f: @escaping (Value) -> T, queue: DispatchQueue, cont: @escaping Continuation<Signal<T>>) {
        
        let processor = Signal<T>(name: "MapProcessor", disposeOnLastDisconnect: true)
        
        connect(ClosureSlot(actor: processor) { value in
            processor.emit(f(value))
            
        }, queue: processor.actorQueue) { connection in
            processor.disposeBag.add(connection)
            
            queue.async {
                cont(processor)
            }
        }
    }
}
