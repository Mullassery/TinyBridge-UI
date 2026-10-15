import Foundation

/// A fixed-capacity ring buffer. Used to bound metric history so a long-running
/// app cannot grow memory without limit (a hard performance requirement).
public struct RingBuffer<Element>: Sendable where Element: Sendable {
    private var storage: [Element?]
    private var head = 0
    private var count = 0

    public let capacity: Int

    public init(capacity: Int) {
        precondition(capacity > 0, "RingBuffer capacity must be positive")
        self.capacity = capacity
        self.storage = Array(repeating: nil, count: capacity)
    }

    public var isEmpty: Bool { count == 0 }
    public var isFull: Bool { count == capacity }

    /// Number of elements currently stored.
    public var length: Int { count }

    public mutating func append(_ element: Element) {
        storage[head] = element
        head = (head + 1) % capacity
        if count < capacity { count += 1 }
    }

    /// Elements in insertion order (oldest first).
    public var elements: [Element] {
        guard count > 0 else { return [] }
        var result: [Element] = []
        result.reserveCapacity(count)
        let start = count == capacity ? head : 0
        for offset in 0..<count {
            let index = (start + offset) % capacity
            if let value = storage[index] {
                result.append(value)
            }
        }
        return result
    }

    public var lastElement: Element? {
        elements.last
    }

    public mutating func removeAll() {
        storage = Array(repeating: nil, count: capacity)
        head = 0
        count = 0
    }
}
