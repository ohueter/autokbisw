#if SWIFT_PACKAGE_INFOPLIST
    import Foundation

    let infoPlistData = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>CFBundleIdentifier</key>
        <string>com.autokbisw</string>
        <key>CFBundleName</key>
        <string>autokbisw</string>
        <key>NSInputMonitoringUsageDescription</key>
        <string>Autokbisw needs Input Monitoring permission to detect keyboard changes and switch input sources.</string>
    </dict>
    </plist>
    """

    @_cdecl("__info_plist")
    public func __info_plist() -> UnsafePointer<CChar>? {
        let ptr = strdup(infoPlistData)
        return UnsafePointer(ptr)
    }
#endif
