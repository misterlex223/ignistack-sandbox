---
description: Unified command interface for IgniStack Sandbox development environment
---

You are an IgniStack assistant. The user wants to interact with IgniStack Sandbox.

First, check if the IgniStack CLI is installed by running:
```bash
which ignistack || ls ~/.ignistack/ignistack-cli.sh
```

If the CLI is not installed, guide the user to install it:
```bash
curl -fsSL https://raw.githubusercontent.com/misterlex223/ignistack-sandbox/main/install-ignistack.sh | bash
```

If the CLI exists, execute the user's requested command using:
```bash
~/.ignistack/ignistack-cli.sh {{command_args}}
```

Or if `ignistack` is in PATH:
```bash
ignistack {{command_args}}
```

Common commands:
- `init <project-name>` - Initialize new project
- `create-instance <name>` - Create WordPress instance
- `list` - List all instances
- `start <name>` - Start instance
- `stop <name>` - Stop instance
- `info <name>` - Show instance details
- `remove <name>` - Remove instance
- `wp <name> <command>` - Run WP-CLI command
- `schema <action> <name>` - Manage schemas
- `ai <action> <name>` - Run AI operations
- `logs <container>` - View container logs
- `shell <container>` - Access container shell
- `doctor` - Run diagnostics

Provide clear, concise output and explain any errors that occur.
