# IgniStack Integration Guide

## Overview

This guide explains how to integrate IgniStack Sandbox into any project. IgniStack provides a complete development environment with WordPress (SQLite), Firebase, and AI capabilities.

## What is IgniStack?

IgniStack Sandbox is a Docker-based development environment that provides:

- **WordPress with SQLite**: No MySQL needed, portable and persistent
- **Firebase Integration**: Real-time sync and backend services
- **AI-Powered Development**: Claude/OpenAI integration for content generation
- **Schema-Driven Development**: Define content structures in YAML/JSON
- **Multi-Instance Support**: Run multiple isolated WordPress installations
- **Zero-Config Setup**: Pull and run from GitHub Container Registry

## Integration Methods

### Method 1: Quick Install (Recommended for Most Projects)

Run the installation script:

```bash
curl -fsSL https://raw.githubusercontent.com/misterlex223/ignistack-sandbox/main/install-ignistack.sh | bash
```

This will:
1. Install the `ignistack` CLI tool
2. Install the Claude Code Skill (if applicable)
3. Set up shell completion
4. Configure the instances directory

### Method 2: Manual Installation

1. **Download the CLI**:
   ```bash
   mkdir -p ~/.ignistack
   curl -fsSL https://raw.githubusercontent.com/misterlex223/ignistack-sandbox/main/ignistack-cli.sh \
     -o ~/.ignistack/ignistack-cli.sh
   chmod +x ~/.ignistack/ignistack-cli.sh
   ```

2. **Add to PATH** (add to `~/.bashrc` or `~/.zshrc`):
   ```bash
   export PATH="$PATH:$HOME/.ignistack"
   ```

3. **For Claude Code users**, install the Skill:
   ```bash
   mkdir -p ~/.claude/skills/ignistack
   curl -fsSL https://raw.githubusercontent.com/misterlex223/ignistack-sandbox/main/.claude-skills/ignistack/skill.md \
       -o ~/.claude/skills/ignistack/skill.md
   ```

### Method 3: Direct Docker Usage

For CI/CD or automation:

```bash
docker run -d \
  --name my-ignistack \
  -p 8080:80 \
  -p 9681:9681 \
  -e WP_INSTANCE_NAME=my-project \
  -v ~/.ignistack-instances/my-project:/home/flexy/wordpress-persistent \
  ghcr.io/misterlex223/ignistack-sandbox:latest
```

## Project Integration Patterns

### Pattern 1: Standalone WordPress Backend

Use IgniStack as a headless CMS for your frontend application:

```bash
# Initialize IgniStack for your project
ignistack init my-cms --port 8080

# Your frontend app can now:
# - Fetch content from WordPress REST API
# - Use Firebase for real-time data
# - Leverage AI for content generation
```

### Pattern 2: Multi-Environment Setup

Maintain separate environments for development, testing, and staging:

```bash
# Development
ignistack create-instance dev --port 8080
ignistack start dev

# Testing
ignistack create-instance test --port 8081
ignistack start test

# Staging
ignistack create-instance staging --port 8082
ignistack start staging
```

### Pattern 3: Existing Project Integration

Add IgniStack to an existing project:

```bash
cd /path/to/your-project

# Initialize project configuration
ignistack project init

# This creates .ignistack/config with your project settings
# Now you can run commands without specifying the project name!

# Create and start the instance
ignistack create-instance $(basename $(pwd)) --port 8080
ignistack start  # Uses project name from config

# Run WP-CLI commands without specifying instance
ignistack wp plugin list
ignistack wp post list
```

### Pattern 4: Project Configuration with Custom Settings

For advanced configuration, create `.ignistack/config` manually or use the CLI with options:

```bash
# Initialize with custom ports
ignistack project init my-app \
  --port 8080 \
  --firebase-port 5000 \
  --webtty-port 9681
```

The `.ignistack/config` file stores:
- `project_name`: Instance identifier
- `port`: WordPress port
- `firebase_port`, `firebase_ui_port`: Firebase emulator ports
- `webtty_port`: WebTTY terminal port
- `cospec_port`: CoSpec AI editor port
- `instance_dir`: Custom instance directory (optional)
- `image`: Custom Docker image (optional)

With this configuration, commands become simpler:
```bash
# Before: ignistack start my-project
# After:  ignistack start

# Before: ignistack wp my-project plugin list
# After:  ignistack wp plugin list
```

## Common Integration Scenarios

### Scenario 1: React + WordPress + Firebase

```bash
# 1. Initialize IgniStack
ignistack init my-react-app --mount $(pwd)

# 2. Install dependencies in container
docker exec -it ignistack-wp-my-react-app bash
cd /home/flexy/workspace
npm install

# 3. Start development
npm run dev

# 4. WordPress content syncs to Firebase automatically
# Access at http://localhost:8080/wp-admin
```

### Scenario 2: Content Management with AI

```bash
# 1. Create instance
ignistack init content-site --port 8080

# 2. Generate alt text for all images
ignistack ai generate-alt-text content-site

# 3. Generate content structure
ignistack ai generate-form "Product: name, price, description, images" \
  --post-type=product

# 4. Generate individual content
ignistack ai generate-content 123 description \
  --prompt="Write compelling product description"
```

### Scenario 3: Schema-Driven Development

```bash
# 1. Define your schema in WordPress
# (via wp-admin or schema files)

# 2. Validate schema
ignistack schema validate product

# 3. Register in WordPress
ignistack schema register product

# 4. Export TypeScript types for frontend
ignistack schema export product \
  --output=./src/types/product.ts

# 5. Use types in your React app
import { Product } from './types/product';
```

