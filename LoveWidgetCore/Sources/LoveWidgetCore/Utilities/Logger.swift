import Foundation
import os.log

// MARK: - LWLogger

/// Structured logging for LoveWidget using the `os.Logger` subsystem.
///
/// Uses `privacy: .public` on user-facing data. All internal state stays private
/// to avoid leaking sensitive info into the system log.
///
/// Usage:
/// ```swift
/// LWLogger.sync.info("Starting realtime listener for pair \(pairID)")
/// LWLogger.storage.error("Failed to write drawing: \(error)")
/// ```
public struct LWLogger: Sendable {

    private let logger: Logger

    /// Create a logger for the given category (appears in Console.app)
    public init(category: String) {
        self.logger = Logger(subsystem: "com.lovewidget.app", category: category)
    }

    // MARK: - Log Methods

    public func debug(_ message: @autoclosure @escaping () -> String) {
        logger.debug("\(message(), privacy: .public)")
    }

    public func info(_ message: @autoclosure @escaping () -> String) {
        logger.info("\(message(), privacy: .public)")
    }

    public func warning(_ message: @autoclosure @escaping () -> String) {
        logger.warning("\(message(), privacy: .public)")
    }

    public func error(_ message: @autoclosure @escaping () -> String) {
        logger.error("\(message(), privacy: .public)")
    }

    public func fault(_ message: @autoclosure @escaping () -> String) {
        logger.fault("\(message(), privacy: .public)")
    }

    // MARK: - Named Loggers (one per component)

    public static let sync     = LWLogger(category: "SyncEngine")
    public static let storage  = LWLogger(category: "Storage")
    public static let network  = LWLogger(category: "Networking")
    public static let canvas   = LWLogger(category: "Canvas")
    public static let pairing  = LWLogger(category: "Pairing")
    public static let widget   = LWLogger(category: "Widget")
    public static let menuBar  = LWLogger(category: "MenuBar")
    public static let app      = LWLogger(category: "App")
}
