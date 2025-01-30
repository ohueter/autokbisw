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

import AppKit
import Carbon
import Foundation
import IOKit
import IOKit.hid
import IOKit.usb
import IOKit.usb.IOUSBLib

public final class IOKeyEventMonitor {
    private let log: Logger

    private let hidManager: IOHIDManager
    fileprivate let notificationCenter: CFNotificationCenter

    fileprivate let MAPPINGS_DEFAULTS_KEY = "keyboardISMapping"
    fileprivate var defaults: UserDefaults = .standard

    fileprivate let MAPPING_ENABLED_KEY = "mappingEnabled"
    var deviceEnabled: [String: Bool] = [:]

    fileprivate let assignmentLock = NSLock()
    var lastActiveKeyboard: String?
    var kb2is: [String: TISInputSource] = .init()

    fileprivate var useLocation: Bool

    private var isMonitoring: Bool = false
    private var restartWorkItem: DispatchWorkItem?

    // TODO: add properties for page and usage
    public init? (usagePage: Int, usage: Int, useLocation: Bool, verbosity: Int, userDefaults: UserDefaults = .standard) {
        self.useLocation = useLocation
        log = Logger(verbosity: verbosity)
        defaults = userDefaults

        notificationCenter = CFNotificationCenterGetDistributedCenter()
        hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

        let deviceMatch: CFMutableDictionary = [kIOHIDDeviceUsageKey: usage, kIOHIDDeviceUsagePageKey: usagePage] as NSMutableDictionary
        IOHIDManagerSetDeviceMatching(hidManager, deviceMatch)

        loadMappings()
    }

    deinit {
        restartWorkItem?.cancel()
        restartWorkItem = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        stopMonitoring()
        stopObservingSettingsChanges()
        self.saveMappings()
    }

    public func start() {
        startMonitoring()
        startObservingSystemEvents()
    }

    private func observeIputSourceChangedNotification(context: UnsafeMutableRawPointer) {
        let inputSourceChanged: CFNotificationCallback = {
            _, observer, _, _, _ in
            let selfPtr = Unmanaged<IOKeyEventMonitor>.fromOpaque(observer!).takeUnretainedValue()
            selfPtr.onInputSourceChanged()
        }

        CFNotificationCenterAddObserver(notificationCenter,
                                        context, inputSourceChanged,
                                        kTISNotifySelectedKeyboardInputSourceChanged, nil,
                                        CFNotificationSuspensionBehavior.deliverImmediately)
    }

    private func registerHIDKeyboardCallback(context: UnsafeMutableRawPointer) {
        let myHIDKeyboardCallback: IOHIDValueCallback = {
            context, _, sender, _ in
            let selfPtr = Unmanaged<IOKeyEventMonitor>.fromOpaque(context!).takeUnretainedValue()
            let senderDevice = Unmanaged<IOHIDDevice>.fromOpaque(sender!).takeUnretainedValue()

            let conformsToKeyboard = selfPtr.deviceConformsToKeyboard(senderDevice)

            let vendorId = selfPtr.deviceProperty(senderDevice, kIOHIDVendorIDKey)
            let productId = selfPtr.deviceProperty(senderDevice, kIOHIDProductIDKey)
            let product = selfPtr.deviceProperty(senderDevice, kIOHIDProductKey)
            let manufacturer = selfPtr.deviceProperty(senderDevice, kIOHIDManufacturerKey)
            let serialNumber = selfPtr.deviceProperty(senderDevice, kIOHIDSerialNumberKey)
            let locationId = selfPtr.deviceProperty(senderDevice, kIOHIDLocationIDKey)
            let uniqueId = selfPtr.deviceProperty(senderDevice, kIOHIDUniqueIDKey)

            let keyboard = selfPtr.useLocation
                ? "\(product)-[\(vendorId)-\(productId)-\(manufacturer)-\(serialNumber)-\(locationId)]"
                : "\(product)-[\(vendorId)-\(productId)-\(manufacturer)-\(serialNumber)]"

            selfPtr.log.trace("received event from device \(keyboard) - \(locationId) - \(uniqueId) - conformsToKeyboard: \(conformsToKeyboard)")
            selfPtr.onKeyboardEvent(keyboard: keyboard, conformsToKeyboard: conformsToKeyboard)
        }

        IOHIDManagerRegisterInputValueCallback(hidManager, myHIDKeyboardCallback, context)
    }

    private func deviceProperty(_ device: IOHIDDevice, _ key: String) -> String {
        guard let value = IOHIDDeviceGetProperty(device, key as CFString) else {
            return "unknown"
        }
        return String(describing: value)
    }

