local H = require("tests.helpers")
local terminal = require("fzf-lua-image.terminal")
local config = require("fzf-lua-image.config")

return {
  { "detects Kitty and Ghostty from the environment", function()
    config.setup({ terminal = {} })
    vim.env.TERM = "xterm-kitty"
    H.eq(true, terminal.env().supported)
    H.eq(true, terminal.env().placeholders)
    vim.env.TERM = "xterm-256color"
    vim.env.TERM_PROGRAM = "ghostty"
    H.eq(true, terminal.env().supported)
  end },
  { "uses cursor placements for WezTerm", function()
    config.setup({ terminal = {} })
    vim.env.TERM_PROGRAM = "WezTerm"
    H.eq(true, terminal.env().supported)
    H.eq(false, terminal.env().placeholders)
  end },
  { "detects SSH and rejects Zellij", function()
    config.setup({ terminal = {} })
    vim.env.TERM_PROGRAM = "ghostty"
    vim.env.SSH_CONNECTION = "client 123 server 22"
    H.eq(true, terminal.env().remote)
    vim.env.ZELLIJ = "0"
    H.eq(false, terminal.env().supported)
  end },
  { "encodes quiet graphics requests without modifying the caller", function()
    local opts = { a = "t", i = 31, data = "aGVsbG8=" }
    terminal.request(opts)
    H.eq(nil, opts.q)
    local request = H.requests[1]
    assert(request:find("\27_G", 1, true) == 1)
    assert(request:find("q=2", 1, true))
    assert(request:find(";aGVsbG8=\27\\", 1, true))
  end },
  { "escapes graphics requests for tmux passthrough", function()
    vim.env.TMUX = "test"
    terminal.request({ a = "d", i = 31 })
    assert(H.requests[1]:find("\27Ptmux;\27\27_G", 1, true) == 1)
    assert(H.requests[1]:sub(-4) == "\27\\\27\\" or H.requests[1]:sub(-5) == "\27\27\\\27\\")
  end },
  { "uses positive cell dimensions when terminal pixel sizes are unavailable", function()
    config.setup({ terminal = {} })
    local size = terminal.size()
    assert(size.cell_width > 0 and size.cell_height > 0)
    config.options.terminal.cell_width = 10
    config.options.terminal.cell_height = 20
    H.eq({ cell_width = 10, cell_height = 20 }, terminal.size())
  end },
}
