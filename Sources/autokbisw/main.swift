// Copyright 2016 Jean Helou
// Copyright 2024 Ole Hüter
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import ArgumentParser
import AutokbiswCore
import Foundation

struct Autokbisw: ParsableCommand {
    private static let defaultUsagePage: Int = 0x01
    private static let defaultUsage: Int = 6

    private static func createMonitor(useLocation: Bool = false, verbosity: Int = 0) -> IOKeyEventMonitor? {
        IOKeyEventMonitor(
            usagePage: defaultUsagePage,
            usage: defaultUsage,
            useLocation: useLocation,
            verbosity: verbosity
        )
    }

    static var configuration = CommandConfiguration(
        abstract: "Automatic keyboard/input source switching for macOS.",
        subcommands: [Enable.self, Disable.self, List.self, Clear.self]
    )

    @Option(
        name: .shortAndLong,
        help: ArgumentHelp(
            "Print verbose output (1 = DEBUG, 2 = TRACE).",
            valueName: "verbosity"
        )
    )
    var verbose = 0

    @Flag(
        name: .shortAndLong,
        help: ArgumentHelp(
            "Use locationId to identify keyboards.",
            discussion: "Note that the locationId changes when you plug a keyboard in a different port. Therefore using the locationId in the keyboards identifiers means the configured language will be associated to a keyboard on a specific port."
        )
    )
    var location = false

    mutating func run() throws {
        if verbose > 0 {
            print("Starting with useLocation: \(location) - verbosity: \(verbose)")
        }
        let monitor = Autokbisw.createMonitor(useLocation: location, verbosity: verbose)
        monitor?.start()
        CFRunLoopRun()
    }

    struct Enable: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "enable",
            abstract: "Enable input source switching for <device number or identifier>."
        )

        @Argument(help: "The device identifier or number (from list command) to enable")
        var keyboard: String

        func run() throws {
            let monitor = Autokbisw.createMonitor()
            if let number = Int(keyboard) {
                monitor?.enableDeviceByNumber(number)
            } else {
                monitor?.enableDevice(keyboard)
            }
        }
    }

    struct Disable: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "disable",
            abstract: "Disable input source switching for <device number or identifier>."
        )

        @Argument(help: "The device identifier or number (from list command) to disable")
        var keyboard: String

        func run() throws {
            let monitor = Autokbisw.createMonitor()
            if let number = Int(keyboard) {
                monitor?.disableDeviceByNumber(number)
            } else {
                monitor?.disableDevice(keyboard)
            }
        }
    }

    struct List: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all known devices and their current status."
        )

        func run() throws {
            let monitor = Autokbisw.createMonitor()
            print(monitor?.getDevicesString() ?? "")
        }
    }

    struct Clear: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "clear",
            abstract: "Clear all stored mappings and device settings."
        )

        func run() throws {
            let monitor = Autokbisw.createMonitor()
            monitor?.clearAllSettings()
            print("All stored settings have been cleared.")
        }
    }
}

Autokbisw.main()