    private func deviceConformsToKeyboard(_ device: IOHIDDevice) -> Bool {
        return IOHIDDeviceConformsTo(device, UInt32(kHIDPage_GenericDesktop), UInt32(kHIDUsage_GD_Keyboard))
    }
}

// MARK: - Monitoring Management

public extension IOKeyEventMonitor {
    private func startMonitoring() {
        guard !isMonitoring else {
            log.trace("startMonitoring() called although already monitoring")
            return
        }

        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        // Close and reopen HID manager to ensure clean state
        IOHIDManagerClose(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))

        let openResult = IOHIDManagerOpen(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
        if openResult == kIOReturnSuccess {
            log.debug("HID Manager opened successfully")
        } else {
            log.debug("Failed to open HID Manager: \(openResult)")
            // Back off 1 second and try again
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.startMonitoring()
            }
            return
        }

        // Reset device matching to re-enumerate all devices
        let deviceMatch: CFMutableDictionary = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard,
        ] as NSMutableDictionary
        IOHIDManagerSetDeviceMatching(hidManager, deviceMatch)

        observeIputSourceChangedNotification(context: context)

        if let devices = IOHIDManagerCopyDevices(hidManager) {
            let count = CFSetGetCount(devices)
            let deviceArray = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: count)
            CFSetGetValues(devices, deviceArray)

            log.debug("Currently connected HID devices: \(count)")

            for i in 0 ..< count {
                guard let devicePtr = deviceArray[i] else { continue }
                let device = Unmanaged<IOHIDDevice>.fromOpaque(devicePtr).takeUnretainedValue()
                if deviceConformsToKeyboard(device) {
                    let product = deviceProperty(device, kIOHIDProductKey)
                    log.debug("Found HID device: \(product)")
                }
            }

            deviceArray.deallocate()

            registerHIDKeyboardCallback(context: context)
            IOHIDManagerScheduleWithRunLoop(hidManager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode!.rawValue)
            startObservingSettingsChanges()
            isMonitoring = true
        } else {
            log.debug("Failed to enumerate devices, retrying...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.startMonitoring()
            }
        }
    }

    private func stopMonitoring() {
        guard isMonitoring else { return }

        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        // Unschedule and close properly
        IOHIDManagerUnscheduleFromRunLoop(hidManager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode!.rawValue)
        IOHIDManagerRegisterInputValueCallback(hidManager, nil, context)

        let closeResult = IOHIDManagerClose(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
        if closeResult == kIOReturnSuccess {
            log.debug("HID Manager closed successfully")
        } else {
            log.debug("Failed to close HID Manager: \(closeResult)")
        }

        stopObservingSettingsChanges()
        isMonitoring = false
    }

    private func restartMonitoring() {
        log.debug("Restarting monitoring...")
        stopMonitoring()
        // Add small delay to ensure USB system is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.startMonitoring()
        }
        log.debug("Monitoring restarted")
    }

    private func debouncedRestartMonitoring() {
        // Cancel any pending restart
        restartWorkItem?.cancel()

        // Create new work item
        let workItem = DispatchWorkItem { [weak self] in
            self?.restartMonitoring()
        }
        restartWorkItem = workItem

        // Schedule restart with delay to allow device initialization
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    private func startObservingSystemEvents() {
        log.debug("Starting system event observation")

        // Sleep/Wake notifications
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWakeNotification),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        // USB device changes
        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName) as NSMutableDictionary

        let port: IONotificationPortRef
        if #available(macOS 12.0, *) {
            port = IONotificationPortCreate(kIOMainPortDefault)
        } else {
            // Use kIOMasterPortDefault for older macOS versions
            port = IONotificationPortCreate(kIOMasterPortDefault)
        }

        IONotificationPortSetDispatchQueue(port, DispatchQueue.main)

        // Create context pointer
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        // Use a static callback function
        let callback: IOServiceMatchingCallback = { userData, iterator in
            guard let userData = userData else { return }
            let monitor = Unmanaged<IOKeyEventMonitor>.fromOpaque(userData).takeUnretainedValue()
            monitor.log.debug("USB device change detected")

            // Process all matched devices
            var device: io_service_t = IOIteratorNext(iterator)
            while device != 0 {
                var name: [Int8] = Array(repeating: 0, count: 128)
                IORegistryEntryGetName(device, &name)
                let deviceName = String(cString: name)
                monitor.log.debug("USB device event for: \(deviceName)")
                IOObjectRelease(device)
                device = IOIteratorNext(iterator)
            }

            monitor.debouncedRestartMonitoring()
        }

        // Register for different types of notifications
        let notifications = [
            kIOPublishNotification, // Device added
            kIOTerminatedNotification, // Device removed
            kIOMatchedNotification, // Device matched
        ]

        var iterators: [io_iterator_t] = Array(repeating: 0, count: notifications.count)

        for (index, notification) in notifications.enumerated() {
            // Create a new copy of the matching dictionary for each notification
            let matchCopy = matchingDict.mutableCopy() as! CFMutableDictionary

            let result = IOServiceAddMatchingNotification(
                port,
                notification,
                matchCopy,
                callback,
                context,
                &iterators[index]
            )

            if result == KERN_SUCCESS {
                log.debug("Successfully registered for USB notification type: \(notification)")
                // Clear initial iterator
                callback(context, iterators[index])
            } else {
                log.debug("Failed to register USB notification type: \(notification), error: \(result)")
            }
        }
    }

    @objc private func handleWakeNotification() {
        log.debug("System woke from sleep, restarting monitoring")

        // Wait a moment for USB devices to be fully initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.restartMonitoring()
        }
    }
}

