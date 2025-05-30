local M = {}

-- Analyze semantic differences between two MCP configs
function M.analyze_configs(master_config, target_config)
  local rules = {}
  
  -- Compare server configurations
  if master_config.mcpServers and target_config.mcpServers then
    for server_name, master_server in pairs(master_config.mcpServers) do
      local target_server = target_config.mcpServers[server_name]
      if target_server then
        local server_rules = M.compare_server_configs(master_server, target_server)
        for _, rule in ipairs(server_rules) do
          table.insert(rules, rule)
        end
      end
    end
  end
  
  return M.deduplicate_rules(rules)
end

-- Compare individual server configurations
function M.compare_server_configs(master, target)
  local rules = {}
  
  -- Command transformations
  if master.command ~= target.command then
    local command_rule = M.analyze_command_change(master.command, target.command, master.args, target.args)
    if command_rule then
      table.insert(rules, command_rule)
    end
  end
  
  -- Args transformations
  if not M.arrays_equal(master.args, target.args) then
    local args_rule = M.analyze_args_change(master.args, target.args)
    if args_rule then
      table.insert(rules, args_rule)
    end
  end
  
  -- Field additions/removals
  for key, value in pairs(target) do
    if master[key] == nil then
      table.insert(rules, {
        type = "add_field",
        field = key,
        value = value,
        condition = "always"
      })
    end
  end
  
  -- Path transformations
  local path_rules = M.analyze_path_changes(master, target)
  for _, rule in ipairs(path_rules) do
    table.insert(rules, rule)
  end
  
  return rules
end

-- Analyze command changes
function M.analyze_command_change(master_cmd, target_cmd, master_args, target_args)
  -- Detect mise wrapper pattern
  if target_cmd == "mise" and target_args and target_args[1] == "x" and target_args[2] == "--" then
    local wrapped_cmd = target_args[3]
    if wrapped_cmd == master_cmd then
      return {
        type = "wrap_command",
        wrapper = "mise",
        pattern = {"x", "--"},
        description = "Wrap command with mise x --"
      }
    end
  end
  
  -- Detect other command transformations
  if master_cmd and target_cmd then
    return {
      type = "replace_command",
      from = master_cmd,
      to = target_cmd,
      description = string.format("Replace '%s' with '%s'", master_cmd, target_cmd)
    }
  end
  
  return nil
end

-- Analyze args changes
function M.analyze_args_change(master_args, target_args)
  master_args = master_args or {}
  target_args = target_args or {}
  
  -- Check for prefix additions
  if #target_args > #master_args then
    local prefix = {}
    local prefix_length = #target_args - #master_args
    
    for i = 1, prefix_length do
      table.insert(prefix, target_args[i])
    end
    
    -- Check if remaining args match
    local remaining_match = true
    for i = 1, #master_args do
      if master_args[i] ~= target_args[i + prefix_length] then
        remaining_match = false
        break
      end
    end
    
    if remaining_match then
      return {
        type = "prepend_args",
        prefix = prefix,
        description = "Prepend args: " .. table.concat(prefix, " ")
      }
    end
  end
  
  return nil
end

-- Analyze path changes across all fields
function M.analyze_path_changes(master, target)
  local rules = {}
  local path_transformations = {}
  
  -- Check all string fields for path patterns
  for key, master_value in pairs(master) do
    local target_value = target[key]
    if type(master_value) == "string" and type(target_value) == "string" then
      local path_rule = M.detect_path_transformation(master_value, target_value)
      if path_rule then
        path_transformations[path_rule.pattern] = path_rule
      end
    end
  end
  
  -- Convert unique transformations to rules
  for _, transformation in pairs(path_transformations) do
    table.insert(rules, {
      type = "transform_paths",
      from_pattern = transformation.from,
      to_pattern = transformation.to,
      description = transformation.description
    })
  end
  
  return rules
end

-- Detect path transformation patterns
function M.detect_path_transformation(master_path, target_path)
  -- Home directory changes
  if master_path:match("^/home/[^/]+") and target_path:match("^/Users/[^/]+") then
    local master_user = master_path:match("^/home/([^/]+)")
    local target_user = target_path:match("^/Users/([^/]+)")
    local master_suffix = master_path:gsub("^/home/[^/]+", "")
    local target_suffix = target_path:gsub("^/Users/[^/]+", "")
    
    if master_suffix == target_suffix then
      return {
        from = "/home/" .. master_user,
        to = "/Users/" .. target_user,
        pattern = "home_directory_conversion",
        description = string.format("Convert /home/%s to /Users/%s", master_user, target_user)
      }
    end
  end
  
  -- Tilde expansion
  if master_path:match("^~") and target_path:match("^/") then
    local expanded_part = target_path:match("^(/[^/]+/[^/]+)")
    local master_suffix = master_path:gsub("^~", "")
    local target_suffix = target_path:gsub("^" .. vim.pesc(expanded_part), "")
    
    if master_suffix == target_suffix then
      return {
        from = "~",
        to = expanded_part,
        pattern = "tilde_expansion",
        description = "Expand ~ to " .. expanded_part
      }
    end
  end
  
  return nil
end

-- Remove duplicate rules
function M.deduplicate_rules(rules)
  local seen = {}
  local unique_rules = {}
  
  for _, rule in ipairs(rules) do
    local key = rule.type .. ":" .. (rule.field or "") .. ":" .. (rule.pattern or "")
    if not seen[key] then
      seen[key] = true
      table.insert(unique_rules, rule)
    end
  end
  
  return unique_rules
end

-- Helper function to compare arrays
function M.arrays_equal(a, b)
  a = a or {}
  b = b or {}
  
  if #a ~= #b then return false end
  
  for i = 1, #a do
    if a[i] ~= b[i] then return false end
  end
  
  return true
end

return M