local M = {}
local rule_engine = require('mcp-manager.rule_engine')

-- Apply adapter based on type
function M.apply_adapter(config, adapter_type)
  if adapter_type == "standard" then
    return config
  elseif adapter_type:match("^rule_based:") then
    local location_name = adapter_type:gsub("^rule_based:", "")
    return M.apply_rule_based_adapter(config, location_name)
  else
    -- Legacy hardcoded adapters (kept for backward compatibility)
    return M.apply_legacy_adapter(config, adapter_type)
  end
end

-- Apply rule-based adapter
function M.apply_rule_based_adapter(config, location_name)
  local rules = rule_engine.load_rules(location_name)
  if #rules == 0 then
    vim.notify("No rules found for " .. location_name .. ", using standard adapter", vim.log.levels.WARN)
    return config
  end
  
  return rule_engine.apply_rules(config, rules)
end

-- Legacy adapters (for backward compatibility)
function M.apply_legacy_adapter(config, adapter_type)
  if adapter_type == "claude_desktop" then
    return M.claude_desktop_legacy(config)
  elseif adapter_type == "amazonq" then
    return M.amazonq_legacy(config)
  end
  
  return config
end

-- Legacy Claude Desktop adapter
function M.claude_desktop_legacy(config)
  local rules = {
    {
      type = "wrap_command",
      wrapper = "mise",
      pattern = {"x", "--"},
      description = "Wrap command with mise x --"
    },
    {
      type = "transform_paths",
      from_pattern = "~",
      to_pattern = "/Users/delorenj",
      pattern = "tilde_expansion",
      description = "Expand ~ to /Users/delorenj"
    }
  }
  
  return rule_engine.apply_rules(config, rules)
end

-- Legacy Amazon Q adapter
function M.amazonq_legacy(config)
  local rules = {
    {
      type = "add_field",
      field = "type",
      value = "stdio",
      condition = "always",
      description = "Add required type field"
    },
    {
      type = "transform_paths",
      from_pattern = "~",
      to_pattern = "/Users/delorenj",
      pattern = "tilde_expansion",
      description = "Expand ~ to /Users/delorenj"
    }
  }
  
  return rule_engine.apply_rules(config, rules)
end

return M