// MARK: - Input Source Management

public extension IOKeyEventMonitor {
    func restoreInputSource(keyboard: String) {
        guard let targetIs = kb2is[keyboard] else {
            log.trace("No previous mapping saved for \(keyboard), awaiting the user to select the right one")
            return
        }

        log.debug("Setting input source for keyboard \(keyboard): \(targetIs)")

        // This will trigger onInputSourceChanged()
        TISSelectInputSource(targetIs)
    }

    func storeInputSource(keyboard: String, conformsToKeyboard: Bool? = nil) {
        let currentSource: TISInputSource = TISCopyCurrentKeyboardInputSource().takeUnretainedValue()
        kb2is[keyboard] = currentSource

        // Only set a default value for deviceEnabled if conformsToKeyboard is provided
        if let isKeyboard = conformsToKeyboard, deviceEnabled[keyboard] == nil {
            log.debug("Enabling device by default because it is recognized as a keyboard")
            deviceEnabled[keyboard] = isKeyboard
        }

        saveMappings()
    }

    func onInputSourceChanged() {
        assignmentLock.lock()
        // lastActiveKeyboard can be nil only if the language is changed between
        // program start and the first keypress, so we can ignore this edge case
        if let lastActiveKeyboard = lastActiveKeyboard {
            storeInputSource(keyboard: lastActiveKeyboard)
        }
        assignmentLock.unlock()
    }

    func onKeyboardEvent(keyboard: String, conformsToKeyboard: Bool? = nil) {
        guard lastActiveKeyboard != keyboard else {
            log.trace("change: ignoring event from keyboard \(keyboard) because active device hasn't changed")
            return
        }

        log.debug("change: keyboard changed from \(lastActiveKeyboard ?? "nil") to \(keyboard)")

        let isEnabled = deviceEnabled[keyboard] ?? true
        guard isEnabled else {
            log.trace("change: ignoring event from keyboard \(keyboard) because device is disabled")
            return
        }

        assignmentLock.lock()
        if kb2is[keyboard] == nil {
            // This keyboard has no mapping yet, store the current input source
            log.debug("New device detected: \(keyboard), storing current input source")
            storeInputSource(keyboard: keyboard, conformsToKeyboard: conformsToKeyboard)
        } else {
            // Keyboard is different from the previously used keyboard, restore settings.
            restoreInputSource(keyboard: keyboard)
        }

        lastActiveKeyboard = keyboard
        assignmentLock.unlock()
    }
}

// MARK: - Device Management

public extension IOKeyEventMonitor {
    func enableDevice(_ keyboard: String) {
        deviceEnabled[keyboard] = true
        saveMappings()
    }

    func disableDevice(_ keyboard: String) {
        deviceEnabled[keyboard] = false
        saveMappings()
    }

    func enableDeviceByNumber(_ number: Int) {
        let devices = Array(deviceEnabled.keys).sorted()
        guard number > 0, number <= devices.count else {
            print("Invalid device number")
            return
        }
        let keyboard = devices[number - 1]
        deviceEnabled[keyboard] = true
        saveMappings()
    }

    func disableDeviceByNumber(_ number: Int) {
        let devices = Array(deviceEnabled.keys).sorted()
        guard number > 0, number <= devices.count else {
            print("Invalid device number")
            return
        }
        let keyboard = devices[number - 1]
        deviceEnabled[keyboard] = false
        saveMappings()
    }

