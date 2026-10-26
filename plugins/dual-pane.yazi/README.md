# dual-pane.yazi

Dual-pane view (two tabs side by side) for [Yazi](https://github.com/sxyazi/yazi).
Based on [terrakok/split-tabs.yazi](https://github.com/terrakok/split-tabs.yazi) (MIT, see `LICENSE`),
with a maximize action added and the actions renamed.

## Actions

Run with `plugin dual-pane <action>`:

| Action       | What it does                                                           |
|--------------|------------------------------------------------------------------------|
| `toggle`     | Turn dual-pane mode on or off                                          |
| `activate`   | Turn it on (idempotent, usable from `init.lua`)                        |
| `deactivate` | Turn it off                                                            |
| `switch`     | Move focus to the other pane                                           |
| `copy`       | Copy selected (or hovered) files to the other pane                     |
| `move`       | Move selected (or hovered) files to the other pane                     |
| `preview`    | Show or hide the full-width preview under the panes; falls back to `toggle-pane min-preview` when not in dual-pane mode |
| `maximize`   | Preview fills the whole area; falls back to `toggle-pane max-preview` when not in dual-pane mode |
