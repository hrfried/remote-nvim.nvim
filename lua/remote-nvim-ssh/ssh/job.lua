local remote_nvim_ssh = require("remote-nvim-ssh")

local SSHJob = {}
SSHJob.__index = SSHJob

function SSHJob:new(ssh_options)
  local instance = {
    ssh_binary = remote_nvim_ssh.ssh_binary,
    ssh_prompts = remote_nvim_ssh.ssh_prompts,
    default_remote_cmd = "echo OK",
    remote_cmd = nil,
    exit_code = nil,
    stdout_data = "",
    stderr_data = "",
    ssh_complete_cmd = nil,
    job_id = nil,
    _is_job_complete = false,
    _remote_cmd_output_separator = "===START-OF-REMOTE-NVIM-SSH-OUTPUT===",
    _stdout_lines = {},
    _stderr_lines = {},
    _stdout_last_prompt_index = 1,
    _stderr_last_prompt_index = 1,
  }

  if type(ssh_options) == "table" then
    instance.ssh_options = table.concat(ssh_options, " ")
  else
    instance.ssh_options = ssh_options
  end

  instance.ssh_base_cmd = table.concat({ instance.ssh_binary, instance.ssh_options }, " ")
  instance.default_separator_cmd = "echo '" .. instance._remote_cmd_output_separator .. "'"

  setmetatable(instance, SSHJob)
  return instance
end

function SSHJob:_handle_stdout(data)
  -- Handle partial (incomplete) lines: https://neovim.io/doc/user/job_control.html#job-control
  for _, datum in ipairs(data) do
    -- Replace '\r' - terminals add it and we run the job in a terminal
    local value = datum:gsub("\r", "\n")

    self.stdout_data = self.stdout_data .. value
    table.insert(self._stdout_lines, value)
  end
  local search_field = table.concat({ unpack(self._stdout_lines, self._stdout_last_prompt_index + 1) }, "")

  for _, prompt in ipairs(self.ssh_prompts) do
    if search_field:find(prompt.match) then
      -- We found a match so all strings until now are done for
      self._stdout_last_prompt_index = #self._stdout_lines
      local prompt_label = prompt.input_prompt or ("Enter " .. prompt.match .. " ")

      local prompt_response
      -- TODO: Switch away from vim.fn.inputsecret since it is a blocking call
      if prompt.type == "secret" then
        prompt_response = vim.fn.inputsecret(prompt_label)
      else
        prompt_response = vim.fn.input(prompt_label)
      end

      vim.api.nvim_chan_send(self.job_id, prompt_response .. "\n")
    end
  end
end

function SSHJob:_handle_stderr(data)
  for _, datum in ipairs(data) do
    local value = datum:gsub("\r", "")

    self.stderr_data = self.stderr_data .. value
    table.insert(self._stderr_lines, datum:gsub("\r", ""))
  end
end

function SSHJob:_handle_exit(exit_code)
  self._is_job_complete = true

  self.exit_code = exit_code
  if exit_code ~= 0 then
    vim.notify("Remote command: " .. self.remote_cmd .. " failed.")
  end
end

function SSHJob:_filter_result(data)
  local start_index, end_index = (data or ""):find(self._remote_cmd_output_separator .. "\n", 1, true)
  if start_index then
    return data:sub(end_index + 1):gsub("\n$", ""):gsub("^\n", "")
  end
  return nil
end

function SSHJob:_generate_ssh_command(cmd)
  self.remote_cmd = cmd or self.default_remote_cmd

  local complete_remote_cmd = self.default_separator_cmd .. " && " .. self.remote_cmd
  self.ssh_complete_cmd = table.concat({ self.ssh_base_cmd, complete_remote_cmd }, " ")
  return self.ssh_complete_cmd
end

function SSHJob:run_command(cmd)
  local ssh_cmd = self:_generate_ssh_command(cmd)

  self.job_id = vim.fn.jobstart(ssh_cmd, {
    pty = true, -- Important because SSH commands can be interactive e.g. password authentication
    on_stdout = function(_, data)
      self:_handle_stdout(data)
    end,
    on_stderr = function(_, data)
      self:_handle_stderr(data)
    end,
    on_exit = function(_, exit_code)
      self:_handle_exit(exit_code)
    end
  })

  return self
end

function SSHJob:wait_for_completion(timeout)
  if self._is_job_complete then
    return self.exit_code
  end
  return vim.fn.jobwait({ self.job_id }, timeout or -1)[1]
end

function SSHJob:verify_successful_connection()
  self:run_command("echo 'Test connection'")

  if self:wait_for_completion() == 0 and self:stdout() == "Test connection" then
    return true
  end
  return false
end

function SSHJob:stdout()
  return self:_filter_result(self.stdout_data)
end

function SSHJob:stderr()
  return self:_filter_result(self.stderr_data)
end

function SSHJob:is_successful()
  return (self.exit_code or -1) == 0
end

return SSHJob
