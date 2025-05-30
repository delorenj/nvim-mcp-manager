local M = {}
local diff_analyzer = require('mcp-manager.diff_analyzer')
local rule_engine = require('mcp-manager.rule_engine')

-- Import a new config file and learn its transformation rules
function M.import_config(file_path, location_name)
  local expanded_path = vim.fn.expand(file_path)
  
  if vim.fn.filereadable(expanded_path) == 0 then
    vim.notify("File not found: " .. file_path, vim.log.levels.ERROR)
    return false
  end
  
  -- Read the target config
  local content = vim.fn.readfile(expanded_path)
  local target_config = vim.fn.json_decode(table.concat(content, '\n'))
  
  -- Get the current master config
  local mcp_manager = require('mcp-manager')
  local master_path = vim.fn.expand(mcp_manager.config.master_config)
  
  if vim.fn.filereadable(master_path) == 0 then
    vim.notify("Master config not found. Create one first with :MCPEdit", vim.log.levels.ERROR)
    return false
  end
  
  local master_content = vim.fn.readfile(master_path)
  local master_config = vim.fn.json_decode(table.concat(master_content, '\n'))
  
  -- Analyze differences and extract rules
  local rules = diff_analyzer.analyze_configs(master_config, target_config)
  
  if #rules == 0 then
    vim.notify("No transformation rules detected - configs appear identical", vim.log.levels.WARN)
    return M.add_location_without_rules(file_path, location_name)
  end
  
  -- Show rules to user for confirmation
  return M.confirm_and_save_rules(file_path, location_name, rules)
end

-- Show detected rules and ask for confirmation
function M.confirm_and_save_rules(file_path, location_name, rules)
  local rule_descriptions = rule_engine.describe_rules(rules)
  
  -- Create confirmation buffer
  local buf = vim.api.nvim_create_buf(false, true)
  local width = 80
  local height = math.min(#rule_descriptions + 15, 25)
  
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = 'minimal',
    border = 'rounded',
    title = ' Import MCP Config ',
    title_pos = 'center'
  })
  
  -- Generate content
  local lines = {
    "Detected transformation rules for: " .. location_name,
    "=" .. string.rep("=", #("Detected transformation rules for: " .. location_name)),
    "",
    "File: " .. file_path,
    "",
    "Rules detected:"
  }
  
  for _, desc in ipairs(rule_descriptions) do
    table.insert(lines, desc)
  end
  
  table.insert(lines, "")
  table.insert(lines, "Actions:")
  table.insert(lines, "  y - Accept and save rules")
  table.insert(lines, "  e - Edit rules manually")
  table.insert(lines, "  n - Cancel import")
  table.insert(lines, "  s - Skip rules (add location without transformation)")
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  
  -- Set up keymaps
  local function close_and_accept()
    vim.api.nvim_win_close(win, true)
    M.finalize_import(file_path, location_name, rules)
  end
  
  local function close_and_cancel()
    vim.api.nvim_win_close(win, true)
    vim.notify("Import cancelled", vim.log.levels.INFO)
  end
  
  local function close_and_skip_rules()
    vim.api.nvim_win_close(win, true)
    M.add_location_without_rules(file_path, location_name)
  end
  
  local function edit_rules()
    vim.api.nvim_win_close(win, true)
    M.edit_rules_interactively(file_path, location_name, rules)
  end
  
  vim.keymap.set('n', 'y', close_and_accept, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'n', close_and_cancel, { buffer = buf, nowait = true })
  vim.keymap.set('n', 's', close_and_skip_rules, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'e', edit_rules, { buffer = buf, nowait = true })
  vim.keymap.set('n', '<Esc>', close_and_cancel, { buffer = buf, nowait = true })
  
  return true
end

-- Finalize the import by saving rules and adding location
function M.finalize_import(file_path, location_name, rules)
  -- Save the rules
  local rules_file = rule_engine.save_rules(location_name, rules)
  
  -- Add the location
  local mcp_manager = require('mcp-manager')
  local locations = mcp_manager.load_locations()
  
  table.insert(locations, {
    name = location_name,
    path = file_path,
    adapter = "rule_based:" .. location_name,
    enabled = true
  })
  
  mcp_manager.save_locations(locations)
  
  vim.notify(string.format("Successfully imported %s with %d rules", location_name, #rules), vim.log.levels.INFO)
  vim.notify("Rules saved to: " .. rules_file, vim.log.levels.INFO)
end

-- Add location without transformation rules
function M.add_location_without_rules(file_path, location_name)
  local mcp_manager = require('mcp-manager')
  local locations = mcp_manager.load_locations()
  
  table.insert(locations, {
    name = location_name,
    path = file_path,
    adapter = "standard",
    enabled = true
  })
  
  mcp_manager.save_locations(locations)
  vim.notify("Added location without transformation rules", vim.log.levels.INFO)
  return true
end

-- Interactive rule editing (simplified for now)
function M.edit_rules_interactively(file_path, location_name, rules)
  -- For now, just open the rules in JSON format for manual editing
  local temp_file = vim.fn.tempname() .. ".json"
  local json_str = vim.fn.json_encode(rules)
  vim.fn.writefile(vim.split(json_str, '\n'), temp_file)
  
  vim.cmd("edit " .. temp_file)
  
  -- Set up autocmd to process edited rules
  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = temp_file,
    once = true,
    callback = function()
      local edited_content = vim.fn.readfile(temp_file)
      local edited_rules = vim.fn.json_decode(table.concat(edited_content, '\n'))
      M.finalize_import(file_path, location_name, edited_rules)
      vim.fn.delete(temp_file)
    end
  })
end

-- Prompt for import details
function M.prompt_import()
  vim.ui.input({ prompt = "Config file path: " }, function(file_path)
    if not file_path or file_path == "" then return end
    
    vim.ui.input({ prompt = "Location name: " }, function(location_name)
      if not location_name or location_name == "" then return end
      
      M.import_config(file_path, location_name)
    end)
  end)
end

return M