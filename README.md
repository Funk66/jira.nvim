# Simple Jira tools

![image](https://github.com/Funk66/jira.nvim/assets/3842222/7bba1bda-9acb-499f-9755-542145e99996)

## Installation

[LazyVim](https://github.com/LazyVim/LazyVim) example configuration:

```lua
return {
  "Funk66/jira.nvim",
  dependencies = {
    { "jcdickinson/http.nvim", build = "cargo build --workspace --release" },
  },
  config = function()
    require("jira").setup()
  end,
  cond = function()
    return vim.env.JIRA_API_TOKEN ~= nil
  end,
}
```

You can either provide your Jira credentials as environment variables

```sh
export JIRA_DOMAIN=myproject.atlassian.net
export JIRA_USER=godzilla@github.com
export JIRA_API_TOKEN=...
export JIRA_PROJECT_KEY=DEMO
```

or as options to the setup function.

```lua
require("jira").setup({
  domain = "myproject.atlassian.net",
  user = "godzilla@github.com",
  token = "...",
  key = "DEMO",
})
```

## Usage

Place the cursor over a Jira issue id and press:

- `<leader>jv` - View issue in a floating window
- `<leader>jo` - Open issue in a browser
