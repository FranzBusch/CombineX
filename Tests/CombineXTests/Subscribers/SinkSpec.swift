import Quick
import Nimble

#if USE_COMBINE
import Combine
#else
import CombineX
#endif

class SinkSpec: QuickSpec {
    
    override func spec() {
        
        afterEach {
            TestResources.release()
        }
        
        // MARK: - Receive Values
        describe("Receive Values") {
            
            // MARK: 1.1 should receive values that upstream send
            it("should receive values that upstream send") {
                let pub = PassthroughSubject<Int, Never>()
                
                var values: [Int] = []
                var completions: [Subscribers.Completion<Never>] = []
                
                let sink = pub.sink(receiveCompletion: { (c) in
                    completions.append(c)
                }, receiveValue: { v in
                    values.append(v)
                })
                
                pub.send(1)
                pub.send(2)
                pub.send(3)
                pub.send(completion: .finished)
                
                expect(values).to(equal([1, 2, 3]))
                expect(completions).to(equal([.finished]))
                
                _ = sink
            }
            
            // MARK: 1.2 should receive values whether received subscription or not
            it("should receive values whether received subscription or not") {
                let pub = TestPublisher<Int, Never> { s in
                    _ = s.receive(1)
                    _ = s.receive(2)
                    s.receive(completion: .finished)
                }
                
                var events: [TestSubscriberEvent<Int, Never>] = []
                let sink = pub.sink(receiveCompletion: { (c) in
                    events.append(.completion(c))
                }, receiveValue: { v in
                    events.append(.value(v))
                })
                
                expect(events).to(equal([.value(1), .value(2), .completion(.finished)]))
                
                _ = sink
            }
            
            // MARK: 1.3 should receive values even if it has received completion
            it("should receive values even if it has received completion") {
                let pub = TestPublisher<Int, Never> { s in
                    _ = s.receive(1)
                    s.receive(completion: .finished)
                    _ = s.receive(2)
                }
                
                var events: [TestSubscriberEvent<Int, Never>] = []
                let sink = pub.sink(receiveCompletion: { (c) in
                    events.append(.completion(c))
                }, receiveValue: { v in
                    events.append(.value(v))
                })
                
                expect(events).to(equal([.value(1), .completion(.finished), .value(2)]))
                
                _ = sink
            }
        }
        
        // MARK: - Release Resources
        describe("Release Resources") {
            
            // MARK: 2.1 should retain subscription then release it after completion
            it("should retain subscription then release it after completion") {
                let sink = Subscribers.Sink<Int, Never>(receiveCompletion: { c in
                }, receiveValue: { v in
                })
                
                weak var subscription: TestSubscription?
                var cancelled = false
                
                do {
                    let s = TestSubscription(cancel: {
                        cancelled = true
                    })
                    sink.receive(subscription: s)
                    subscription = s
                }
                
                expect(subscription).toNot(beNil())
                expect(cancelled).to(beFalse())
                sink.receive(completion: .finished)
                expect(subscription).to(beNil())
                expect(cancelled).to(beFalse())
            }
            
            // MARK: 2.2 should retain subscription then release and cancel it after cancel
            it("should retain subscription then release and cancel it after cancel") {
                let sink = Subscribers.Sink<Int, Never>(receiveCompletion: { c in
                }, receiveValue: { v in
                })
                
                weak var subscription: TestSubscription?
                var cancelled = false
                
                do {
                    let s = TestSubscription(cancel: {
                        cancelled = true
                    })
                    sink.receive(subscription: s)
                    subscription = s
                }
                
                expect(subscription).toNot(beNil())
                expect(cancelled).to(beFalse())
                sink.cancel()
                expect(subscription).to(beNil())
                expect(cancelled).to(beTrue())
            }
            
            // MARK: 2.3 should not retain subscription if it is already subscribing
            it("should not retain subscription if it is already subscribing") {
                let sink = Subscribers.Sink<Int, Never>(receiveCompletion: { c in
                }, receiveValue: { v in
                })
                
                sink.receive(subscription: Subscriptions.empty)
                
                weak var subscription: TestSubscription?
                var cancelled = false
                
                do {
                    let s = TestSubscription(cancel: {
                        cancelled = true
                    })
                    sink.receive(subscription: s)
                    subscription = s
                }
                
                expect(subscription).to(beNil())
                expect(cancelled).to(beTrue())
            }
        }
    }
}
