import Foundation
import Quick
import Nimble

#if USE_COMBINE
import Combine
#else
import CombineX
#endif

class ReceiveOnSpec: QuickSpec {
    
    override func spec() {
        
        afterEach {
            TestResources.release()
        }
        
        // MARK: - Relay
        describe("Relay") {
            
            // MARK: 1.1 should receive events on the specified queue
            it("should receive events on the specified queue") {
                let subject = PassthroughSubject<Int, Never>()
                let scheduler = TestDispatchQueueScheduler.serial()
                let pub = subject.receive(on: scheduler)
                
                var received = (
                    subscription: false,
                    value: false,
                    completion: false
                )
                
                let sub = TestSubscriber<Int, Never>(receiveSubscription: { (s) in
                    s.request(.max(100))
                    received.subscription = true
                    expect(scheduler.isCurrent).to(beTrue())
                }, receiveValue: { v in
                    received.value = true
                    expect(scheduler.isCurrent).to(beTrue())
                    return .none
                }, receiveCompletion: { c in
                    received.completion = true
                    expect(scheduler.isCurrent).to(beTrue())
                })
                
                pub.subscribe(sub)
                
                1000.times {
                    subject.send($0)
                }
                subject.send(completion: .finished)

                expect(
                    [
                        received.subscription,
                        received.value,
                        received.completion
                    ]
                ).toEventually(equal([true, true, true]))
            }
            
            // MARK: 1.2 should send values as many as demand
            it("should send values as many as demand") {
                let subject = PassthroughSubject<Int, Never>()
                let scheduler = TestDispatchQueueScheduler.serial()
                let pub = subject.receive(on: scheduler)
                
                let count = Atom(val: 2)
                
                let sub = TestSubscriber<Int, Never>(receiveSubscription: { (s) in
                    s.request(.max(10))
                }, receiveValue: { v in
                    count.sub(1) > 0 ? .max(1) : .none
                }, receiveCompletion: { c in
                })
                
                pub.subscribe(sub)
                
                expect(sub.subscription).toEventuallyNot(beNil())
                
                100.times {
                    subject.send($0)
                }
                
                expect(sub.events.count).toEventually(equal(12))
            }
        }
    }
}
