# MCP Config Manager

> Unified MCP configuration management for Neovim

A Neovim plugin that intelligently manages MCP (Model Context Protocol) server configurations across multiple clients. Edit once in a master config, sync everywhere with automatic format transformations.

## ✨ Features

- 🎯 **Single Source of Truth** - One master config for all MCP clients
- 🧠 **Smart Rule Learning** - Automatically discovers transformation patterns
- 🔄 **Auto-sync** - Changes propagate instantly to all enabled locations
- 🎛️ **Flexible Adapters** - Handles client-specific requirements seamlessly
- 📍 **Location Management** - Toggle sync targets on demand

## 🚀 Quick Start

1. **Install the plugin** (using your preferred method)
2. **Create master config**: `:MCPEdit`
3. **Import existing configs**: `:MCPImport`
4. **Manage locations**: `:MCPLocations`

That's it! Your configs will stay in sync automatically.

## 📦 Installation

### lazy.nvim
```lua
{
  "delorenj/mcp-config-manager",
  config = function()
    require("mcp-manager").setup()
  end,
}
```

### packer.nvim
```lua
use {
  "delorenj/mcp-config-manager",
  config = function()
    require("mcp-manager").setup()
  end,
}
```

### vim-plug
```vim
Plug 'delorenj/mcp-config-manager'
```

## 🎮 Commands

| Command | Description |
|---------|-------------|
| `:MCPEdit` | Edit master MCP configuration |
| `:MCPImport` | Import existing config and learn rules |
| `:MCPLocations` | Manage sync locations |
| `:MCPSync` | Manually sync all configs |

## 🔧 How It Works

### The Problem
Different MCP clients have different configuration requirements:

- **Claude Desktop** needs `mise x -- npx` instead of `npx`
- **Amazon Q** requires a `type` field for each server
- **Path differences** between macOS (`/Users/`) and Linux (`/home/`)

### The Solution
1. **Import** your existing configs with `:MCPImport`
2. **Analyze** differences automatically to extract transformation rules
3. **Edit** the master config with `:MCPEdit`
4. **Sync** happens automatically on save

### Example Transformation

**Master Config:**
```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["@mcp/server-filesystem", "~/Documents"]
    }
  }
}
```

**→ Claude Desktop:**
```json
{
  "mcpServers": {
    "filesystem": {
      "command": "mise",
      "args": ["x", "--", "npx", "@mcp/server-filesystem", "/Users/delorenj/Documents"]
    }
  }
}
```

**→ Amazon Q:**
```json
{
  "mcpServers": {
    "filesystem": {
      "type": "stdio",
      "command": "npx", 
      "args": ["@mcp/server-filesystem", "/Users/delorenj/Documents"]
    }
  }
}
```

## 🧪 Rule Learning

The plugin learns transformation rules by analyzing differences:

```
:MCPImport
Enter config path: ~/.aws/amazonq/mcp.json
Enter location name: Amazon Q

Rules detected:
• Add required type field
• Expand ~ to /Users/delorenj

[y] Accept  [e] Edit  [n] Cancel  [s] Skip rules
```

## 📂 File Structure

```
~/.config/mcp-manager/
├── master.json           # Master configuration
├── locations.json        # Registered sync locations
└── rules/
    ├── amazon_q.json     # Rules for Amazon Q
    └── claude_desktop.json # Rules for Claude Desktop
```

## ⚙️ Configuration

The plugin works out of the box, but you can customize paths:

```lua
require("mcp-manager").setup({
  master_config = "~/.config/mcp-manager/master.json",
  locations_config = "~/.config/mcp-manager/locations.json"
})
```

## 🎯 Use Cases

- **Multi-platform Development** - Sync configs between macOS and Linux
- **Multiple MCP Clients** - Use Claude Desktop, Amazon Q, and others
- **Team Collaboration** - Share standardized MCP setups
- **Configuration Evolution** - Easily update server configurations

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

Built for the MCP ecosystem and the Neovim community.