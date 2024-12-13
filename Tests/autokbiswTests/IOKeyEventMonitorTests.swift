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

@testable import AutokbiswCore
import XCTest

class IOKeyEventMonitorTests: XCTestCase {
    var monitor: IOKeyEventMonitor!
    var mockUserDefaults: UserDefaults!

    override func setUp() {
        super.setUp()

        mockUserDefaults = UserDefaults(suiteName: #file) // Create an in-memory UserDefaults
        mockUserDefaults.removePersistentDomain(forName: #file) // Ensure it's empty

        // Initialize the monitor before each test
        monitor = IOKeyEventMonitor(usagePage: 0x01, usage: 6, useLocation: true, verbosity: 0, userDefaults: mockUserDefaults)
    }

    override func tearDown() {
        // Clean up after each test
        mockUserDefaults.removePersistentDomain(forName: #file)
        monitor = nil
        mockUserDefaults = nil
        super.tearDown()
    }

    func testInitialization() {
        XCTAssertNotNil(monitor, "IOKeyEventMonitor should be successfully initialized")
    }

    func testStoreAndRestoreInputSource() {
        let testKeyboard = "TestKeyboard-[1-2-TestManufacturer-123-456]"

        // Store a mock input source
        monitor.storeInputSource(keyboard: testKeyboard)

        // Verify that the input source was stored
        XCTAssertNotNil(monitor.kb2is[testKeyboard], "Input source should be stored for the test keyboard")

        // Attempt to restore the input source
        monitor.restoreInputSource(keyboard: testKeyboard)

        // We can't easily verify if TISSelectInputSource was called correctly,
        // but we can check that no error was thrown
    }

    func testOnKeyboardEvent() {
        let testKeyboard1 = "TestKeyboard1-[1-2-TestManufacturer-123-456]"
        let testKeyboard2 = "TestKeyboard2-[3-4-TestManufacturer-789-012]"

        monitor.onKeyboardEvent(keyboard: testKeyboard1)
        XCTAssertEqual(monitor.lastActiveKeyboard, testKeyboard1, "Last active keyboard should be updated")

        monitor.onKeyboardEvent(keyboard: testKeyboard2)
        XCTAssertEqual(monitor.lastActiveKeyboard, testKeyboard2, "Last active keyboard should be updated to the new keyboard")
    }

    func testEnableDevice() {
        let testKeyboard = "TestKeyboard-[1-2-TestManufacturer-123-456]"
        monitor.enableDevice(testKeyboard)
        XCTAssertTrue(monitor.deviceEnabled[testKeyboard] ?? false, "Device should be enabled")
    }

    func testDisableDevice() {
        let testKeyboard = "TestKeyboard-[1-2-TestManufacturer-123-456]"
        monitor.disableDevice(testKeyboard)
        XCTAssertFalse(monitor.deviceEnabled[testKeyboard] ?? true, "Device should be disabled")
    }

    func testClearAllSettings() {
        let testKeyboard = "TestKeyboard-[1-2-TestManufacturer-123-456]"
        monitor.storeInputSource(keyboard: testKeyboard)
        monitor.enableDevice(testKeyboard)

        monitor.clearAllSettings()

        XCTAssertTrue(monitor.kb2is.isEmpty, "kb2is should be empty after clearing settings")
        XCTAssertTrue(monitor.deviceEnabled.isEmpty, "deviceEnabled should be empty after clearing settings")
        XCTAssertNil(monitor.lastActiveKeyboard, "lastActiveKeyboard should be nil after clearing settings")
    }

    func testStoreInputSourceWithConformsToKeyboard() {
        let testKeyboard = "TestKeyboard-[1-2-TestManufacturer-123-456]"

        // Test storing with conformsToKeyboard = true
        monitor.storeInputSource(keyboard: testKeyboard, conformsToKeyboard: true)
        XCTAssertTrue(monitor.deviceEnabled[testKeyboard] ?? false, "Device should be enabled when conformsToKeyboard is true")

        // Clear settings
        monitor.clearAllSettings()

        // Test storing with conformsToKeyboard = false
        monitor.storeInputSource(keyboard: testKeyboard, conformsToKeyboard: false)
        XCTAssertFalse(monitor.deviceEnabled[testKeyboard] ?? true, "Device should be disabled when conformsToKeyboard is false")

        // Test storing without conformsToKeyboard
        monitor.clearAllSettings()
        monitor.storeInputSource(keyboard: testKeyboard)
        XCTAssertNil(monitor.deviceEnabled[testKeyboard], "Device enabled status should not be set when conformsToKeyboard is not provided")
    }

    func testOnKeyboardEventWithConformsToKeyboard() {
        let testKeyboard = "TestKeyboard-[1-2-TestManufacturer-123-456]"

        // Test with conformsToKeyboard = true
        monitor.onKeyboardEvent(keyboard: testKeyboard, conformsToKeyboard: true)
        XCTAssertTrue(monitor.deviceEnabled[testKeyboard] ?? false, "Device should be enabled when conformsToKeyboard is true")
        XCTAssertEqual(monitor.lastActiveKeyboard, testKeyboard, "Last active keyboard should be updated")

        // Clear settings
        monitor.clearAllSettings()

        // Test with conformsToKeyboard = false
        monitor.onKeyboardEvent(keyboard: testKeyboard, conformsToKeyboard: false)
        XCTAssertFalse(monitor.deviceEnabled[testKeyboard] ?? true, "Device should be disabled when conformsToKeyboard is false")
        XCTAssertEqual(monitor.lastActiveKeyboard, testKeyboard, "Last active keyboard should be updated even for disabled device")
    }

    func testPrintDevices() {
        let testKeyboard1 = "TestKeyboard1-[1-2-TestManufacturer-123-456]"
        let testKeyboard2 = "TestKeyboard2-[3-4-TestManufacturer-789-012]"

        monitor.enableDevice(testKeyboard1)
        monitor.disableDevice(testKeyboard2)

        let output = monitor.getDevicesString()

        XCTAssertTrue(output.contains("\(testKeyboard1): enabled"), "Output should show TestKeyboard1 as enabled")
        XCTAssertTrue(output.contains("\(testKeyboard2): disabled"), "Output should show TestKeyboard2 as disabled")
    }

    func testEnableDeviceByNumber() {
        let testKeyboard1 = "ATestKeyboard1-[1-2-TestManufacturer-123-456]"
        let testKeyboard2 = "BTestKeyboard2-[3-4-TestManufacturer-789-012]"

        // Setup initial state
        monitor.enableDevice(testKeyboard1)
        monitor.enableDevice(testKeyboard2)
        monitor.disableDevice(testKeyboard2) // Should be: keyboard1 enabled, keyboard2 disabled

        // Enable device #2 (testKeyboard2)
        monitor.enableDeviceByNumber(2)

        XCTAssertTrue(monitor.deviceEnabled[testKeyboard2] ?? false, "Device #2 should be enabled")
        XCTAssertTrue(monitor.deviceEnabled[testKeyboard1] ?? false, "Device #1 should remain enabled")
    }

    func testDisableDeviceByNumber() {
        let testKeyboard1 = "ATestKeyboard1-[1-2-TestManufacturer-123-456]"
        let testKeyboard2 = "BTestKeyboard2-[3-4-TestManufacturer-789-012]"

        // Setup initial state
        monitor.enableDevice(testKeyboard1)
        monitor.enableDevice(testKeyboard2)

        // Disable device #1 (testKeyboard1)
        monitor.disableDeviceByNumber(1)

        XCTAssertFalse(monitor.deviceEnabled[testKeyboard1] ?? true, "Device #1 should be disabled")
        XCTAssertTrue(monitor.deviceEnabled[testKeyboard2] ?? false, "Device #2 should remain enabled")
    }

    func testDeviceNumbering() {
        let testKeyboard1 = "XTestKeyboard1-[1-2-TestManufacturer-123-456]"
        let testKeyboard2 = "BTestKeyboard2-[3-4-TestManufacturer-789-012]"

        monitor.enableDevice(testKeyboard1)
        monitor.enableDevice(testKeyboard2)

        let output = monitor.getDevicesString()
        let lines = output.split(separator: "\n")

        XCTAssertTrue(lines[0].starts(with: "1. BTestKeyboard2"), "Second device should be numbered 1")
        XCTAssertTrue(lines[1].starts(with: "2. XTestKeyboard1"), "First device should be numbered 2")
    }

    func testInvalidDeviceNumber() {
        let testKeyboard = "TestKeyboard-[1-2-TestManufacturer-123-456]"
        monitor.enableDevice(testKeyboard)

        // Test invalid numbers
        monitor.enableDeviceByNumber(0) // Too low
        monitor.enableDeviceByNumber(2) // Too high
        monitor.disableDeviceByNumber(0) // Too low
        monitor.disableDeviceByNumber(2) // Too high

        // State should remain unchanged
        XCTAssertTrue(monitor.deviceEnabled[testKeyboard] ?? false, "Device state should not change with invalid number")
    }
}
