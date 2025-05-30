# MCP Config Manager

A Neovim plugin that provides unified editing and management of MCP (Model Context Protocol) configurations across multiple clients and platforms.

## Overview

This plugin solves the problem of managing MCP server configurations across different clients (Claude Desktop, Amazon Q, etc.) that each have their own format requirements and quirks. Instead of manually maintaining separate config files, you edit a single master configuration that automatically syncs to all registered locations with appropriate transformations.

## Key Features

- **Master Config Editing**: Single source of truth for all MCP server configurations
- **Dynamic Rule Learning**: Import existing configs and automatically extract transformation rules
- **Intelligent Adapters**: Handles platform-specific requirements (mise wrappers, required fields, path conversions)
- **Location Management**: Toggle sync targets on/off as needed
- **Auto-sync**: Configurations sync automatically when the master config is saved

## Commands

```vim
:MCPEdit        " Edit master MCP configuration
:MCPImport      " Import existing config and learn transformation rules
:MCPLocations   " Manage sync locations (toggle enabled/disabled)
:MCPSync        " Manually sync master config to all enabled locations
```

## Workflow

1. **Initial Setup**: Run `:MCPEdit` to create your master configuration
2. **Import Existing Configs**: Use `:MCPImport` to learn from your current configs
3. **Edit Once**: Make changes to the master config
4. **Auto-sync**: Transformations are automatically applied to all enabled locations

## Architecture

### Core Components

- `init.lua` - Main plugin interface and configuration management
- `diff_analyzer.lua` - Semantic analysis of config differences
- `rule_engine.lua` - Rule application and transformation system
- `adapters.lua` - Adapter management (rule-based and legacy)
- `import.lua` - Config import and rule extraction workflow
- `locations.lua` - Location management UI

### Rule System

The plugin uses a dynamic rule system that learns transformation patterns:

- **add_field** - Add required fields (e.g., `type: "stdio"` for Amazon Q)
- **wrap_command** - Command wrapping (e.g., `npx` → `mise x -- npx`)
- **transform_paths** - Path conversions between platforms
- **prepend_args** - Argument modifications

### Configuration Files

- `~/.config/mcp-manager/master.json` - Master configuration
- `~/.config/mcp-manager/locations.json` - Registered sync locations
- `~/.config/mcp-manager/rules/*.json` - Transformation rules per location

## Example

Master config:
```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-filesystem", "~/Documents"]
    }
  }
}
```

Automatically transforms to Claude Desktop format:
```json
{
  "mcpServers": {
    "filesystem": {
      "command": "mise",
      "args": ["x", "--", "npx", "@modelcontextprotocol/server-filesystem", "/Users/delorenj/Documents"]
    }
  }
}
```

And to Amazon Q format:
```json
{
  "mcpServers": {
    "filesystem": {
      "type": "stdio",
      "command": "npx",
      "args": ["@modelcontextprotocol/server-filesystem", "/Users/delorenj/Documents"]
    }
  }
}
```

## Installation

Add the plugin directory to your Neovim configuration. The plugin will automatically set up commands when loaded.

## Development

The plugin is designed to be extensible. New transformation rules can be added to the rule engine, and the diff analyzer can be enhanced to detect additional patterns.

### Testing

Use `:MCPImport` with test configurations to verify rule extraction accuracy. The confirmation dialog shows detected rules before applying them.

### Debugging

Rules are saved as JSON files in `~/.config/mcp-manager/rules/` for inspection and manual editing if needed.