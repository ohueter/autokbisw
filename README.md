# autokbisw – Automatic keyboard input language switcher

Automatic keyboard input language switching for macOS.

`autokbisw` is made for those who use multiple keyboards with different key layouts (e.g. English and French), and frequently switch between them. It runs as a background service and remembers the last active keyboard input language for a specific keyboard and automatically activates it when typing on that keyboard again.

## Features

- Automatically switches the keyboard layout (input source) based on the connected keyboard
- Identifies keyboards by their product name, hardware ID, and optionally the connected USB port (location ID)
- Command-line interface to enable/disable switching for specific keyboards

## Installation

The easiest way to install `autokbisw` as a background service is by using [Homebrew](https://brew.sh):

```sh
brew install ohueter/tap/autokbisw
brew services start autokbisw
```

Please note that `autokbisw` is compiled from source by Homebrew, so a full installation of Xcode.app is required. Installing just the Command Line Tools is not sufficient.

`autokbisw` requires privileges to monitor all keyboard input. You need to grant these privileges on the first start of the service.

### Upgrading an existing installation

If you already have `autokbisw` installed, you can upgrade it by running the following command:

```sh
brew upgrade ohueter/tap/autokbisw
```

This will update the formula to the latest version and reinstall it.

## Getting started

- Begin typing with your first keyboard, so it becomes the **active keyboard**.
- Select the desired **keyboard layout** for your first keyboard by selecting it in the menu bar or pressing the <kbd>🌐</kbd> key.
- Begin typing with your second keyboard, so it becomes the **active keyboard**.
- Select the desired **keyboard layout** for your second keyboard.
- Repeat if you are using more keyboards.

You should notice that after the first keystroke on any of your keyboards, the keyboard layout automatically switches to the selected one. Note that the keyboard layout switch happens **after** the first keystroke, so you won't have the selected keyboard layout at this time.

## Enabling/disabling switching for specific keyboards

By default, `autokbisw` uses device identification data reported by the hardware to determine whether to enable automatic switching. However, some devices report incorrect information: keyboards may identify as mice (and thus be initially disabled), while mice may identify as keyboards (triggering unwanted input source switches). If you encounter either issue, you can manually enable or disable switching for specific devices using the command-line interface.

### Listing Devices

To list all known devices and their current status:

```sh
autokbisw list
```

This will display a numbered list of devices with their identifier, status (enabled/disabled), and the associated keyboard layout.

Note: Devices only appear in this list after they've been used for text input while `autokbisw` was running.

### Enabling/disabling switching

To enable keyboard layout switching for a specific keyboard:

```sh
autokbisw enable <device number or identifier>
```

To disable keyboard layout switching for a specific keyboard:

```sh
autokbisw disable <device number or identifier>
```

You can use either the device number (obtained from the `list` subcommand) or the device identifier to specify the keyboard.

## Building from source

Clone this repository, make sure you have a full Xcode.app installation, and run the following commands:

```sh
cd autokbisw
swift build --configuration release
```

The output will provide the path to the built binary, likely `.build/release/autokbisw`. You can run it from the `release` directory as is.

### Command-line arguments

```
OVERVIEW: Automatic keyboard/input source switching for macOS.

USAGE: autokbisw [--verbose <verbosity>] [--location] <subcommand>

OPTIONS:
  -v, --verbose <verbosity>
                          Print verbose output (1 = DEBUG, 2 = TRACE). (default: 0)
  -l, --location          Use locationId to identify keyboards.
        Note that the locationId changes when you plug a keyboard in a different port. Therefore using the locationId in the keyboards
        identifiers means the configured language will be associated to a keyboard on a specific port.
  -h, --help              Show help information.

SUBCOMMANDS:
  enable                  Enable input source switching for <device number or identifier>.
  disable                 Disable input source switching for <device number or identifier>.
  list                    List all known devices and their current status.
  clear                   Clear all stored mappings and device settings.

  See 'autokbisw help <subcommand>' for detailed help.
```

## FAQ & Common issues

### The installation fails with an XCode error.

On some system configurations, the installation fails with XCode errors similar to those described in GitHub issues [#12](https://github.com/ohueter/autokbisw/issues/12) and [#28](https://github.com/ohueter/autokbisw/issues/28). In order to check if your system is affected, run

```sh
xcode-select --print-path
```

in the terminal. The expected output is `/Applications/Xcode.app/Contents/Developer`. If the output on your system is different, run

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

to set the correct path and (hopefully) fix the compilation.

### autokbisw doesn't work after installation.

If `autokbisw` isn't working after the first start of the service, try these solutions:

1. Restart the service:

   ```sh
   brew services restart autokbisw
   ```

2. Re-grant the required privileges to the service by removing and re-adding the executable under `System Preferences > Security & Privacy > Privacy > Input Monitoring`. The path to add should either be `/usr/local/bin/autokbisw` (on Intel Macs) or `/opt/homebrew/opt/autokbisw/bin/autokbisw` (on Apple M1 Macs).

### autokbisw doesn't work as expected with my Logitech keyboard or mouse.

It seems that some Logitech devices miss-identify as keyboard or mouse, although they're actually the respective other kind of device (see GitHub issues [#7](https://github.com/ohueter/autokbisw/issues/7) or [#18](https://github.com/ohueter/autokbisw/issues/18) for examples). If `autokbisw` isn't working for you because of this issue, try enabling/disabling switching for specific devices using the command-line interface (see [Enabling/disabling switching for specific keyboards](#enablingdisabling-switching-for-specific-keyboards)). Open a new issue if it's still not working for your device.

### Can autokbisw be used with the `Automatically switch to a document's input source` option?

`autokbisw` is not compatible with the `Automatically switch to a document's input source` system option (found under System Settings > Keyboard > Input sources > Edit…). If the setting is turned on, `autokbisw` might not work as expected (see [#33](https://github.com/ohueter/autokbisw/issues/33)).

### Can autokbisw be used with Karabiner-Elements?

`autokbisw` is not compatible with [Karabiner Elements](https://karabiner-elements.pqrs.org/), since it proxies keyboard events. That makes Karabiner appear as the system input device, and `autokbisw` can't detect the original input device. However, you can manually configure Karabiner to switch keyboard layouts based on device ID and other variables, it just won't be _fully_ automated -- see [this GH answer](https://github.com/pqrs-org/Karabiner-Elements/issues/2230#issuecomment-2043513996).

### autokbisw is installed correctly but the background service does not changes the language?

Try to unload and reload the plist and reboot (see [discussion for reference](https://github.com/ohueter/autokbisw/discussions/38#discussioncomment-9127439)):

```sh
launchctl unload ~/Library/LaunchAgents/homebrew.mxcl.autokbisw.plist
launchctl load ~/Library/LaunchAgents/homebrew.mxcl.autokbisw.plist
```

## Acknowledgements

This program was originally developed by [Jean Helou](https://github.com/jeantil/autokbisw) ([@jeantil](https://github.com/jeantil)).
