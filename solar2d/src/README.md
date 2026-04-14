# Solar2D Playground App

The Solar2D app that powers [Solar2D Playground](https://playground.solar2d.com/). It runs as an HTML5 build inside an iframe on the website, receives user code from the browser's code editor, and executes it via `loadstring()`.

## How It Works

The website's code editor sends Lua code to the app through a custom event dispatched on the iframe. The app calls `loadstring()` to compile and run the code. Before each run, the app performs a full reset: stops physics, cancels all timers and transitions, removes all Runtime listeners, undefines custom shaders, clears all user-created display objects, and restores modified globals to their original values.

The code is executed with a raw `loadstring()()` call rather than being wrapped in `pcall` or `xpcall`. This is intentional: while `pcall` would prevent crashes from errors in the initial code, it produces a less useful stack trace. By letting the app crash on error, Solar2D's built-in error handler sends a full, descriptive stack trace to the browser, which is far more helpful for the user. It also makes crash behaviour consistent and predictable regardless of where the error occurs.

### Sandboxing

- **Global tracking**: All original `_G` entries are recorded at startup. After each reset, any new globals are removed and any modified originals are restored.
- **Runtime listeners**: `Runtime.addEventListener` is wrapped to track all user-added listeners, ensuring they get cleaned up on reset.
- **Physics state**: `physics.start/pause/stop` are wrapped to track state for automatic cleanup.
- **Custom shaders**: `graphics.defineEffect` is wrapped to track and undefine user-created effects.
- **Disabled APIs**: `disabledAPI.lua` stubs out functions that don't work in the HTML5/GitHub Pages environment (native UI, file I/O, networking, etc.) with warning messages pointing users to the full Solar2D download.

### Display object management

`newDisplay.lua` wraps all `display.new*` functions so that user-created display objects are automatically inserted into a managed group (`groupGlobal`). This lets the app remove everything the user created without touching its own UI elements.

### Built-in assets

The app bundles a set of images (`img/`), sounds (`sfx/`), and fonts (`fnt/`) that users can reference in their code. The in-app asset browser (toggled via sidebar buttons) lets users browse available assets and copy file paths to their clipboard.

## Building

Open `solar2d/src/` as a project in Solar2D Simulator and build for HTML5 with these settings:

- **Application Name**: `playground`
- **Include Standard Resources**: yes
- **Create FB Instant archive**: no

After building, patch the `.bin` archive to remove the blur callback registration (prevents the app from freezing when clicking outside):

```bash
python remove_blur_callback.py bin/
```

## Key Files

| File | Purpose |
|------|---------|
| `main.lua` | Entry point. Sets up UI, sandboxing, and the code execution pipeline. |
| `config.lua` | Display config: 960x640 letterbox at 60 fps. |
| `disabledAPI.lua` | Stubs out APIs unavailable in the Playground environment. |
| `newDisplay.lua` | Wraps `display.new*` to auto-insert objects into the managed group. |
| `createWindow.lua` | Asset browser windows (images, sounds, fonts). |
| `printToDisplay.lua` | In-app console overlay with syntax highlighting. |
| `spyricFontLoader.lua` | Preloads bundled fonts for use in user code. |
| `inputCode.js` | JS bridge: receives code from the parent page via custom events. |
| `versionInfo.js` | Outputs Playground and Solar2D version info to the browser console. |
| `copyToClipboard.js` | JS bridge: copies asset paths to the user's clipboard. |
| `printToBrowser.js` | JS bridge: forwards Lua print output to the browser console. |
