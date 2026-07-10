# 20-20-20

A tiny native macOS menu bar app for the 20-20-20 rule: every **20 minutes**, look at something **20 feet** away for **20 seconds**. Helps with dry eyes and screen-induced blink suppression.

## How it works

- An eye icon with a live countdown sits in your menu bar. Click it for a popover with the timer ring, pause/skip controls, and settings.
- When the countdown hits zero, the screen gently dims into a calm overlay with a 20-second ring ("Look somewhere far away"), then fades out on its own. Press **esc** if you're mid-thought and need to skip.
- **Idle-aware:** if you step away from the keyboard for a few minutes the countdown freezes, and a long absence refills it — no break demands right after you return from lunch.
- **Call-aware:** whenever a call is detected (Zoom, Google Meet, Microsoft Teams — anything that holds the mic or camera open), a small camera badge appears on the menu bar eye so you can see the app knows, while the countdown keeps ticking. If a break comes due mid-call it's *held*, not lost: the badged eye shows "due", and the break fires about 10 seconds after the call ends (once you're back at the keyboard). If you walk away after the call instead, that counts as your rest and the timer just restarts. Detection reads CoreAudio/CoreMediaIO device state only, so it needs no permissions and works for browser-tab calls too.
- **Daily stats:** the popover shows today's completed breaks, manual skips (esc), and breaks held for calls, plus a 🔥 streak of consecutive days with at least one completed break. Counts reset at midnight.
- Waking from sleep resets the timer.

## Settings (in the popover)

- Reminder interval (10–45 min) and break length (20–60 s)
- Soft start/end sounds on or off
- Hold breaks during calls on or off
- Countdown in the menu bar on or off
- Start at login

## Build & install

Requires only Xcode Command Line Tools (`xcode-select --install`), macOS 14+.

```sh
./build.sh          # builds build/20-20-20.app
./build.sh install  # builds, copies to ~/Applications, launches
```

The app is ad-hoc signed and sandboxed to nothing unusual — no network, no permissions prompts. Quit it any time from the popover.

## Updating an existing installation

```sh
git pull
./build.sh install
```

`install` quits the running copy, replaces `~/Applications/20-20-20.app`, and relaunches it — no manual cleanup needed. Your settings, daily stats, and streak all survive updates (they live in `UserDefaults`, keyed by the bundle identifier, not in the app bundle).

Two notes:

- If you've been running the app straight from `build/` instead of `~/Applications`, quit it first (popover → Quit), then use `./build.sh install` so there's only one copy.
- **Start at login** points at the app's path. It survives an in-place replacement, but if the login item ever stops firing after an update, flip the toggle off and on again in the popover.
