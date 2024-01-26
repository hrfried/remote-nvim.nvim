# 🚀 Remote Nvim

Adds support for [remote development](https://code.visualstudio.com/docs/remote/remote-overview)
and [devcontainers](https://code.visualstudio.com/docs/devcontainers/containers)
to Neovim (just like VSCode).

_**This plugin is still under initial development. So, breaking changes are expected. Any such change would be
communicated through [this GitHub discussion](https://github.com/amitds1997/remote-nvim.nvim/discussions/78).**_

## ✨ Features

| Remote mode                   | Current support                                                               |
| ----------------------------- | ----------------------------------------------------------------------------- |
| SSH (using password)          | ✅                                                                             |
| SSH (using SSH key)           | ✅                                                                             |
| SSH (using `ssh_config` file) | ✅                                                                             |
| Docker image                  | _In progress_ ([#66](https://github.com/amitds1997/remote-nvim.nvim/pull/66)) |
| Docker container              | _In progress_ ([#66](https://github.com/amitds1997/remote-nvim.nvim/pull/66)) |
| Devcontainer                  | _In progress_ ([#66](https://github.com/amitds1997/remote-nvim.nvim/pull/66)) |

[Remote Tunnels](https://code.visualstudio.com/docs/remote/tunnels)
is a Microsoft-specific features and will not be supported. If
you have an alternative though, I would be happy to integrate it into the plugin.

### Planned features

- **Dynamic port forwarding** - I already have a clear path to implementing this,
  but waiting for complete support for devcontainers to be present and then
  integrate this. For tracking, see [#77](https://github.com/amitds1997/remote-nvim.nvim/issues/77).
  For more feature details, see [similar implementation in
  VSCode](https://code.visualstudio.com/docs/devcontainers/containers#_temporarily-forwarding-a-port).

<details>
<summary><b>✨ Other noice features</b></summary>

- Automatically install and launch Neovim
- No changes to your remote environment
- Can copy over and sync your local Neovim configuration to remote
- Saves your past sessions automatically so you can easily reconnect
- Easily cleanup the remote machine once you are done with a single command

</details>

## 📜 Requirements

### OS support

| Support level                     | OS                                                                      |
| --------------------------------- | ----------------------------------------------------------------------- |
| ✅ **Supported**                   | Linux, MacOS                                                            |
| 🚧 **In progress**                 | FreeBSD ([#71](https://github.com/amitds1997/remote-nvim.nvim/pull/71)) |
| 🟡 **Planned but not implemented** | Windows, WSL                                                            |

### Local machine 💻

- OpenSSH client
- Neovim >= 0.9.0 (as `nvim`)
- Binaries: `curl`

### Remote machine ☁️

- OpenSSH-compliant SSH server
- Connectivity to [GitHub.com](https://github.com) (to download Neovim release)
- Binaries: `curl` or `wget`
- `bash` shell must be available

## 📥 Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
   "amitds1997/remote-nvim.nvim",
   version = "*", -- Pin to GitHub releases
   dependencies = {
       "nvim-lua/plenary.nvim", -- For standard functions
       "MunifTanjim/nui.nvim", -- To build the plugin UI
       "nvim-telescope/telescope.nvim", -- For picking b/w different remote methods
   },
   config = true,
}
```

If you use any other plugin manager, ensure that you call `require("remote-nvim").setup()`.

<details>
<summary><b>⚙️ Advanced configuration</b></summary>

Below is the default configuration. Please read the associated comments before changing the value.

```lua
 {
  -- Configuration for SSH connections
  ssh_config = {
    ssh_binary = "ssh", -- Binary to use for running SSH command
    scp_binary = "scp", -- Binary to use for running SSH copy commands
    ssh_config_file_paths = { "$HOME/.ssh/config" }, -- Which files should be considered to contain the ssh host configurations. NOTE: `Include` is respected in the provided files.

    -- These are useful for password-based SSH authentication.
    -- It provides parsing pattern for the plugin to detect that an input is requested.
    -- Each element contains the following attributes:
    -- match - The string to match (plain matching is done)
    -- type - Supports two values "plain"|"secret". Secret means when you provide the value, it should not be stored in the completion history of Neovim.
    -- value - Default value for the prompt
    -- value_type - "static"|"dynamic". For things like password, it would be needed for each new connection that the plugin initiates which could be obtrusive.
    -- So, we save the value (only for current session's interval) to ease the process. If set to "dynamic", we do not save the value even for the session. You have to provide a fresh value each time.
    ssh_prompts = {
      {
        match = "password:",
        type = "secret",
        value_type = "static",
        value = "",
      },
      {
        match = "continue connecting (yes/no/[fingerprint])?",
        type = "plain",
        value_type = "static",
        value = "",
      },
    },
  },

  -- Path to the script that would be copied to the remote and called to ensure that neovim gets installed.
  -- Default path is to the plugin's own ./scripts/neovim_install.sh file.
  neovim_install_script_path = utils.path_join(
    utils.is_windows,
    vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h:h:h"),
    "scripts",
    "neovim_install.sh"
  ),

  -- Modify the UI for the plugin's progress viewer.
  -- type can be "split" or "popup". All options from https://github.com/MunifTanjim/nui.nvim/tree/main/lua/nui/popup and https://github.com/MunifTanjim/nui.nvim/tree/main/lua/nui/split are supported.
  -- Note that some options like "border" are only available for "popup".
  progress_view = {
    type = "popup",
  },

  -- Path to the user's Neovim configuration files. These would be copied to the remote if user chooses to do so.
  neovim_user_config_path = vim.fn.stdpath("config"),

  -- Local client configuration
  local_client_config = {
    -- You can supply your own callback that should be called to create the local client. This is the default implementation.
    -- Two arguments are passed to the callback:
    -- port: Local port at which the remote server is available
    -- workspace_config: Workspace configuration for the host. For all the properties available, see https://github.com/amitds1997/remote-nvim.nvim/blob/main/lua/remote-nvim/providers/provider.lua#L4
    -- A sample implementation using WezTerm tab is at: https://github.com/amitds1997/remote-nvim.nvim/wiki/Configuration-recipes
    callback = function(port, _)
      require("remote-nvim.ui").float_term(("nvim --server localhost:%s --remote-ui"):format(port), function(exit_code)
        if exit_code ~= 0 then
          vim.notify(("Local client failed with exit code %s"):format(exit_code), vim.log.levels.ERROR)
        end
      end)
    end,
  },

  -- Plugin log related configuration [PREFER NOT TO CHANGE THIS]
  log = {
    -- Where is the log file
    filepath = utils.path_join(utils.is_windows, vim.fn.stdpath("state"), ("%s.log"):format(constants.PLUGIN_NAME)),
    -- Level of logging
    level = "info",
    -- At what size, should we truncate the logs
    max_size = 1024 * 1024 * 2, -- 2MB
  },
}
```

</details>

> [!NOTE]
> Run `:checkhealth remote-nvim.nvim` to ensure necesssary binaries are available. If missing,
> parts of the plugin might be broken.