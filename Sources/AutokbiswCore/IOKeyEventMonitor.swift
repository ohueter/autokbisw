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

import Carbon
import Foundation
import IOKit
import IOKit.hid
import IOKit.usb

public let DEBUG = 1
public let TRACE = 2

public final class IOKeyEventMonitor {
    private let hidManager: IOHIDManager
    fileprivate let notificationCenter: CFNotificationCenter

    fileprivate let MAPPINGS_DEFAULTS_KEY = "keyboardISMapping"
    fileprivate var defaults: UserDefaults = .standard

    fileprivate let MAPPING_ENABLED_KEY = "mappingEnabled"
    internal var deviceEnabled: [String: Bool] = [:]
    
    fileprivate let assignmentLock = NSLock()
    internal var lastActiveKeyboard: String? = nil
    internal var kb2is: [String: TISInputSource] = .init()

    fileprivate var useLocation: Bool
    public var verbosity: Int

    public init? (usagePage: Int, usage: Int, useLocation: Bool, verbosity: Int) {
        self.useLocation = useLocation
        self.verbosity = verbosity
        hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        notificationCenter = CFNotificationCenterGetDistributedCenter()
        let deviceMatch: CFMutableDictionary = [kIOHIDDeviceUsageKey: usage, kIOHIDDeviceUsagePageKey: usagePage] as NSMutableDictionary
        IOHIDManagerSetDeviceMatching(hidManager, deviceMatch)
        loadMappings()
    }

    deinit {
        self.saveMappings()
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerRegisterInputValueCallback(hidManager, Optional.none, context)
        CFNotificationCenterRemoveObserver(notificationCenter, context, CFNotificationName(kTISNotifySelectedKeyboardInputSourceChanged), nil)
    }

    public func start() {
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        observeIputSourceChangedNotification(context: context)
        registerHIDKeyboardCallback(context: context)

        IOHIDManagerScheduleWithRunLoop(hidManager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode!.rawValue)
        IOHIDManagerOpen(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
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

            let vendorId = IOHIDDeviceGetProperty(senderDevice, kIOHIDVendorIDKey as CFString) ??? "unknown"
            let productId = IOHIDDeviceGetProperty(senderDevice, kIOHIDProductIDKey as CFString) ??? "unknown"
            let product = IOHIDDeviceGetProperty(senderDevice, kIOHIDProductKey as CFString) ??? "unknown"
            let manufacturer = IOHIDDeviceGetProperty(senderDevice, kIOHIDManufacturerKey as CFString) ??? "unknown"
            let serialNumber = IOHIDDeviceGetProperty(senderDevice, kIOHIDSerialNumberKey as CFString) ??? "unknown"
            let locationId = IOHIDDeviceGetProperty(senderDevice, kIOHIDLocationIDKey as CFString) ??? "unknown"
            let uniqueId = IOHIDDeviceGetProperty(senderDevice, kIOHIDUniqueIDKey as CFString) ??? "unknown"

            let keyboard = selfPtr.useLocation
                ? "\(product)-[\(vendorId)-\(productId)-\(manufacturer)-\(serialNumber)-\(locationId)]"
                : "\(product)-[\(vendorId)-\(productId)-\(manufacturer)-\(serialNumber)]"

            if selfPtr.verbosity >= TRACE {
                print("received event from device \(keyboard) - \(locationId) - \(uniqueId)")
            }

            selfPtr.onKeyboardEvent(keyboard: keyboard, conformsToKeyboard: conformsToKeyboard)
        }

        IOHIDManagerRegisterInputValueCallback(hidManager, myHIDKeyboardCallback, context)
    }

    private func deviceConformsToKeyboard(_ device: IOHIDDevice) -> Bool {
        return IOHIDDeviceConformsTo(device, UInt32(kHIDPage_GenericDesktop), UInt32(kHIDUsage_GD_Keyboard))
    }
}

extension IOKeyEventMonitor {
    public func restoreInputSource(keyboard: String) {
        guard let targetIs = kb2is[keyboard] else {
            if verbosity >= TRACE {
                print("No previous mapping saved for \(keyboard), awaiting the user to select the right one")
            }

            return
        }

        if verbosity >= DEBUG {
            print("Setting input source for keyboard \(keyboard):\n\t\(targetIs)")
        }

        // This will trigger onInputSourceChanged()
        TISSelectInputSource(targetIs)
    }

    public func storeInputSource(keyboard: String, conformsToKeyboard: Bool? = nil) {
        let currentSource: TISInputSource = TISCopyCurrentKeyboardInputSource().takeUnretainedValue()
        kb2is[keyboard] = currentSource

        // Only set a default value for deviceEnabled if conformsToKeyboard is provided
        if let isKeyboard = conformsToKeyboard, deviceEnabled[keyboard] == nil {
            deviceEnabled[keyboard] = isKeyboard
        }

        saveMappings()
    }

    public func onInputSourceChanged() {
        assignmentLock.lock()
        // lastActiveKeyboard can be nil only if the language is changed between
        // program start and the first keypress, so we can ignore this edge case
        if let lastActiveKeyboard = lastActiveKeyboard {
            storeInputSource(keyboard: lastActiveKeyboard)
        }
        assignmentLock.unlock()
    }

    public func onKeyboardEvent(keyboard: String, conformsToKeyboard: Bool? = nil) {
        guard lastActiveKeyboard != keyboard else { return }

        if verbosity >= TRACE {
            print("change: keyboard changed from \(lastActiveKeyboard ?? "nil") to \(keyboard)")
        }

        let isEnabled = deviceEnabled[keyboard] ?? true
        guard isEnabled else { 
            if verbosity >= DEBUG {
                print("change: ignoring event from keyboard \(keyboard) because device is disabled")
            }

            return
        }

        assignmentLock.lock()
        if lastActiveKeyboard == nil {
            // It's the first keyboard event from this keyboard since starting the program.
            // Persist settings, assuming the current setup is what the user wants to use
            // for the currently typing keyboard.
            storeInputSource(keyboard: keyboard, conformsToKeyboard: conformsToKeyboard)
        } else {
            // Keyboard is different from the previously used keyboard, restore settings.
            restoreInputSource(keyboard: keyboard)
        }

        lastActiveKeyboard = keyboard
        assignmentLock.unlock()
    }

    func loadMappings() {
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
        let mappings = kb2is.mapValues(is2Id)
        defaults.set(mappings, forKey: MAPPINGS_DEFAULTS_KEY)
        defaults.set(deviceEnabled, forKey: MAPPING_ENABLED_KEY)
    }

    public func enableDevice(_ keyboard: String) {
        deviceEnabled[keyboard] = true
        saveMappings()
    }

    public func disableDevice(_ keyboard: String) {
        deviceEnabled[keyboard] = false
        saveMappings()
    }

    public func getDevicesString() -> String {
        return deviceEnabled.map { "\($0.key): \($0.value ? "enabled" : "disabled")" }.joined(separator: "\n")
    }

    public func clearAllSettings() {
        kb2is.removeAll()
        deviceEnabled.removeAll()
        lastActiveKeyboard = nil
        defaults.removeObject(forKey: MAPPINGS_DEFAULTS_KEY)
        defaults.removeObject(forKey: MAPPING_ENABLED_KEY)
        defaults.synchronize()
    }

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

// Nicer string interpolation of optional strings, see: https://oleb.net/blog/2016/12/optionals-string-interpolation/

infix operator ???: NilCoalescingPrecedence

public func ??? <T>(optional: T?, defaultValue: @autoclosure () -> String) -> String {
    return optional.map { String(describing: $0) } ?? defaultValue()
}
