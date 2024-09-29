import XCTest
@testable import AutokbiswCore

class IOKeyEventMonitorTests: XCTestCase {
    
    var monitor: IOKeyEventMonitor!
    
    override func setUp() {
        super.setUp()
        // Initialize the monitor before each test
        monitor = IOKeyEventMonitor(usagePage: 0x01, usage: 6, useLocation: true, verbosity: 0)
    }
    
    override func tearDown() {
        // Clean up after each test
        monitor.clearAllSettings()
        monitor = nil
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
}
