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

import TSCBasic
import Foundation
import TSCUtility

let DEBUG = 1
let TRACE = 2

let arguments = Array(ProcessInfo.processInfo.arguments.dropFirst())
let parser = ArgumentParser(usage: "<options>", overview: "Automatic keyboard/input source switching for macOS")

let locationUsage = """
Use locationId to identify keyboards (defaults to false.)
Note that the locationId changes when you plug a keyboard in a different port. Therefore using the locationId in the keyboards identifiers means the configured language will be associated to a keyboard on a specific port.

"""
let locationOption = parser.add(option: "--location", shortName: "-l", kind: Bool.self, usage: locationUsage, completion: .none)
let verboseOption = parser.add(option: "--verbose", shortName: "-v", kind: Int.self, usage: "Print verbose output (1 = DEBUG, 2 = TRACE)", completion: .none)

do {
    let parsedArguments = try parser.parse(arguments)
    let useLocation = parsedArguments.get(locationOption) ?? false
    let verbosity = parsedArguments.get(verboseOption) ?? 0

    if verbosity > 0 {
        print("Starting with useLocation: \(useLocation) - verbosity: \(verbosity)");
    }
    let monitor = IOKeyEventMonitor(usagePage: 0x01, usage: 6, useLocation: useLocation, verbosity: verbosity)
    monitor?.start()
    CFRunLoopRun()
} catch let e as ArgumentParserError {
    print(e.description)
} catch let e {
    print(e.localizedDescription)
}
