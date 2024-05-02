# Autokbisw - Automatic keyboard input source switcher

`autokbisw` is a useful tool for those who use multiple keyboards with different key layouts (e.g. English and French), and frequently switch between them. It runs as a background service and works by remembering the last active macOS input source (i.e., key mapping) for a specific keyboard and automatically restoring it when that keyboard becomes active again.

## Installation

The easiest way to install autokbisw as a background service is by using [Homebrew](https://brew.sh):

```sh
brew install ohueter/tap/autokbisw
brew services start autokbisw
```

Please note that `autokbisw` is compiled from source by Homebrew, so a full installation of Xcode.app is required. Installing just the Command Line Tools is not sufficient.

`autokbisw` requires privileges to monitor all keyboard input. You need to grant these privileges on the first start of the service.

## Usage instructions

- Begin typing with your first keyboard, so it becomes the `active keyboard`.
- Select the desired `Input source` for your first keyboard.
- Begin typing with your second keyboard, so it becomes the `active keyboard`.
- Select the desired `Input source` for your second keyboard.
- Repeat if you are using more keyboards.

You should notice that after the first keystroke on any of your keyboards, the input source automatically switches to the selected one. Note that the input source switch happens **after** the first keystroke, so you won't have the selected input source at this time.

## Building from source

Clone this repository, make sure you have a full Xcode.app installation, and run the following commands:

```sh
cd autokbisw
swift build --configuration release
```

The output will provide the path to the built binary, likely `.build/release/autokbisw`. You can run it from the `release` directory as is.

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

It seems that some Logitech devices miss-identify as keyboard or mouse, although they're actually the respective other kind of device (see GitHub issues [#7](https://github.com/ohueter/autokbisw/issues/7) or [#18](https://github.com/ohueter/autokbisw/issues/18) for examples). If `autokbisw` isn't working for you because of this issue, currently the only option is to fork the repository, edit the source code and build the program with your changes.

**Help wanted:** We've sketched a software design change (manually activate or deactivate autokbisw for specific devices) in issues [#24](https://github.com/ohueter/autokbisw/issues/24) and [#25](https://github.com/ohueter/autokbisw/issues/25) to resolve this issue. If you are proficient in Swift and would like to contribute, your help would be greatly appreciated!

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
