import Foundation

// MARK: - ExponentialBackoff

/// Calculates retry delays using the **Full Jitter** exponential backoff strategy.
///
/// Jitter prevents the thundering-herd problem where many clients retry at the
/// same time after a server failure. This implementation is based on the
/// AWS architecture blog recommendation:
/// `sleep = random_between(0, min(cap, base * 2^attempt))`
///
/// Usage:
/// ```swift
/// // Retry up to 5 times with standard backoff
/// let result = try await ExponentialBackoff.standard.retry(maxAttempts: 5) {
///     try await uploadDrawing()
/// }
/// ```
public struct ExponentialBackoff: Sendable {

    // MARK: - Configuration

    /// Minimum delay before the first retry
    public let baseDelay: Duration
    /// Hard cap on any single delay
    public let maxDelay: Duration
    /// Growth factor applied at each attempt
    public let multiplier: Double

    // MARK: - Presets

    /// General-purpose backoff: 1s base, 60s cap, ×2 per attempt.
    public static let standard = ExponentialBackoff(
        baseDelay: .seconds(1),
        maxDelay: .seconds(60),
        multiplier: 2.0
    )

    /// Sync-optimized backoff: 500ms base, 30s cap, ×1.5 per attempt.
    /// Used for drawing upload retries to feel more responsive.
    public static let sync = ExponentialBackoff(
        baseDelay: .milliseconds(500),
        maxDelay: .seconds(30),
        multiplier: 1.5
    )

    /// Realtime reconnect: 2s base, 120s cap, ×2 per attempt.
    /// Used for WebSocket reconnect loops to avoid hammering the server.
    public static let realtime = ExponentialBackoff(
        baseDelay: .seconds(2),
        maxDelay: .seconds(120),
        multiplier: 2.0
    )

    // MARK: - Initialization

    public init(baseDelay: Duration, maxDelay: Duration, multiplier: Double = 2.0) {
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.multiplier = multiplier
    }

    // MARK: - Delay Calculation

    /// Calculate the jittered delay for a given attempt number (0-indexed).
    ///
    /// - Parameter attempt: Zero-indexed attempt number (0 = first retry)
    /// - Returns: A duration in the range `[0, min(maxDelay, baseDelay * multiplier^attempt)]`
    public func delay(for attempt: Int) -> Duration {
        let base     = baseDelay.seconds * pow(multiplier, Double(attempt))
        let capped   = min(base, maxDelay.seconds)
        let jittered = Double.random(in: 0...capped)
        return .seconds(jittered)
    }

    // MARK: - Retry Helper

    /// Execute an async throwing operation, retrying with backoff on failure.
    ///
    /// - Parameters:
    ///   - maxAttempts: Total attempts allowed (including the first one)
    ///   - shouldRetry: Predicate to inspect an error and decide whether to retry.
    ///                  Defaults to retrying on any error.
    ///   - operation: The async operation to attempt
    /// - Returns: The successful result
    /// - Throws: The last error if all attempts fail, or any error that `shouldRetry` rejects
    public func retry<T: Sendable>(
        maxAttempts: Int = 5,
        shouldRetry: @Sendable (Error) -> Bool = { _ in true },
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for attempt in 0..<maxAttempts {
            do {
                return try await operation()
            } catch {
                guard shouldRetry(error) else { throw error }
                lastError = error
                if attempt < maxAttempts - 1 {
                    let wait = delay(for: attempt)
                    LWLogger.network.warning(
                        "Attempt \(attempt + 1)/\(maxAttempts) failed: \(error.localizedDescription). " +
                        "Retrying in \(String(format: "%.1f", wait.seconds))s"
                    )
                    try await Task.sleep(for: wait)
                }
            }
        }
        throw lastError ?? CancellationError()
    }
}

// MARK: - Duration Extension

extension Duration {
    /// Convert Duration to a Double value in seconds
    public var seconds: Double {
        let (secs, attoseconds) = components
        return Double(secs) + Double(attoseconds) / 1_000_000_000_000_000_000.0
    }
}
