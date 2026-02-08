## Dockyard.nvim

Minimal Neovim companion for peeking at running Docker containers without
leaving the editor.

### Installation (lazy.nvim)

```
{
  "emrearmagan/dockyard.nvim",
  config = function()
    require("dockyard").setup()
  end,
  cmd = "Dockyard",
}
```

### Usage

- `:Dockyard` – opens a vertical panel similar to dadbod/dadbod-ui drawers and
  lists every container returned by `docker ps`. Moving focus away leaves the
  buffer in place; press `q`, `<Esc>`, or `:close` to dismiss it.
- `:DockyardFull` – same listing but opens inside a new tab page.
- `r` inside the panel reloads the container list.

### Requirements / Notes

- Relies on the local Docker CLI (`docker ps`). Only running containers are
  shown at the moment.
- The panel is purely informational for now; future iterations can wire in
  actions (start/stop, logs, exec, etc.).
