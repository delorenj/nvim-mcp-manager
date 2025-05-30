local M = {}

-- Apply a set of rules to transform a config
function M.apply_rules(config, rules)
  local result = vim.deepcopy(config)
  
  for _, rule in ipairs(rules) do
    result = M.apply_single_rule(result, rule)
  end
  
  return result
end

-- Apply a single transformation rule
function M.apply_single_rule(config, rule)
  if rule.type == "add_field" then
    return M.apply_add_field_rule(config, rule)
  elseif rule.type == "wrap_command" then
    return M.apply_wrap_command_rule(config, rule)
  elseif rule.type == "replace_command" then
    return M.apply_replace_command_rule(config, rule)
  elseif rule.type == "prepend_args" then
    return M.apply_prepend_args_rule(config, rule)
  elseif rule.type == "transform_paths" then
    return M.apply_transform_paths_rule(config, rule)
  end
  
  return config
end

-- Add field to all servers
function M.apply_add_field_rule(config, rule)
  local result = vim.deepcopy(config)
  
  if result.mcpServers then
    for server_name, server_config in pairs(result.mcpServers) do
      if rule.condition == "always" or M.evaluate_condition(server_config, rule.condition) then
        server_config[rule.field] = rule.value
      end
    end
  end
  
  return result
end

-- Wrap commands with a wrapper
function M.apply_wrap_command_rule(config, rule)
  local result = vim.deepcopy(config)
  
  if result.mcpServers then
    for server_name, server_config in pairs(result.mcpServers) do
      if server_config.command then
        local original_command = server_config.command
        local original_args = server_config.args or {}
        
        server_config.command = rule.wrapper
        server_config.args = vim.list_extend(vim.deepcopy(rule.pattern), {original_command})
        server_config.args = vim.list_extend(server_config.args, original_args)
      end
    end
  end
  
  return result
end

-- Replace commands
function M.apply_replace_command_rule(config, rule)
  local result = vim.deepcopy(config)
  
  if result.mcpServers then
    for server_name, server_config in pairs(result.mcpServers) do
      if server_config.command == rule.from then
        server_config.command = rule.to
      end
    end
  end
  
  return result
end

-- Prepend arguments
function M.apply_prepend_args_rule(config, rule)
  local result = vim.deepcopy(config)
  
  if result.mcpServers then
    for server_name, server_config in pairs(result.mcpServers) do
      local original_args = server_config.args or {}
      server_config.args = vim.list_extend(vim.deepcopy(rule.prefix), original_args)
    end
  end
  
  return result
end

-- Transform paths throughout the config
function M.apply_transform_paths_rule(config, rule)
  local result = vim.deepcopy(config)
  
  if result.mcpServers then
    for server_name, server_config in pairs(result.mcpServers) do
      -- Transform command paths
      if server_config.command then
        server_config.command = M.transform_path_string(server_config.command, rule)
      end
      
      -- Transform arg paths
      if server_config.args then
        for i, arg in ipairs(server_config.args) do
          server_config.args[i] = M.transform_path_string(arg, rule)
        end
      end
      
      -- Transform env var paths
      if server_config.env then
        for key, value in pairs(server_config.env) do
          server_config.env[key] = M.transform_path_string(value, rule)
        end
      end
    end
  end
  
  return result
end

-- Transform a single path string
function M.transform_path_string(str, rule)
  if type(str) ~= "string" then return str end
  
  if rule.pattern == "home_directory_conversion" then
    return str:gsub(vim.pesc(rule.from_pattern), rule.to_pattern)
  elseif rule.pattern == "tilde_expansion" then
    return str:gsub("^~", rule.to_pattern)
  else
    return str:gsub(vim.pesc(rule.from_pattern), rule.to_pattern)
  end
end

-- Evaluate conditions for rule application
function M.evaluate_condition(server_config, condition)
  if condition == "always" then
    return true
  elseif condition == "has_command" then
    return server_config.command ~= nil
  elseif condition == "is_npm_package" then
    return server_config.command == "npx" or (server_config.args and server_config.args[1] and server_config.args[1]:match("^[a-zA-Z]"))
  end
  
  return false
end

-- Save rules to file
function M.save_rules(location_name, rules)
  local rules_dir = vim.fn.expand("~/.config/mcp-manager/rules")
  vim.fn.mkdir(rules_dir, "p")
  
  local rules_file = string.format("%s/%s.json", rules_dir, location_name:gsub("%s+", "_"):lower())
  local json_str = vim.fn.json_encode(rules)
  vim.fn.writefile(vim.split(json_str, '\n'), rules_file)
  
  return rules_file
end

-- Load rules from file
function M.load_rules(location_name)
  local rules_file = string.format("~/.config/mcp-manager/rules/%s.json", 
    location_name:gsub("%s+", "_"):lower())
  local expanded_path = vim.fn.expand(rules_file)
  
  if vim.fn.filereadable(expanded_path) == 1 then
    local content = vim.fn.readfile(expanded_path)
    return vim.fn.json_decode(table.concat(content, '\n'))
  end
  
  return {}
end

-- Get human-readable description of rules
function M.describe_rules(rules)
  local descriptions = {}
  
  for _, rule in ipairs(rules) do
    if rule.description then
      table.insert(descriptions, "• " .. rule.description)
    else
      table.insert(descriptions, "• " .. rule.type .. " rule")
    end
  end
  
  return descriptions
end

return M