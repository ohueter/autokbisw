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

internal final class IOKeyEventMonitor {
    private let hidManager: IOHIDManager
    fileprivate let MAPPINGS_DEFAULTS_KEY = "keyboardISMapping"
    fileprivate let notificationCenter: CFNotificationCenter
    fileprivate var lastActiveKeyboard: String? = nil
    fileprivate var kb2is: [String: KeyboardState] = .init()
    fileprivate var lang2inputSource: [String: TISInputSource] = .init()
    fileprivate var defaults: UserDefaults = .standard
    fileprivate var useLocation: Bool
    fileprivate var verbosity: Int
    fileprivate let assignmentLock = NSLock()

    init? (usagePage: Int, usage: Int, useLocation: Bool, verbosity: Int) {
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

    func start() {
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

            let conformsToKeyboard = IOHIDDeviceConformsTo(senderDevice, UInt32(kHIDPage_GenericDesktop), UInt32(kHIDUsage_GD_Keyboard))

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


            if conformsToKeyboard {
                if selfPtr.verbosity >= TRACE {
                    print("received event from keyboard \(keyboard) - \(locationId) - \(uniqueId)")
                }
                selfPtr.onKeyboardEvent(keyboard: keyboard)
            } else {
                if selfPtr.verbosity >= TRACE {
                    print("received event from device \(keyboard) - \(locationId) - \(uniqueId). Ignoring as device is not a keyboard")
                }
            } 
        }

        IOHIDManagerRegisterInputValueCallback(hidManager, myHIDKeyboardCallback, context)
    }
}

fileprivate func unmanagedStringToString(_ p: UnsafeMutableRawPointer?) -> String? {
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

extension IOKeyEventMonitor {
    /**
     Init/deinit functions
     */
    
    func loadMappings() {
        let selectableIsProperties = [
            kTISPropertyInputSourceIsEnableCapable: true,
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource ?? "" as CFString,
        ] as CFDictionary
        let inputSources = TISCreateInputSourceList(selectableIsProperties, false).takeUnretainedValue() as! [TISInputSource]
        
        if verbosity >= DEBUG {
            print("Loading mappings\n")
        }
        self.lang2inputSource = inputSources.reduce([String: TISInputSource]()) {
            dict, inputSource -> [String: TISInputSource] in
                var dict = dict
                if let id = unmanagedStringToString(TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID)) {
                    dict[id] = inputSource
                    if verbosity >= DEBUG {
                        print("\t\(id):\t\(inputSource)")
                    }
                }
                return dict
        }
        
        if verbosity >= DEBUG {
            print("\nPersisted configs\n")
        }

        self.kb2is = Dictionary()
        guard let stored = defaults.dictionary(forKey: MAPPINGS_DEFAULTS_KEY) else {
            return
        }
        for (key, val) in stored {
            guard let data = val as? Data else {
                continue
            }
            let decoded = try? PropertyListDecoder().decode(KeyboardState.self, from: data)
            guard let retval = decoded else {
                continue
            }
            self.kb2is[key] = retval
            if verbosity >= DEBUG {
                print("\t\(key):\t\(retval)")
            }
        }
        
        if verbosity >= DEBUG {
            print("")
        }
    }
    
    /**
     Store functions
     */
    
    func saveMappings() {
        let data = kb2is.mapValues{ val in
            return try? PropertyListEncoder().encode(val)
        }
        defaults.set(data, forKey: MAPPINGS_DEFAULTS_KEY)
    }
    
    func getKbdStateForSource() -> KeyboardState {
        let currentSource: TISInputSource = TISCopyCurrentKeyboardInputSource().takeUnretainedValue()
        let lang = unmanagedStringToString(TISGetInputSourceProperty(currentSource, kTISPropertyInputSourceID))!
        return KeyboardState(lang: lang)
    }

    func storeInputSource(keyboard: String) {
        let kbstate = getKbdStateForSource()
        kb2is[keyboard] = kbstate
        
        if verbosity >= DEBUG {
            print("STORing values for keyboard \(keyboard):\n\t\(kbstate)")
        }
        saveMappings()
    }
    
    /**
     Apply functions
     */
    func restoreInputSource(keyboard: String) {
        guard let targetIs = kb2is[keyboard] else {
            if verbosity >= TRACE {
                print("No previous mapping saved for \(keyboard), awaiting the user to select the right one")
            }
            return
        }
        if verbosity >= DEBUG {
            print("SETting values for keyboard \(keyboard):\n\t\(targetIs)")
        }
        if let lang = self.lang2inputSource[String(describing: targetIs.lang)] {
            //This triggers the listener, see comment on onInputSourceChanged
            TISSelectInputSource(lang)
        } else {
            if verbosity >= DEBUG {
                print("Lang \(targetIs) associated to \(keyboard) is not available anymore")
            }
        }
    }
    
    /**
     Entrypoints functions
     */

    /**
     This function is used to store changes in the config done by the user, to assign the correct language to the current keyboard.
     If a language change happens meanwhile we are changing it to be the new keyboard's, there can be disalignments from what is saved and what is applied, hence the lock.
     This is also triggered when we set a new input source, thus generating an unnecessary save, as we would re-assign the mapping to the keyboard.
     */
    func onInputSourceChanged() {
        self.assignmentLock.lock()
        //lastActiveKeyboard can be nil only if the language is changed between program start and the first keypress, so we can ignore this corner case
        if let lastActiveKeyboard = lastActiveKeyboard {
            storeInputSource(keyboard: lastActiveKeyboard)
        }
        self.assignmentLock.unlock()
    }

    func onKeyboardEvent(keyboard: String) {
        guard lastActiveKeyboard != keyboard else { return }
        if verbosity >= TRACE {
            print("change: keyboard changed from \(lastActiveKeyboard ?? "nil") to \(keyboard)")
        }

        // It's a keyboard and either it's different from the previous keyboard or it's the first type with this keyboard since startup
        self.assignmentLock.lock()
        if lastActiveKeyboard == nil {
            // If it's the first type, persist settings, considering the current user setup is what the user wants to use for the currently typing keyboard
            storeInputSource(keyboard: keyboard)
        } else {
            // If it's different, so let's try restoring keyboard settings
            restoreInputSource(keyboard: keyboard)
        }
        self.lastActiveKeyboard = keyboard
        self.assignmentLock.unlock()
    }
}

// Nicer string interpolation of optional strings, see: https://oleb.net/blog/2016/12/optionals-string-interpolation/

infix operator ???: NilCoalescingPrecedence

public func ??? <T>(optional: T?, defaultValue: @autoclosure () -> String) -> String {
    return optional.map { String(describing: $0) } ?? defaultValue()
}
