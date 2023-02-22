# Autokbisw - Automatic keyboard input source switcher

## Motivation

This small utility was born out of frustation after a mob programming sesssion. The session took place on a french mac book pro, using a pair of french pc keyboards. Some programmers were used to eclipse, others to intellij on linux, others to intellij on mac.

While macOS automatically switches the layout when a keyboard is activated it doesn't change the keymap, meaning we had to remember changing both the OS _and_ the IDE keymap each time we switched developer.

This software removes one of the switches: it memorizes the last active macOS input source for a given keyboard and restores it automatically when that keyboard becomes the active keyboard.

## Homebrew

Install as a service using [Homebrew](https://brew.sh):

```
brew install ohueter/tap/autokbisw
brew services start ohueter/tap/autokbisw
```

`autokbisw` needs privileges to monitor all keyboard input. You have to grant these privileges on the first start of the service.

### Throubleshooting

If `autokbisw` doesn't work after the first start of the service, try to restart it:

```
brew services restart ohueter/tap/autokbisw
```

If `autokbisw` still doesn't work even after rebooting, try re-adding the executable manually to System Preferences > Security & Privacy > Privacy > Input Monitoring (after removing existing entries). The path to add should be `/usr/local/bin/autokbisw` (Intel Macs) or `/opt/homebrew/opt/autokbisw/bin/autokbisw` (Apple M1 Macs).

## How it works

- Begin Typing with your first keyboard, such that it becomes the `active keyboard`.
- Switch `Input source` to the appropriate one for your first keyboard.
- Begin Typing with your second keyboard, such that it becomes the `active keyboard`.
- Switch `Input source` to the appropriate one for your second keyboard.
- If everything is working, you should notice that after the first keystroke on any of your two keyboards, the input source automatically switches to the appropriate one.

NB: the input switch happens **after** the first keystroke, which means you won't have the appropriate input source at this time.

## Building from source

Clone this repository, make sure you have XCode installed and run the following commands:

```
cd autokbisw
swift build --configuration release
```

In the output will be the path to the built program, something like `.build/release/autokbisw`.

You can run it from the `release` directory as is.

## Acknowledgements

This program has originally been developed by [Jean Helou](https://github.com/jeantil/autokbisw) ([@jeantil](https://github.com/jeantil)).
