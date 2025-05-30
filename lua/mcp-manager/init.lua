local M = {}
local adapters = require('mcp-manager.adapters')
local locations_ui = require('mcp-manager.locations')
local import_ui = require('mcp-manager.import')

-- Configuration
M.config = {
  master_config = "~/.config/mcp-manager/master.json",
  locations_config = "~/.config/mcp-manager/locations.json"
}

-- Load registered locations
function M.load_locations()
  local locations_file = vim.fn.expand(M.config.locations_config)
  if vim.fn.filereadable(locations_file) == 1 then
    local content = vim.fn.readfile(locations_file)
    return vim.fn.json_decode(table.concat(content, '\n'))
  end
  
  -- Default locations if file doesn't exist
  return {
    {
      name = "Claude Desktop",
      path = "~/Library/Application Support/Claude/claude_desktop_config.json",
      adapter = "claude_desktop",
      enabled = true
    },
    {
      name = "Amazon Q",
      path = "~/.aws/amazonq/mcp.json", 
      adapter = "amazonq",
      enabled = true
    }
  }
end

-- Save locations configuration
function M.save_locations(locations)
  local locations_file = vim.fn.expand(M.config.locations_config)
  local dir = vim.fn.fnamemodify(locations_file, ":h")
  vim.fn.mkdir(dir, "p")
  
  local json_str = vim.fn.json_encode(locations)
  vim.fn.writefile(vim.split(json_str, '\n'), locations_file)
end

-- Open master config for editing
function M.edit_master()
  local master_file = vim.fn.expand(M.config.master_config)
  local dir = vim.fn.fnamemodify(master_file, ":h")
  vim.fn.mkdir(dir, "p")
  
  -- Create default master config if it doesn't exist
  if vim.fn.filereadable(master_file) == 0 then
    local default_config = {
      mcpServers = {}
    }
    local json_str = vim.fn.json_encode(default_config)
    vim.fn.writefile(vim.split(json_str, '\n'), master_file)
  end
  
  vim.cmd("edit " .. master_file)
  
  -- Set up auto-sync on save
  local group = vim.api.nvim_create_augroup("MCPManagerSync", { clear = true })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = master_file,
    callback = function()
      M.sync_configs()
    end
  })
end

-- Sync master config to all enabled locations
function M.sync_configs()
  local master_file = vim.fn.expand(M.config.master_config)
  if vim.fn.filereadable(master_file) == 0 then
    vim.notify("Master config not found", vim.log.levels.ERROR)
    return
  end
  
  local master_content = vim.fn.readfile(master_file)
  local master_config = vim.fn.json_decode(table.concat(master_content, '\n'))
  
  local locations = M.load_locations()
  local synced_count = 0
  
  for _, location in ipairs(locations) do
    if location.enabled then
      local success = M.apply_adapter(master_config, location)
      if success then
        synced_count = synced_count + 1
      end
    end
  end
  
  vim.notify(string.format("Synced to %d locations", synced_count), vim.log.levels.INFO)
end

-- Manage locations interface
function M.manage_locations()
  locations_ui.manage_locations()
end

-- Setup user commands
function M.setup()
  vim.api.nvim_create_user_command('MCPEdit', function()
    M.edit_master()
  end, { desc = "Edit master MCP configuration" })
  
  vim.api.nvim_create_user_command('MCPLocations', function()
    M.manage_locations()
  end, { desc = "Manage MCP config locations" })
  
  vim.api.nvim_create_user_command('MCPSync', function()
    M.sync_configs()
  end, { desc = "Sync master config to all enabled locations" })
  
  vim.api.nvim_create_user_command('MCPImport', function()
    import_ui.prompt_import()
  end, { desc = "Import new MCP config file and learn its rules" })
end

-- Apply adapter transformations and save to target location
function M.apply_adapter(master_config, location)
  local adapted_config = vim.deepcopy(master_config)
  
  -- Apply adapter transformations
  adapted_config = adapters.apply_adapter(adapted_config, location.adapter)
  
  -- Save to target location
  local target_path = vim.fn.expand(location.path)
  local target_dir = vim.fn.fnamemodify(target_path, ":h")
  vim.fn.mkdir(target_dir, "p")
  
  local json_str = vim.fn.json_encode(adapted_config)
  local lines = vim.split(json_str, '\n')
  
  local success, err = pcall(vim.fn.writefile, lines, target_path)
  if not success then
    vim.notify(string.format("Failed to write %s: %s", location.name, err), vim.log.levels.ERROR)
    return false
  end
  
  return true
end

return M