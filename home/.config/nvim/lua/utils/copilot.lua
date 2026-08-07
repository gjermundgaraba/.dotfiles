local M = {}

local function client_and_buffer()
  local client = vim.lsp.get_clients({ name = "copilot" })[1]
  if not client then
    vim.notify("Copilot is not attached yet. Open a normal source file and retry.", vim.log.levels.WARN)
    return
  end

  local bufnr = client.attached_buffers[vim.api.nvim_get_current_buf()] and vim.api.nvim_get_current_buf() or next(client.attached_buffers)
  return client, bufnr
end

function M.sign_in()
  local client, bufnr = client_and_buffer()
  if not client then
    return
  end

  client:request("signIn", vim.empty_dict(), function(err, result)
    if err then
      vim.notify(err.message, vim.log.levels.ERROR)
      return
    end

    if result.status == "AlreadySignedIn" then
      vim.notify("Already signed in to GitHub Copilot as " .. result.user)
      return
    end

    if result.status ~= "PromptUserDeviceFlow" or not result.command then
      vim.notify("GitHub Copilot sign-in did not return a device flow", vim.log.levels.ERROR)
      return
    end

    vim.fn.setreg("+", result.userCode)
    vim.fn.setreg("*", result.userCode)

    local choice = vim.fn.confirm("Copied the GitHub Copilot one-time code to the clipboard.\nOpen the browser to finish signing in?", "&Yes\n&No", 1)
    if choice ~= 1 then
      vim.notify("Enter " .. result.userCode .. " at " .. result.verificationUri)
      return
    end

    client:exec_cmd(result.command, { bufnr = bufnr }, function(cmd_err, cmd_result)
      if cmd_err then
        vim.notify(cmd_err.message, vim.log.levels.ERROR)
        return
      end
      if cmd_result and cmd_result.status == "OK" then
        vim.notify("Signed in to GitHub Copilot as " .. cmd_result.user)
      end
    end)
  end)
end

function M.sign_out()
  local client = client_and_buffer()
  if not client then
    return
  end

  client:request("signOut", vim.empty_dict(), function(err, result)
    if err then
      vim.notify(err.message, vim.log.levels.ERROR)
      return
    end
    if result.status == "NotSignedIn" then
      vim.notify "Signed out of GitHub Copilot"
    end
  end)
end

function M.setup()
  vim.api.nvim_create_user_command("LspCopilotSignIn", M.sign_in, {
    desc = "Sign in to GitHub Copilot",
  })
  vim.api.nvim_create_user_command("LspCopilotSignOut", M.sign_out, {
    desc = "Sign out of GitHub Copilot",
  })
end

return M
