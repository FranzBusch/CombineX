import Foundation

private protocol Locking: NSLocking {
    func `try`() -> Bool
}

extension NSRecursiveLock: Locking {}
extension NSLock: Locking {}

final class Lock {
    
    private let locking: Locking
    
    init(recursive: Bool = false) {
        self.locking = recursive ? NSRecursiveLock() : NSLock()
    }
    
    func lock() {
        self.locking.lock()
    }

    func `try`() -> Bool {
        return self.locking.try()
    }
    
    func unlock() {
        self.locking.unlock()
    }
    
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        self.lock(); defer { self.unlock() }
        return try body()
    }
    
    func withLockGet<T>(_ body: @autoclosure () throws -> T) rethrows -> T {
        self.lock(); defer { self.unlock() }
        return try body()
    }
}
