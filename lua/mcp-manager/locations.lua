local M = {}

-- Show location management interface
function M.manage_locations()
  local mcp_manager = require('mcp-manager')
  local locations = mcp_manager.load_locations()
  
  -- Create a new buffer for the location manager
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = 80,
    height = math.min(#locations + 10, 20),
    col = (vim.o.columns - 80) / 2,
    row = (vim.o.lines - math.min(#locations + 10, 20)) / 2,
    style = 'minimal',
    border = 'rounded',
    title = ' MCP Config Locations ',
    title_pos = 'center'
  })
  
  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'mcp-locations')
  
  -- Generate content
  local lines = M.generate_location_display(locations)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  -- Set up keymaps
  M.setup_location_keymaps(buf, win, locations)
  
  -- Make buffer read-only
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
end

-- Generate the display content for locations
function M.generate_location_display(locations)
  local lines = {
    "MCP Configuration Locations",
    "=" .. string.rep("=", 28),
    "",
    "Toggle: <Space>  │  Close: <q>  │  Add: <a>",
    ""
  }
  
  for i, location in ipairs(locations) do
    local status = location.enabled and "✓" or "✗"
    local line = string.format("[%s] %s", status, location.name)
    table.insert(lines, line)
    table.insert(lines, string.format("    Path: %s", location.path))
    table.insert(lines, string.format("    Adapter: %s", location.adapter))
    table.insert(lines, "")
  end
  
  table.insert(lines, "")
  table.insert(lines, "Available Adapters:")
  table.insert(lines, "  • claude_desktop - Adds 'mise x -- ' prefix to npx commands")
  table.insert(lines, "  • amazonq - Adds 'type' field, handles stdio/sse")
  table.insert(lines, "  • standard - No transformations")
  
  return lines
end

-- Set up keymaps for the location manager
function M.setup_location_keymaps(buf, win, locations)
  local function close_window()
    vim.api.nvim_win_close(win, true)
  end
  
  local function toggle_location()
    local line = vim.api.nvim_win_get_cursor(win)[1]
    local location_index = M.get_location_index_from_line(line)
    
    if location_index and locations[location_index] then
      locations[location_index].enabled = not locations[location_index].enabled
      
      -- Save updated locations
      local mcp_manager = require('mcp-manager')
      mcp_manager.save_locations(locations)
      
      -- Refresh display
      local lines = M.generate_location_display(locations)
      vim.api.nvim_buf_set_option(buf, 'modifiable', true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    end
  end
  
  -- Set keymaps
  vim.keymap.set('n', 'q', close_window, { buffer = buf, nowait = true })
  vim.keymap.set('n', '<Esc>', close_window, { buffer = buf, nowait = true })
  vim.keymap.set('n', '<Space>', toggle_location, { buffer = buf, nowait = true })
end

-- Get location index from cursor line
function M.get_location_index_from_line(line)
  -- Lines 6, 9, 12, etc. are the location status lines
  if line >= 6 and (line - 6) % 4 == 0 then
    return ((line - 6) / 4) + 1
  end
  return nil
end

return M