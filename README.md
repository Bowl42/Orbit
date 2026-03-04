# Ring

A macOS menubar utility that puts your most-used apps and text lookup one mouse button away.

## Features

**Mouse Button 5 — App Ring**
Hold mouse button 5 to show a radial ring of apps around the cursor. Click any icon to switch to that app (or launch it if it's not running). Click outside or press the button again to dismiss.

**Mouse Button 4 — Look Up**
Press mouse button 4 to trigger macOS's native "Look Up" on the selected text or the word under the cursor.

**Configure Slots**
Open *Ring → Configure Slots…* from the menubar to pin specific apps to fixed positions in the ring. Drag apps from the list on the right onto a slot. Click a slot to clear it.

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

Ring uses the **Input Monitoring** permission to listen for mouse button 4/5 events globally. Without it the app will still launch but the mouse buttons won't work. Grant access in *System Settings → Privacy & Security → Input Monitoring*.
