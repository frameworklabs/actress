import Foundation

/// An active object which receives messages and works on them on it's own queue
/// in a sequential way.
///
/// Actor methods are asynchronous - they do their work on the queue of the Actor and
/// return back to the calling queue once finished. Currently, we use Continuation Passing Style (CPS)
/// and the explicit passing of the callers queue. In the future async/await should be used instead.
///
/// The data sent between `Actors` should be of value type to prevent concurrency issues.
///
/// Actors might support behaviours. Once a special behaviour is set, the Actor will only
/// handle actor messages conforming to that behaviour while all other messages will be ignored.
open class Actor {

    // MARK: Private Properties

    private typealias Activity = () -> Void

    private var activities: [(String, Activity)] = []
    private var currentActivity: Activity?
    private var behaviourStack: [Behaviour] = []

    // MARK: Subclass accessible Properties

    /// The serial `DispatchQueue` of this actor instance.
    public let actorQueue: DispatchQueue

    // MARK: Construction

    /// Constructs an Actor with a name used for the serial Dispatch queue.
    public init(name: String) {
        actorQueue = DispatchQueue(label: name, attributes: [])
    }

    // MARK: Sending and receiving messages

    /// Wrapper for bodies of actor methods which start an activity.
    ///
    /// While one `actorMethod` is active, other activities will be
    /// blocked from running to ensure strict serial execution of activities.
    ///
    /// - Note: See Test for usage
    /// - Note: In the future with async/await, the compiler should insert some equivalent code instead.
    public func actorMethod<T>(_ method: StaticString, queue: DispatchQueue, cont: @escaping Continuation<T>, messageHandler: @escaping (@escaping Continuation<T>) -> Void) {
        actorQueue.async {
            self.startActivity(method: method) {
                messageHandler { t in
                    queue.async {
                        cont(t)
                    }
                    self.finishActivity()
                }
            }
        }
    }
    
    /// Wrapper for bodies of actor methods which start an activity but don't return values.
    ///
    /// While one `actorMethod` is active, other activities will be
    /// blocked from running to ensure strict serial execution of activities.
    ///
    /// - Note: See Test for usage
    /// - Note: In the future with async/await, the compiler should insert some equivalent code instead.
    public func onewayActorMethod(_ method: StaticString, messageHandler: @escaping (@escaping Continuation<Void>) -> Void) {
        actorQueue.async {
            self.startActivity(method: method) {
                messageHandler {
                    self.finishActivity()
                }
            }
        }
    }

    /// Wrapper for bodies of actor methods which should not start an activity.
    ///
    /// To prevent deadlocks, some actor methods should be able to run outside of the activities stream - but still
    /// on the queue of the actor.
    public func interleavedActorMethod<T>(queue: DispatchQueue, cont: @escaping Continuation<T>, messageHandler: @escaping (@escaping Continuation<T>) -> Void) {
        actorQueue.async {
            messageHandler { t in
                queue.async {
                    cont(t)
                }
            }
        }
    }

    // MARK: Setting Behaviour

    /// Activate the given `behaviour` - this will clear the behaviour stack first.
    public func become(_ behaviour: Behaviour?) {
        behaviourStack.removeAll()
        if let behaviour = behaviour {
            push(behaviour)
        }
    }

    /// Pushes and activates `behaviour`.
    public func push(_ behaviour: Behaviour) {
        behaviourStack.append(behaviour)
    }

    /// Pops the most recently pushed behaviour.
    public func popBehaviour() {
        behaviourStack.removeLast()
    }

    // MARK: Helpers

    private func startActivity(method: StaticString, activity: @escaping Activity) {
        activities.append((String(describing: method), activity))

        runNextActivityIfAvailable()
    }

    private func finishActivity() {
        currentActivity = nil

        runNextActivityIfAvailable()
    }

    private func runNextActivityIfAvailable() {
        guard currentActivity == nil else {
            return
        }
        guard activities.count > 0 else {
            return
        }

        currentActivity = selectActivity()

        currentActivity?()
    }

    private func selectActivity() -> Activity? {
        for i in 0..<activities.count {

            let (method, activity) = activities[i]

            if let currentBehaviour = behaviourStack.last {
                guard currentBehaviour.methods.contains(method) else {
                    continue
                }
            }

            activities.remove(at: i)
            return activity
        }
        return nil
    }
}

// MARK: - Behaviour

/// A set of APIs supported by an Actor.
public protocol Behaviour {
    var methods: Set<String> { get }
}

/// Simple concrete implementation of `Behaviour` protocol.
public struct StandardBehaviour<T>: Behaviour {

    public let methods: Set<String>

    /// Constructs the `Behaviour` by extracting the methods from the generic type T.
    public init() {
        // TODO: Should fill `methods` by reflecting over T
        self.methods = []
    }

    /// Constructs a `Behaviour` by providing the method signatures explicity.
    public init(_ methods: String...) {
        self.methods = Set(methods)
    }
}

// MARK: - Helpers

public typealias Continuation<T> = (T) -> Void