    func getDevicesString() -> String {
        return deviceEnabled
            .sorted { $0.key < $1.key }
            .enumerated()
            .map { index, entry -> String in
                let (keyboard, isEnabled) = entry
                let number = index + 1
                let status = isEnabled ? "enabled" : "disabled"
                var layoutInfo = "no layout stored"

                if let source = kb2is[keyboard] {
                    let name = TISGetInputSourceProperty(source, kTISPropertyLocalizedName)
                    let localizedName = unmanagedStringToString(name) ?? "unknown"
                    let id = is2Id(source) ?? "unknown"
                    layoutInfo = "\(localizedName) (\(id))"
                }

                return "\(number). \(keyboard): \(status) - \(layoutInfo)"
            }
            .joined(separator: "\n")
    }
}

// MARK: - Persistence

extension IOKeyEventMonitor {
    func loadMappings() {
        kb2is.removeAll()
        deviceEnabled.removeAll()

        let selectableIsProperties = [
            kTISPropertyInputSourceIsEnableCapable: true,
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource ?? "" as CFString,
        ] as CFDictionary
        let inputSources = TISCreateInputSourceList(selectableIsProperties, false).takeUnretainedValue() as! [TISInputSource]

        let inputSourcesById = inputSources.reduce([String: TISInputSource]()) {
            dict, inputSource -> [String: TISInputSource] in
            var dict = dict
            if let id = unmanagedStringToString(TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID)) {
                dict[id] = inputSource
            }
            return dict
        }

        if let mappings = defaults.dictionary(forKey: MAPPINGS_DEFAULTS_KEY) {
            for (keyboardId, inputSourceId) in mappings {
                kb2is[keyboardId] = inputSourcesById[String(describing: inputSourceId)]
            }
        }

        if let enabledMappings = defaults.dictionary(forKey: MAPPING_ENABLED_KEY) as? [String: Bool] {
            deviceEnabled = enabledMappings
        }
    }

    func saveMappings() {
        withPausedSettingsObserver {
            let mappings = kb2is.mapValues(is2Id)
            defaults.set(mappings, forKey: MAPPINGS_DEFAULTS_KEY)
            defaults.set(deviceEnabled, forKey: MAPPING_ENABLED_KEY)
            defaults.synchronize()

            postSettingsChangedNotification()
        }

        log.trace("Saved keyboard mappings to UserDefaults")
    }

    public func clearAllSettings() {
        withPausedSettingsObserver {
            kb2is.removeAll()
            deviceEnabled.removeAll()
            lastActiveKeyboard = nil
            defaults.removeObject(forKey: MAPPINGS_DEFAULTS_KEY)
            defaults.removeObject(forKey: MAPPING_ENABLED_KEY)
            defaults.synchronize()

            postSettingsChangedNotification()
        }
    }
}

// MARK: - Settings Change Notifications

private extension IOKeyEventMonitor {
    private func startObservingSettingsChanges() {
        log.trace("Starting UserDefaults observation")

        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let callback: CFNotificationCallback = { _, observer, _, _, _ in
            let selfPtr = Unmanaged<IOKeyEventMonitor>.fromOpaque(observer!).takeUnretainedValue()
            selfPtr.log.trace("Received settings change notification")
            selfPtr.onSettingsChanged()
        }

        CFNotificationCenterAddObserver(
            notificationCenter,
            context,
            callback,
            "com.autokbisw.settingsChanged" as CFString,
            nil,
            .deliverImmediately
        )
    }

    private func stopObservingSettingsChanges() {
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CFNotificationCenterRemoveObserver(
            notificationCenter,
            context,
            CFNotificationName("com.autokbisw.settingsChanged" as CFString),
            nil
        )
    }

    private func postSettingsChangedNotification() {
        log.trace("Posting settings changed notification")
        CFNotificationCenterPostNotification(
            notificationCenter,
            CFNotificationName("com.autokbisw.settingsChanged" as CFString),
            nil,
            nil,
            true
        )
    }

    private func withPausedSettingsObserver<T>(_ operation: () -> T) -> T {
        stopObservingSettingsChanges()
        defer { startObservingSettingsChanges() }
        return operation()
    }

    private func onSettingsChanged() {
        loadMappings()

        // If mappings are empty, settings were cleared in another instance
        if kb2is.isEmpty, deviceEnabled.isEmpty {
            lastActiveKeyboard = nil
        }

        log.trace("Reloaded mappings due to UserDefaults change")
    }
}

// MARK: - Utilities

extension IOKeyEventMonitor {
    private func is2Id(_ inputSource: TISInputSource) -> String? {
        return unmanagedStringToString(TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID))!
    }

    func unmanagedStringToString(_ p: UnsafeMutableRawPointer?) -> String? {
        if let cfValue = p {
            let value = Unmanaged.fromOpaque(cfValue).takeUnretainedValue() as CFString
            if CFGetTypeID(value) == CFStringGetTypeID() {
                return value as String
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
}
