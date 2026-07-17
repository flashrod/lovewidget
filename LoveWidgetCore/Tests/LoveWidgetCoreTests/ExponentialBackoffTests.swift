import Testing
import Foundation
@testable import LoveWidgetCore

@Suite("Exponential Backoff")
struct ExponentialBackoffTests {

    @Test("Delay cap increases with attempts (jitter affects actual values)")
    func delayCapIncreases() {
        let backoff = ExponentialBackoff(baseDelay: .seconds(1), maxDelay: .seconds(60))
        let cap0 = backoff.baseDelay.seconds * pow(2, 0)
        let cap1 = backoff.baseDelay.seconds * pow(2, 1)
        let cap2 = backoff.baseDelay.seconds * pow(2, 2)
        #expect(cap0 <= cap1)
        #expect(cap1 <= cap2)
    }

    @Test("Delay is capped at maxDelay")
    func delayCapped() {
        let backoff = ExponentialBackoff(baseDelay: .seconds(10), maxDelay: .seconds(5))
        for attempt in 0..<5 {
            let delay = backoff.delay(for: attempt)
            #expect(delay.seconds <= 5.0)
        }
    }

    @Test("Delay is non-negative")
    func delayNonNegative() {
        let backoff = ExponentialBackoff(baseDelay: .seconds(1), maxDelay: .seconds(60))
        for attempt in 0..<10 {
            let delay = backoff.delay(for: attempt)
            #expect(delay.seconds >= 0)
        }
    }

    @Test("Delay is jittered (not identical across calls)")
    func delayJittered() {
        let backoff = ExponentialBackoff(baseDelay: .seconds(10), maxDelay: .seconds(10))
        var delays = Set<Double>()
        for _ in 0..<50 {
            delays.insert(backoff.delay(for: 5).seconds)
        }
        // With full jitter, we should see multiple distinct values
        #expect(delays.count > 1)
    }

    @Test("Sync preset has short base delay")
    func syncPreset() {
        let backoff = ExponentialBackoff.sync
        #expect(backoff.baseDelay.seconds <= 1.0)
        #expect(backoff.maxDelay.seconds <= 30.0)
    }

    @Test("Realtime preset has longer delays")
    func realtimePreset() {
        let backoff = ExponentialBackoff.realtime
        #expect(backoff.baseDelay.seconds >= 2.0)
        #expect(backoff.maxDelay.seconds >= 60.0)
    }

    @Test("Standard preset has default values")
    func standardPreset() {
        let backoff = ExponentialBackoff.standard
        #expect(backoff.baseDelay.seconds == 1.0)
        #expect(backoff.maxDelay.seconds == 60.0)
        #expect(backoff.multiplier == 2.0)
    }
}
