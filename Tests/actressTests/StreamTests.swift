@testable import actress
import XCTest

class StreamTests: XCTestCase {

    func testMapAndDispose() {
        let expectation = self.expectation(description: #function)

        let db1 = DisposeBag()
        let db2 = DisposeBag()
        
        let s = Signal<Int>()
        
        var detectCount = 0
        
        s.map({ $0 * 2 }, queue: .main) { processor in
            processor.connect(ClosureSlot(queue: .main) { value in
                XCTAssertEqual(value, 42)
                
                XCTAssertEqual(detectCount, 0)
                detectCount += 1
                
                db1.dispose()
                
                s.emit(0)
                
            }, queue: .main) { connection in
                db1.add(connection)
                
                s.emit(21)
            }
        }

        s.connect(ClosureSlot(queue: .main) { value in
            if value == 0 {
                expectation.fulfill()
            }
        }, queue: .main, cont: db2.add)

        waitForExpectations(timeout: 7)
    }
    
    func testMultiMap() {
        let expectation = self.expectation(description: #function)
        
        let db = DisposeBag()
        
        let s = Signal<Int>()

        s.map({ (val: Int) -> Int in val * 2 }, queue: .main) { proc in
            proc.map({ "\($0)" }, queue: .main) { proc in
                proc.connect(ClosureSlot(queue: .main) { value in
                    XCTAssertEqual(value, "42")
                    
                    expectation.fulfill()
                    
                }, queue: .main) { conn in
                    db.add(conn)
                    
                    s.emit(21)
                }
            }
        }
        
        waitForExpectations(timeout: 7)
    }
}
