import Foundation

// MARK: - Observer and Observable

/// An object which emits values which can be observed by `Observers`.
public protocol Observable {
    
    associatedtype Value
    
    /// Connects `observer` to `self`.
    ///
    /// Note: Disconnect by disposing the returned `Disposable`.
    func connect<O: Observer>(_ observer: O, queue: DispatchQueue, cont: @escaping Continuation<Disposable>) where O.Value == Value
    
    /// Sends `value` to all `Observers`.
    func emit(_ value: Value)
}

/// An object which can detect values emitted by `Observables`.
public protocol Observer {
    
    associatedtype Value
    
    /// Invoked when the connected `Observer` emits a value.
    func detect(_ value: Value)
}

// MARK: - Signal and Slots

/// An implementation of the `Observable` protocol via an Actor to ensure thread safety.
public class Signal<T>: Actor, Observable {
    
    // MARK: Properties
    
    private let disposeOnLastDisconnect: Bool

    private var observerAdapters: [ObserverAdapter<T>] = []
    
    // MARK: Construction
    
    public init(name: String = "Signal", disposeOnLastDisconnect: Bool = false) {
        self.disposeOnLastDisconnect = disposeOnLastDisconnect
        super.init(name: name)
    }
    
    // MARK: Observable API
    
    public func connect<O>(_ observer: O, queue: DispatchQueue, cont: @escaping (Disposable) -> Void) where O : Observer, T == O.Value {
        actorMethod(#function, queue: queue, cont: cont) { cont in
            
            let observerAdapter: ObserverAdapter<T> = GenericObserverAdapter(observer: observer)
            observerAdapter.delegate = self
            
            self.observerAdapters.append(observerAdapter)
            
            cont(observerAdapter)
        }
    }
    
    public func emit(_ value: T) {
        onewayActorMethod(#function) { cont in
            
            for observerAdapter in self.observerAdapters {
                observerAdapter.detect(value)
            }
            
            cont(())
        }
    }
}

extension Signal: ObserverAdapterDelegate {
    
    func dispose(adapter: AnyObject) {
        onewayActorMethod(#function) { cont in
            
            for i in 0..<self.observerAdapters.count {
                
                if self.observerAdapters[i] === adapter {
                    self.observerAdapters.remove(at: i)
                    
                    if self.observerAdapters.isEmpty && self.disposeOnLastDisconnect {
                        self.disposeBag.dispose()
                    }
                    
                    break
                }
            }
            
            cont(())
        }
    }
}

/// An implementation of `Observer` which calls an actor-method of the observing actor.
public struct MethodSlot<A: Actor, T>: Observer {
    
    public typealias Method = (A) -> (T) -> Void
    
    private unowned let actor: A
    private let method: Method
    
    public init(actor: A, method: @escaping Method) {
        self.actor = actor
        self.method = method
    }
    
    public func detect(_ value: T) {
        method(actor)(value)
    }
}

/// An implementation of `Observer` which calls a closure on the queue of an actor (or some other queue).
public struct ClosureSlot<T>: Observer {
    
    public typealias Closure = (T) -> Void
    
    private let queue: DispatchQueue
    private let closure: Closure

    public init(queue: DispatchQueue, closure: @escaping Closure) {
        self.queue = queue
        self.closure = closure
    }

    public init(actor: Actor, closure: @escaping Closure) {
        self.init(queue: actor.actorQueue, closure: closure)
    }
    
    public func detect(_ value: T) {
        queue.async {
            self.closure(value)
        }
    }
}

// MARK: - Internals

private protocol ObserverAdapterDelegate: class {
    func dispose(adapter: AnyObject)
}

private class ObserverAdapter<T>: Observer, Disposable {
    
    weak var delegate: ObserverAdapterDelegate?
    
    func detect(_ value: T) {}
    
    func dispose() {
        delegate?.dispose(adapter: self)
    }
}

private class GenericObserverAdapter<O: Observer>: ObserverAdapter<O.Value> {
    
    let observer: O
    
    init(observer: O) {
        self.observer = observer
    }
    
    override func detect(_ value: O.Value) {
        observer.detect(value)
    }
}
