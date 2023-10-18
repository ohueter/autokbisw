# Autokbisw - Automatic keyboard input source switcher

`autokbisw` is a useful tool for those who use multiple keyboards with different key layouts (e.g. English and French), and frequently switch between them. It runs as a background service and works by remembering the last active macOS input source (i.e., key mapping) for a specific keyboard and automatically restoring it when that keyboard becomes active again.

## Installation

The easiest way to install autokbisw as a background service is by using [Homebrew](https://brew.sh):

```
brew install ohueter/tap/autokbisw
brew services start autokbisw
```

Please note that `autokbisw` is compiled from source by Homebrew, so a full installation of Xcode.app is required. Installing just the Command Line Tools is not sufficient.

`autokbisw` requires privileges to monitor all keyboard input. You need to grant these privileges on the first start of the service.

### Throubleshooting

If `autokbisw` isn't working after the first start of the service, try these solutions:

1. Restart the service:

   ```
   brew services restart autokbisw
   ```

2. Re-grant the required privileges to the service by removing and re-adding the executable under `System Preferences > Security & Privacy > Privacy > Input Monitoring`. The path to add should either be `/usr/local/bin/autokbisw` (on Intel Macs) or `/opt/homebrew/opt/autokbisw/bin/autokbisw` (on Apple M1 Macs).

## Usage instructions

- Begin typing with your first keyboard, so it becomes the `active keyboard`.
- Select the desired `Input source` for your first keyboard.
- Begin typing with your second keyboard, so it becomes the `active keyboard`.
- Select the desired `Input source` for your second keyboard.
- Repeat if you are using more keyboards.

You should notice that after the first keystroke on any of your keyboards, the input source automatically switches to the selected one. Note that the input source switch happens **after** the first keystroke, so you won't have the selected input source at this time.

## Building from source

Clone this repository, make sure you have a full Xcode.app installation, and run the following commands:

```
cd autokbisw
swift build --configuration release
```

The output will provide the path to the built binary, likely `.build/release/autokbisw`.

To give the binary all the required permissions and to launch autokbisw at login, create a .plist file containing the following content, and making sure to replace '/path/to/autokbisw' with the actual full path of your autokbisw binary:

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>autokbisw</string>
    <key>ProgramArguments</key>
    <array>
      <string>/path/to/autokbisw</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
  </dict>
</plist>
```

Save the .plist file in /Library/LaunchAgents and launch autokbisw for the fist time using the following command:

```
launchctl load /Library/LaunchAgents/autokbisw.plist
```

You will be prompted to allow the application to monitor keyboard input, and upon first restart you will be notified that autokbisw is allowed to run as a background process.

### Command-Line Arguments

```
USAGE: autokbisw [--verbose <verbosity>] [--location]

OPTIONS:
  -v, --verbose <verbosity>
                          Print verbose output (1 = DEBUG, 2 = TRACE). (default: 0)
  -l, --location          Use locationId to identify keyboards.
                          Note that the locationId changes when you plug a keyboard in a different port.
                          Therefore using the locationId in the keyboards identifiers means the configured
                          language will be associated to a keyboard on a specific port.
  -h, --help              Show help information.

```

## Acknowledgements

This program was originally developed by [Jean Helou](https://github.com/jeantil/autokbisw) ([@jeantil](https://github.com/jeantil)).
