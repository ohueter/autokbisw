import Foundation

public let DEBUG = 1
public let TRACE = 2

public struct Logger {
    let verbosity: Int

    func trace(_ message: String) {
        if verbosity >= TRACE {
            print(message)
        }
    }

    func debug(_ message: String) {
        if verbosity >= DEBUG {
            print(message)
        }
    }
}
