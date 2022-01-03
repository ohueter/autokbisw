# Autokbisw - Automatic keyboard input source switcher

## Motivation

This small utility was born out of frustation after a mob programming sesssion.
The session took place on a french mac book pro, using a pair of french pc
keyboards. Some programmers were used to eclipse, others to intellij on linux,
others to intellij on mac. 

While macOS automatically switches the layout when a keyboard is activated it
doesn't change the keymap, meaning we had to remember changing both the OS _and_
the IDE keymap each time we switched developer. 

This software removes one of the switches: it memorizes the last active macOS
input source for a given keyboard and restores it automatically when that
keyboard becomes the active keyboard. 

### Build from Source

Clone this repository, make sure you have XCode installed and run the following commands:

```
cd autokbisw
swift build --configuration release
```

In the output will be the path to the built program, something like `.build/release/autokbisw`.

You can run it from the `release` directory as is.

## Installation 

To install it in `/usr/local/bin`, run:

```
sudo cp .build/release/autokbisw /usr/local/bin/
```

If you want the program to start automatically when you log in,
you can copy the provided plist file to `~/Library/LaunchAgents` and load it
manually for the first run: 
```
cp eu.byjean.autokbisw.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/eu.byjean.autokbisw.plist
```

## Troubleshooting

If `launchctl` returns an error, you may try one of the following:

### 1. Reboot
Running `launchctl` sometimes produced inexplainable error messages (to me), that often were gone after rebooting. 🤷‍♂️

### 2. Unload and load the service again:
```
launchctl unload ~/Library/LaunchAgents/eu.byjean.autokbisw.plist
launchctl load ~/Library/LaunchAgents/eu.byjean.autokbisw.plist
```

### 3. Force a restart of the service:
```
launchctl kickstart -kp gui/501/eu.byjean.autokbisw
```

This may be needed on the first run, after permissions to capture all keyboard events have been granted.

`501` may need to be replaced with your user id (uid). To find your user id, run:
```
id
```

### 4. Maybe you need to (re-)enable the service:
```
launchctl enable gui/501/eu.byjean.autokbisw
```