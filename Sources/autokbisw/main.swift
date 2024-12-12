// Copyright [2016] Jean Helou
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
import Foundation
import AutokbiswCore

struct Autokbisw: ParsableCommand {
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
        let monitor = IOKeyEventMonitor(usagePage: 0x01, usage: 6, useLocation: location, verbosity: verbose)
        monitor?.start()
        CFRunLoopRun()
    }

    struct Enable: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "enable",
            abstract: "Enable input source switching for <device identifier>."
        )

        @Argument(help: "The device identifier to enable")
        var keyboard: String

        func run() throws {
            let monitor = IOKeyEventMonitor(usagePage: 0x01, usage: 6, useLocation: false, verbosity: 0)
            monitor?.enableDevice(keyboard)
        }
    }

    struct Disable: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "disable",
            abstract: "Disable input source switching for <device identifier>."
        )

        @Argument(help: "The device identifier to disable")
        var keyboard: String

        func run() throws {
            let monitor = IOKeyEventMonitor(usagePage: 0x01, usage: 6, useLocation: false, verbosity: 0)
            monitor?.disableDevice(keyboard)
        }
    }

    struct List: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all known devices and their current status."
        )

        func run() throws {
            let monitor = IOKeyEventMonitor(usagePage: 0x01, usage: 6, useLocation: false, verbosity: 0)
            print(monitor?.getDevicesString() ?? "")
        }
    }

    struct Clear: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "clear",
            abstract: "Clear all stored mappings and device settings."
        )

        func run() throws {
            let monitor = IOKeyEventMonitor(usagePage: 0x01, usage: 6, useLocation: false, verbosity: 0)
            monitor?.clearAllSettings()
            print("All stored settings have been cleared.")
        }
    }
}

Autokbisw.main()
