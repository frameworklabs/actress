@testable import Actress
import XCTest

class ActorTests: XCTestCase {

    func testEcho() {
        let expectation = self.expectation(description: #function)

        let e = EchoActor(name: "e")

        e.echo("shutup", queue: DispatchQueue.main) { str in

            XCTAssertTrue(isOnQueue(DispatchQueue.main))
            XCTAssertEqual(str, "shutup")

            var count = 0

            e.echo("hi", queue: DispatchQueue.main) { str in
                count += 1

                XCTAssertEqual(count, 2)
                XCTAssertEqual(str, "hi")

                expectation.fulfill()
            }
            e.speakUp(queue: DispatchQueue.main) { str in
                count += 1

                XCTAssertTrue(isOnQueue(DispatchQueue.main))
                XCTAssertEqual(count, 1)
                XCTAssertEqual(str, "yo")
            }
        }
        waitForExpectations(timeout: 700, handler: nil)
    }
}

protocol EchoBehaviour {
    func echo(_ text: String, queue: DispatchQueue, cont: @escaping (String) -> Void)
}

protocol QuietBehaviour {
    func speakUp(queue: DispatchQueue, cont: @escaping (String) -> Void)
}

class EchoActor: Actor, EchoBehaviour {

    let echoBehaviour = StandardBehaviour<EchoBehaviour>("echo(_:queue:cont:)")
    let quietBehaviour = StandardBehaviour<QuietBehaviour>("speakUp(queue:cont:)")

    override init(name: String) {
        super.init(name: name)
    }

    func echo(_ text: String, queue: DispatchQueue, cont: @escaping (String) -> Void) {
        actorMethod(#function, queue: queue, cont: cont) { cont in

            XCTAssertTrue(isOnQueue(self.actorQueue))

            if text == "shutup" {
                self.push(self.quietBehaviour)
            }

            cont(text)
        }
    }

    func speakUp(queue: DispatchQueue, cont: @escaping (String) -> Void) {
        actorMethod(#function, queue: queue, cont: cont) { cont in

            XCTAssertTrue(isOnQueue(self.actorQueue))

            self.popBehaviour()

            cont("yo")
        }
    }
}

func isOnQueue(_ expectedQueue: DispatchQueue) -> Bool {

    func currentQueueLabel() -> String? {
        let name = __dispatch_queue_get_label(nil)
        return String(cString: name, encoding: .utf8)
    }

    let currentLabel = currentQueueLabel()
    let expectedLabel = expectedQueue.label
    return currentLabel == expectedLabel
}
