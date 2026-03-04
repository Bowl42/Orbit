# Ring

A macOS menubar utility that puts your most-used apps and text lookup one mouse button away.

## Features

**Mouse Button 5 — App Ring**
Press mouse button 5 to show a radial ring of up to 8 app icons around the cursor. Click any icon to switch to that app (launching it if not running). Click outside or press button 5 again to dismiss.

**Mouse Button 4 — Look Up**
Press mouse button 4 to trigger macOS's native "Look Up" on the word under the cursor or selected text.

**Configure Slots**
Open *Ring → Configure Slots…* from the menubar icon to pin apps to fixed positions in the ring.

- The left panel shows all 8 slots arranged as a ring — matching what you'll see on screen
- Tap a slot to select it, then tap an app icon to assign it
- Or drag any app icon directly onto a slot
- Hover a slot and click the ✕ badge to clear it
- Unassigned slots auto-fill with currently running apps at ring open time

## Requirements

- macOS 13 or later
- A mouse with at least 5 buttons
- Input Monitoring permission (prompted on first launch)

## Build

```bash
make        # build only
make run    # build and open
make clean  # remove build artifacts
```

Requires Xcode command line tools and Swift.

## Permissions

Ring requires **Input Monitoring** permission to listen for mouse button 4/5 events system-wide. The app prompts on first launch. If you rebuild with ad-hoc signing, macOS may revoke the permission — re-grant it in *System Settings → Privacy & Security → Input Monitoring*.