## Configuration

### Environment Variables

Set these in your shell or project `.env` file:

```bash
# API Keys
export OPENAI_API_KEY="sk-..."          # For AI features
export ANTHROPIC_AUTH_TOKEN="sk-ant-"   # For Claude Code
export FIREBASE_TOKEN="..."              # For Firebase CLI

# IgniStack Settings
export IGNISTACK_IMAGE="ghcr.io/misterlex223/ignistack-sandbox:latest"
export IGNISTACK_INSTANCES_ROOT="$HOME/.ignistack-instances"
```

### Project Configuration

Create `.ignistack.yml` in your project root:

```yaml
project_name: my-app
port: 8080
mount: ./src

firebase:
  port: 5000
  ui_port: 4000

webtty:
  port: 9681

cospec:
  port: 9280

environment:
  WP_DEBUG: "true"
  WP_DEBUG_LOG: "true"
  OPENAI_API_KEY: ${OPENAI_API_KEY}
```

## Claude Code Skill & Commands Usage

When using Claude Code, IgniStack provides both:

1. **Skill**: Context and documentation about IgniStack capabilities
2. **Slash Command (`/ignistack`)**: Executes actual operations

```
# Initialize a project
/ignistack init my-new-project

# Start working
/ignistack start my-new-project

# Generate some content
/ignistack ai generate-form "Blog post: title, content, featured image"

# Check status
/ignistack info my-new-project
```

The `/ignistack` command automatically:
1. Checks if CLI is installed
2. Executes the requested operation via `ignistack-cli.sh`
3. Provides clear output and error handling
4. Handles container management, port allocation, volume mounting

## Architecture Integration

```
Your Project
    ↓
ignistack CLI
    ↓
Docker Container (ghcr.io/misterlex223/ignistack-sandbox:latest)
    ├── WordPress (SQLite) ← Content Management
    ├── Firebase Emulator ← Real-time Backend
    ├── IgnisAI Plugin ← AI Content Generation
    └── WebTTY ← Terminal Access
```

### Data Flow

1. **Content Creation**: WordPress admin or AI-generated
2. **Storage**: SQLite database (`wp-content/database/.ht.sqlite`)
3. **Sync**: Automatically syncs to Firebase
4. **Frontend**: Consumes WordPress REST API or Firebase
5. **AI Enhancement**: Claude/OpenAI generates and improves content

## Troubleshooting Integration Issues

### Issue: "Command not found: ignistack"

**Solution**: Add to PATH or use full path:
```bash
export PATH="$PATH:$HOME/.ignistack"
# or
~/.ignistack/ignistack-cli.sh
```

### Issue: "Port already in use"

**Solution**: Use a different port:
```bash
ignistack init my-project --port 8081
```

### Issue: "Container exits immediately"

**Solution**: Check logs:
```bash
docker logs ignistack-wp-my-project
ignistack logs ignistack-wp-my-project
```

### Issue: "WordPress shows install screen"

**Solution**: Check volume mount:
```bash
docker inspect ignistack-wp-my-project | grep wordpress-persistent
```

## Best Practices

1. **Instance Naming**: Use descriptive names (dev, test, staging, prod)
2. **Port Management**: Document port assignments for your team
3. **Backup**: Regularly backup `~/.ignistack-instances/`
4. **Security**: Never commit `.env` files with API keys
5. **Updates**: Periodically pull latest image:
   ```bash
   docker pull ghcr.io/misterlex223/ignistack-sandbox:latest
   ```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Test with IgniStack

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Start IgniStack
        run: |
          docker run -d \
            -p 8080:80 \
            -e WP_INSTANCE_NAME=ci-test \
            ghcr.io/misterlex223/ignistack-sandbox:latest

      - name: Run tests
        run: |
          # Wait for WordPress to be ready
          sleep 30
          # Run your tests
          docker exec ignistack-wp-ci-test wp plugin test --allow-root
```

## Advanced Topics

### Custom Docker Images

Build your own image based on IgniStack:

```dockerfile
FROM ghcr.io/misterlex223/ignistack-sandbox:latest

# Add custom plugins
COPY custom-plugin/ /tmp/custom-plugin/
RUN wp plugin install /tmp/custom-plugin --allow-root

# Configure WordPress
RUN wp config set WP_DEBUG true --raw --allow-root
```

### Plugin Development

```bash
# Mount your plugin directory
docker run -d \
  -v /path/to/plugin:/home/flexy/workspace/plugin \
  ghcr.io/misterlex223/ignistack-sandbox:latest

# In container
wp plugin symlink /home/flexy/workspace/plugin --allow-root
```

### Multi-Project Setup

```bash
# Project 1
ignistack init project-a --port 8080

# Project 2
ignistack init project-b --port 8081

# Both run simultaneously with isolated data
```

## Support and Resources

- **GitHub**: https://github.com/misterlex223/ignistack-sandbox
- **Issues**: Report bugs and request features
- **Documentation**: Comprehensive guides in the repository
- **Docker Hub**: https://github.com/misterlex223/ignistack-sandbox/pkgs/container/ignistack-sandbox

## Summary

IgniStack provides a complete, production-ready development environment that integrates seamlessly with any project. Whether you're building a headless CMS, a content-rich application, or an AI-powered platform, IgniStack handles the infrastructure so you can focus on your application logic.

**Key Benefits**:
- Zero-config setup
- No database server needed
- AI-powered content generation
- Firebase integration
- Multi-instance support
- Claude Code Skill for natural-language interaction

**Next Steps**:
1. Run the installation script
2. Initialize your first project
3. Explore the AI and schema features
4. Build your application on top of IgniStack
