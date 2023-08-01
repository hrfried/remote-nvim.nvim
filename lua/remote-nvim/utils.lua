local utils = {}

utils.PLUGIN_NAME = "remote-nvim.nvim"

function utils.find_binary(binary)
  if type(binary) == "string" and vim.fn.executable(binary) == 1 then
    return binary
  elseif type(binary) == "table" and vim.fn.executable(binary[1]) then
    return vim.deepcopy(binary)
  end
  return nil
end

function utils.merge_tables(t1, t2)
  local merged_table = {}

  for key, value in pairs(t1) do
    merged_table[key] = value
  end

  -- Append values from t2 into t1 only if key not already in t1
  for key, value in pairs(t2) do
    if merged_table[key] == nil then
      merged_table[key] = value
    end
  end

  return merged_table
end

function utils.path_join(...)
  local parts = { ... }
  return table.concat(parts, vim.loop.os_uname().sysname == "Windows" and "\\" or "/")
end

function utils.get_package_root()
  local root_dir
  for dir in vim.fs.parents(debug.getinfo(1).source:sub(2)) do
    if vim.fn.isdirectory(utils.path_join(dir, "lua", "remote-nvim")) == 1 then
      root_dir = dir
    end
  end
  return root_dir
end

function utils.generate_random_string(length)
  local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  math.randomseed(os.time()) -- Seed the random number generator with the current time
  local random_string = ""

  for _ = 1, length do
    local rand_index = math.random(1, #charset)
    random_string = random_string .. string.sub(charset, rand_index, rand_index)
  end

  return random_string
end

function utils.find_free_port()
  local socket = vim.loop.new_tcp()

  socket:bind("127.0.0.1", 0)
  local result = socket.getsockname(socket)
  socket:close()

  if not result then
    print("Failed to find a free port")
    return
  end

  return result["port"]
end

function utils.get_host_identifier(ssh_host, ssh_options)
  local host_config_identifier = ssh_host
  if ssh_options ~= nil then
    local port = ssh_options:match("-p%s*(%d+)")
    if port ~= nil then
      host_config_identifier = host_config_identifier .. ":" .. port
    end
  end
  return host_config_identifier
end

return utils
