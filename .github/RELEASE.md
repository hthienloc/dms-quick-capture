## What's New

### Features

- **History carousel**: Browse saved screenshots in a paginated grid with **Open**, **Copy**, and **Delete** actions.
  <img width="1728" height="972" alt="History carousel" src="https://github.com/user-attachments/assets/e42997ed-eaf6-4175-97cb-c8f07eedc41b" />
  <img width="3960" height="1177" alt="History actions" src="https://github.com/user-attachments/assets/0a1031f2-3dd4-41ab-87d4-ea82464782f7" />

- **Clickable save notifications**: Click a save notification to open the screenshot in your default image viewer or open the containing folder.
  <img width="857" height="325" alt="Save notification" src="https://github.com/user-attachments/assets/70435a85-ed59-4491-b446-1fdb68494f36" />

- **Pen selection indicator**: Selected freehand strokes now display a dashed outline with automatic contrast.

- **15° angle snapping**: Hold <kbd>Shift</kbd> while dragging line, arrow, or highlighter endpoints to snap in 15° increments.

- **Scale editor to screenshot**: New optional setting to resize the editor window to match the captured image dimensions. *(Contributed by @adschem.)*

- **Backdrop blur preview**: Preview now renders at the display's native resolution instead of the editor preview resolution.

### Fixes

- Fixed a race condition that could leave the editor canvas blank after exporting twice.
- Fixed notification timestamps being rendered in italic.
- Changed the default filename format from `Screenshot_` to `Screenshot-`.
