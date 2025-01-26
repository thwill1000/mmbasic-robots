# ChangeLog

## Version 1.0.1.mmb4l - 26-Jan-2025

### Added

 * Write contents for `README.md`.
 * New key bindings for PS2 keyboard:
     * `y` - "search object" (to supplement existing `z`).
     * `M` - "toggle music" (lower case `m` is "move object").

### Fixed

 * "Toggle music" action now behaves correctly from the first time it is used; previously its behaviour was reversed.

## Version 1.0 RC 6 sp - 19-Jan-2025

Changes from official version 1.0 RC 6.

### Changed

 - Ensure all variables are declared by using `OPTION EXPLICIT`.
  - Change main menu to behave more like MSX version.
 - Tweak many of the messages.
 - Miscellaneous changes for MMB4L 0.7.0 + Game*Pack support.

### Added

 - SNES controller support.
 - PS2 keyboard support.

### Fixed

 - Typo that meant that you never found any magnets.
 - Clear input buffer after player moves an object so that the player does not also move.