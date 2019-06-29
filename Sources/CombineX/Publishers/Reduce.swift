extension Publisher {
    
    /// Applies a closure that accumulates each element of a stream and publishes a final result upon completion.
    ///
    /// - Parameters:
    ///   - initialResult: The value the closure receives the first time it is called.
    ///   - nextPartialResult: A closure that takes the previously-accumulated value and the next element from the upstream publisher to produce a new value.
    /// - Returns: A publisher that applies the closure to all received elements and produces an accumulated value when the upstream publisher finishes.
    public func reduce<T>(_ initialResult: T, _ nextPartialResult: @escaping (T, Self.Output) -> T) -> Publishers.Reduce<Self, T> {
        return .init(upstream: self, initial: initialResult, nextPartialResult: nextPartialResult)
    }
}

extension Publishers {
    
    /// A publisher that applies a closure to all received elements and produces an accumulated value when the upstream publisher finishes.
    public struct Reduce<Upstream, Output> : Publisher where Upstream : Publisher {
        
        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Upstream.Failure
        
        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream
        
        /// The initial value provided on the first invocation of the closure.
        public let initial: Output
        
        /// A closure that takes the previously-accumulated value and the next element from the upstream publisher to produce a new value.
        public let nextPartialResult: (Output, Upstream.Output) -> Output
        
        /// This function is called to attach the specified `Subscriber` to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<S>(subscriber: S) where Output == S.Input, S : Subscriber, Upstream.Failure == S.Failure {
            let subscription = Inner(pub: self, sub: subscriber)
            self.upstream.subscribe(subscription)
        }
    }
}

extension Publishers.Reduce {
    
    private final class Inner<S>:
        Subscription,
        Subscriber,
        CustomStringConvertible,
        CustomDebugStringConvertible
    where
        S: Subscriber,
        S.Input == Output,
        S.Failure == Failure
    {
        
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure
        
        typealias Pub = Publishers.Reduce<Upstream, Output>
        typealias Sub = S
        
        let state = Atomic<RelayState>(value: .waiting)
        
        var pub: Pub?
        var sub: Sub?
        
        let output: Atomic<Output>
        
        init(pub: Pub, sub: Sub) {
            self.pub = pub
            self.sub = sub
            
            self.output = Atomic(value: pub.initial)
        }
        
        func request(_ demand: Subscribers.Demand) {
            precondition(demand > 0)
            self.state.subscription?.request(.unlimited)
        }
        
        func cancel() {
            self.state.finishIfRelaying()?.cancel()
            
            self.pub = nil
            self.sub = nil
        }
        
        func receive(subscription: Subscription) {
            if self.state.compareAndStore(expected: .waiting, newVaue: .relaying(subscription)) {
                self.sub?.receive(subscription: self)
            } else {
                subscription.cancel()
            }
        }
        
        func receive(_ input: Input) -> Subscribers.Demand {
            guard self.state.isRelaying else {
                return .none
            }
            
            guard let pub = self.pub else {
                return .none
            }
            
            self.output.withLockMutating {
                $0 = pub.nextPartialResult($0, input)
            }
            
            return .none
        }
        
        func receive(completion: Subscribers.Completion<Failure>) {
            guard let subscription = self.state.finishIfRelaying() else {
                return
            }
            
            subscription.cancel()
            
            switch completion {
            case .failure(let e):
                self.sub?.receive(completion: .failure(e))
            case .finished:
                _ = self.sub?.receive(self.output.load())
                self.sub?.receive(completion: .finished)
            }

            self.pub = nil
            self.sub = nil
        }
        
        var description: String {
            return "Reduce"
        }
        
        var debugDescription: String {
            return "Reduce"
        }
    }
}
