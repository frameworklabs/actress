@testable import actress
import XCTest

class SignalTests: XCTestCase {

    func testDispose() {
        let expectation = self.expectation(description: #function)
        
        let db = DisposeBag()
        
        let s = Signal<Void>(name: "s")
        
        var detectCount = 0
        
        s.connect(ClosureSlot(queue: .main) {
            XCTAssertEqual(detectCount, 0)
            
            detectCount += 1
            
            db.dispose()
            
            s.emit(())
            
            DispatchQueue.main.async {
                expectation.fulfill()
            }
        }, queue: .main, cont: db.add)
        
        s.emit(())
        
        waitForExpectations(timeout: 7)
    }
    
    func testEmit() {
        let expectation = self.expectation(description: #function)

        let sender = Sender(name: "sender")
        let receiver = Receiver(name: "receiver", sender: sender, expectation: expectation)
        _ = receiver
        
        sender.start()
        
        waitForExpectations(timeout: 7)
    }
}

class Sender: Actor {
    
    let signal = Signal<Int>(name: "signal")
    
    func start() {
        onewayActorMethod(#function) { cont in
            
            self.signal.emit(42)
            
            cont(())
        }
    }
}

class Receiver: Actor {
    
    let expectation: XCTestExpectation
    
    init(name: String, sender: Sender, expectation: XCTestExpectation) {
        self.expectation = expectation
        expectation.expectedFulfillmentCount = 2
        
        super.init(name: name)
        sender.signal.connect(MethodSlot(actor: self, method: Receiver.didReceive), queue: actorQueue, cont: self.disposeBag.add)
        sender.signal.connect(ClosureSlot(actor: self) { value in

            XCTAssertEqual(value, 42)

            print("2. value: \(value)")
            
            expectation.fulfill()
            
        }, queue: actorQueue, cont: self.disposeBag.add)
    }
    
    func didReceive(value: Int) {
        onewayActorMethod(#function) { cont in
            
            XCTAssertEqual(value, 42)
            
            print("1. value: \(value)")
            
            self.expectation.fulfill()
        }
    }
}
