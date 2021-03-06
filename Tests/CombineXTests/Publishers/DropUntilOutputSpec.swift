import Quick
import Nimble

#if USE_COMBINE
import Combine
#else
import CombineX
#endif

class DropUntilOutputSpec: QuickSpec {
    
    override func spec() {
        
        afterEach {
            TestResources.release()
        }
        
        // MARK: - Relay
        describe("Relay") {
            
            // MARK: 1.1 should drop until other sends a value
            it("should drop until other sends a value") {
                
                let pub0 = PassthroughSubject<Int, TestError>()
                let pub1 = PassthroughSubject<Int, TestError>()
                
                let pub = pub0.drop(untilOutputFrom: pub1)
                let sub = makeTestSubscriber(Int.self, TestError.self, .unlimited)
                pub.subscribe(sub)
                
                10.times {
                    pub0.send($0)
                }
                pub1.send(-1)
                
                for i in 10..<20 {
                    pub0.send(i)
                }
                 
                let expected = (10..<20).map { TestSubscriberEvent<Int, TestError>.value($0) }
                expect(sub.events).to(equal(expected))
            }
            
            // MARK: 1.2 should complete when other complete
            it("should complete when other complete") {
                
                let pub0 = PassthroughSubject<Int, TestError>()
                let pub1 = PassthroughSubject<Int, TestError>()
                
                let pub = pub0.drop(untilOutputFrom: pub1)
                let sub = makeTestSubscriber(Int.self, TestError.self, .unlimited)
                pub.subscribe(sub)
                
                10.times {
                    pub0.send($0)
                }
                pub1.send(completion: .finished)
                10.times {
                    pub0.send($0)
                }
                
                expect(sub.events).to(equal([.completion(.finished)]))
            }
            
            // MARK: 1.3 should complete if self complete
            it("should complete if self complete") {
                
                let pub0 = PassthroughSubject<Int, TestError>()
                let pub1 = PassthroughSubject<Int, TestError>()
                
                let pub = pub0.drop(untilOutputFrom: pub1)
                let sub = makeTestSubscriber(Int.self, TestError.self, .unlimited)
                pub.subscribe(sub)
                
                10.times {
                    pub0.send($0)
                }
                pub0.send(completion: .finished)
                
                expect(sub.events).to(equal([.completion(.finished)]))
            }
        }
    }
}
