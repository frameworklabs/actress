@testable import actress
import XCTest

class ActorTests: XCTestCase {

    func testEcho() {
        let expectation = self.expectation(description: #function)

        let e = EchoActor(name: "e")

        e.echo("shutup", queue: .main) { str in

            XCTAssertTrue(isOnQueue(.main))
            XCTAssertEqual(str, "shutup")

            var count = 0

            e.echo("hi", queue: .main) { str in
                count += 1

                XCTAssertEqual(count, 2)
                XCTAssertEqual(str, "hi")

                expectation.fulfill()
            }
            e.speakUp(queue: .main) { str in
                count += 1

                XCTAssertTrue(isOnQueue(.main))
                XCTAssertEqual(count, 1)
                XCTAssertEqual(str, "yo")
            }
        }
        waitForExpectations(timeout: 7, handler: nil)
    }
    
    func testOneway() {
        let expectation = self.expectation(description: #function)
        
        let a = Adder(name: "a")
        
        a.add(3)
        a.getSum(queue: .main) { value in
            XCTAssertEqual(value, 3)
            
            a.reset()
            a.getSum(queue: .main) { value in
                XCTAssertEqual(value, 0)
                
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 7, handler: nil)
    }
}

// MARK: - EchoActor

protocol EchoBehaviour {
    func echo(_ text: String, queue: DispatchQueue, cont: @escaping Continuation<String>)
}

protocol QuietBehaviour {
    func speakUp(queue: DispatchQueue, cont: @escaping Continuation<String>)
}

class EchoActor: Actor, EchoBehaviour, QuietBehaviour {

    // MARK: Properties

    let echoBehaviour = StandardBehaviour<EchoBehaviour>("echo(_:queue:cont:)")
    let quietBehaviour = StandardBehaviour<QuietBehaviour>("speakUp(queue:cont:)")

    // MARK: Actor methods

    func echo(_ text: String, queue: DispatchQueue, cont: @escaping Continuation<String>) {
        actorMethod(#function, queue: queue, cont: cont) { cont in

            XCTAssertTrue(isOnQueue(self.actorQueue))

            if text == "shutup" {
                self.push(self.quietBehaviour)
            }

            cont(text)
        }
    }

    func speakUp(queue: DispatchQueue, cont: @escaping Continuation<String>) {
        actorMethod(#function, queue: queue, cont: cont) { cont in

            XCTAssertTrue(isOnQueue(self.actorQueue))

            self.popBehaviour()

            cont("yo")
        }
    }
}

// MARK: - One Way

class Adder: Actor {
    
    // MARK: Properties

    private var value = 0
    
    // MARK: Actor methods

    func add(_ delta: Int) {
        onewayActorMethod(#function) { cont in
            self.value += delta
            cont(())
        }
    }
    
    func getSum(queue: DispatchQueue, cont: @escaping Continuation<Int>) {
        actorMethod(#function, queue: queue, cont: cont) { cont in
            cont(self.value)
        }
    }
    
    func reset() {
        onewayActorMethod(#function) { cont in
            self.value = 0
            cont(())
        }
    }
}

// MARK: - Helpers

func isOnQueue(_ expectedQueue: DispatchQueue) -> Bool {

    func currentQueueLabel() -> String? {
        let name = __dispatch_queue_get_label(nil)
        return String(cString: name, encoding: .utf8)
    }

    let currentLabel = currentQueueLabel()
    let expectedLabel = expectedQueue.label
    return currentLabel == expectedLabel
}
