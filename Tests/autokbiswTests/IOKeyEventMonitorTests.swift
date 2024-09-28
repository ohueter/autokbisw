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
    
    func testIgnoreMouseEvent() {
        let previousKeyboard = monitor.lastActiveKeyboard
        monitor.onKeyboardEvent(keyboard: "CONFORMS_TO_MOUSE")
        XCTAssertEqual(monitor.lastActiveKeyboard, previousKeyboard, "Last active keyboard should not change for mouse events")
    }
}
