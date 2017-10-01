@testable import actress
import XCTest

class StreamTests: XCTestCase {

    func testMapAndDispose() {
        let expectation = self.expectation(description: #function)

        let db1 = DisposeBag()
        let db2 = DisposeBag()
        
        let s = Signal<Int>()
        
        var detectCount = 0

        s.map { $0 * 2 }.connect(ClosureSlot(queue: .main) { value in
            XCTAssertEqual(value, 42)
            
            XCTAssertEqual(detectCount, 0)
            detectCount += 1
            
            db1.dispose()
            
            s.emit(0)
            
        }, queue: .main, cont: db1.add)
        
        s.connect(ClosureSlot(queue: .main) { value in
            if value == 0 {
                expectation.fulfill()
            }
        }, queue: .main, cont: db2.add)
        
        s.emit(21)
        
        waitForExpectations(timeout: 7)
    }
}
