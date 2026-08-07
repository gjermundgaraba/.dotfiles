-- Transparent background
local transparent_groups = {
  "Normal",
  "NormalNC",
  "NormalFloat",
  "SignColumn",
  "StatusLine",
  "StatusLineNC",
  "EndOfBuffer",
  "LineNr",
  "CursorLine",
  "CursorLineNr",
}
local function clear_background(group)
  vim.cmd.highlight(group .. " guibg=NONE ctermbg=NONE")
end

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("gg/transparent", { clear = true }),
  desc = "Clear background for transparency",
  callback = function()
    for _, group in ipairs(transparent_groups) do
      clear_background(group)
    end
  end,
})

vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("gg/highlight-yank", { clear = true }),
  desc = "Highlight when yanking (copying) text",
  callback = function()
    vim.highlight.on_yank()
  end,
})

vim.api.nvim_create_autocmd("BufReadPost", {
  group = vim.api.nvim_create_augroup("gg/last_location", { clear = true }),
  desc = "Go to the last location when opening a buffer",
  callback = function(args)
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    local line_count = vim.api.nvim_buf_line_count(args.buf)
    if mark[1] > 0 and mark[1] <= line_count then
      vim.cmd 'normal! g`"zz'
    end
  end,
})

local lsp_document_highlight = vim.api.nvim_create_augroup("gg/lsp_document_highlight", { clear = true })

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("gg/lsp_attach", { clear = true }),
  desc = "Enable builtin LSP features for attached clients",
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client then
      return
    end
    if client:supports_method "textDocument/completion" then
      vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
    end

    if client.name ~= "copilot" and vim.lsp.inline_completion and client:supports_method "textDocument/inlineCompletion" then
      vim.lsp.inline_completion.enable(true, { bufnr = args.buf })
    end

    local bufnr = args.buf

    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end

    local fzf = function(fn)
      return function()
        require("fzf-lua")[fn]()
      end
    end

    if vim.fn.maparg("K", "n", false, true).buffer ~= 1 then
      map("n", "K", vim.lsp.buf.hover, "LSP Hover")
    end
    map("n", "gd", fzf "lsp_definitions", "Go to definition")
    vim.keymap.set("n", "<leader>cdn", function()
      vim.diagnostic.jump { count = 1 }
    end, { buffer = bufnr, desc = "Next diagnostic", nowait = true })
    vim.keymap.set("n", "<leader>cdp", function()
      vim.diagnostic.jump { count = -1 }
    end, { buffer = bufnr, desc = "Previous diagnostic", nowait = true })
    map("n", "gD", fzf "lsp_declarations", "Go to declaration")
    map("n", "gi", fzf "lsp_implementations", "Go to implementation")
    map("n", "gr", fzf "lsp_references", "References")
    map("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
    map({ "n", "v" }, "<leader>ca", fzf "lsp_code_actions", "Code action")
    map("n", "<leader>lh", function()
      local enabled = vim.lsp.inlay_hint.is_enabled { bufnr = bufnr }
      vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
    end, "Toggle inlay hints")

    if client:supports_method "textDocument/documentHighlight" then
      vim.api.nvim_clear_autocmds { group = lsp_document_highlight, buffer = bufnr }
      vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
        group = lsp_document_highlight,
        buffer = bufnr,
        callback = vim.lsp.buf.document_highlight,
      })
      vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        group = lsp_document_highlight,
        buffer = bufnr,
        callback = vim.lsp.buf.clear_references,
      })
    end

    if client:supports_method "textDocument/codeLens" then
      vim.lsp.codelens.enable(true, { bufnr = bufnr })
    end

    if client:supports_method "textDocument/linkedEditingRange" then
      vim.lsp.linked_editing_range.enable(true, { client_id = client.id })
    end
  end,
})

vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("gg/startup_explorer", { clear = true }),
  desc = "Open Neo-tree when starting in a directory",
  once = true,
  callback = function()
    local dir = require("utils.startup").directory()
    if not dir then
      return
    end

    vim.schedule(function()
      require("neo-tree.command").execute {
        action = "focus",
        source = "filesystem",
        position = "left",
        dir = dir,
      }
    end)
  end,
})
