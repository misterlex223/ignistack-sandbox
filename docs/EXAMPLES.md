# IgniStack Usage Examples

This document provides practical examples for common IgniStack workflows.

## Table of Contents

- [Quick Start Examples](#quick-start-examples)
- [Project Setup Examples](#project-setup-examples)
- [Development Workflow Examples](#development-workflow-examples)
- [AI-Powered Development Examples](#ai-powered-development-examples)
- [Schema-Driven Development Examples](#schema-driven-development-examples)
- [Multi-Environment Examples](#multi-environment-examples)
- [Troubleshooting Examples](#troubleshooting-examples)

## Quick Start Examples

### Example 1: Create Your First Project

```bash
# Install IgniStack
curl -fsSL https://raw.githubusercontent.com/misterlex223/ignistack-sandbox/main/install-ignistack.sh | bash

# Initialize a new project
ignistack init my-first-project

# Access WordPress
open http://localhost:8080/wp-admin
# Username: admin
# Password: password123
```

### Example 2: Quick WordPress Instance

```bash
# Create a WordPress instance without a full project
ignistack create-instance blog --port 8080
ignistack start blog

# Check status
ignistack info blog
```

## Project Setup Examples

### Example 3: Integrate with Existing React Project

```bash
# Navigate to your project
cd /path/to/my-react-app

# Initialize IgniStack with project mount
ignistack init react-app --mount $(pwd)

# Your project files are now available in the container
# Install dependencies inside container
docker exec -it ignistack-wp-react-app bash
cd /home/flexy/workspace
npm install
npm run dev
```

### Example 4: Custom Port Configuration

```bash
# Avoid port conflicts by specifying custom ports
ignistack init my-project \
  --port 8081 \
  --firebase-port 5001 \
  --firebase-ui-port 4001 \
  --ttyd-port 9682 \
  --cospec-port 9281
```

### Example 5: Using Configuration File

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

Then initialize:

```bash
ignistack init --config .ignistack.yml
```

## Development Workflow Examples

### Example 6: Working with WordPress via CLI

```bash
# List all plugins
ignistack wp my-project plugin list

# Activate a plugin
ignistack wp my-project plugin activate akismet

# Create a new post
ignistack wp my-project post create --post_title='Hello World' --post_content='Welcome to IgniStack'

# List all posts
ignistack wp my-project post list

# Get site URL
ignistack wp my-project option get siteurl
```

### Example 7: Database Operations

```bash
# Export database
docker exec ignistack-wp-my-project \
  wp db export ~/backup.sql --allow-root

# Import database
docker exec ignistack-wp-my-project \
  wp db import ~/backup.sql --allow-root

# Search and replace
ignistack wp my-project search-replace 'localhost:8080' 'https://example.com'
```

### Example 8: File Operations in Container

```bash
# Open shell in container
ignistack shell ignistack-wp-my-project

# Inside container:
cd /home/flexy/wordpress-persistent/wp-content
ls -la

# Edit files
vi themes/my-theme/functions.php

# View logs
tail -f /home/flexy/wordpress.log
```

## AI-Powered Development Examples

### Example 9: Generate Content Structure

```bash
# Generate a complete field group for products
ignistack ai generate-form my-project \
  "Product catalog: name (text), price (number), description (wysiwyg), images (gallery), SKU (text), category (taxonomy)" \
  --post-type=product \
  --title="Product Information"
```

### Example 10: Generate Content with AI

```bash
# Generate alt text for all images
ignistack ai generate-alt-text my-project

# Generate description for a specific post
ignistack ai generate-content my-project 123 description \
  --prompt="Write a compelling product description highlighting key features"
```

### Example 11: Bulk Content Generation

```bash
# Create multiple posts and generate content
for i in {1..10}; do
  POST_ID=$(ignistack wp my-project post create --post_title="Product $i" --post_status=draft --porcelain)
  ignistack ai generate-content my-project $POST_ID post_content \
    --prompt="Write engaging content for Product $i"
done
```

## Schema-Driven Development Examples

### Example 12: Define Custom Post Type

Create a schema file in WordPress:

```bash
# Define schema (usually done via WordPress admin or schema files)
ignistack schema validate my-project product

# Register in WordPress
ignistack schema register my-project --post_type=product

# Export TypeScript types
ignistack schema export my-project product --output=./src/types/product.ts
```

### Example 13: Export All Schemas

```bash
# Export all schemas to your frontend project
ignistack schema export-all my-project --output=./src/types

# Use in your TypeScript code:
import { Product, Article, Portfolio } from './types';
```

### Example 14: Schema Validation

```bash
# Validate all schemas before deployment
ignistack schema list my-project | awk 'NR>1 {print $1}' | while read post_type; do
  echo "Validating $post_type..."
  ignistack schema validate my-project "$post_type"
done
```

## Multi-Environment Examples

### Example 15: Development, Staging, and Production

```bash
# Create three environments
ignistack create-instance dev --port 8080
ignistack create-instance staging --port 8081
ignistack create-instance production --port 8082

# Start all environments
ignistack start dev
ignistack start staging
ignistack start production

# View all instances
ignistack list
```

### Example 16: Environment-Specific Configuration

```bash
# Development with debugging
ignistack init dev-env \
  -e WP_DEBUG=true \
  -e WP_DEBUG_LOG=true \
  -e SCRIPT_DEBUG=true

# Production with optimizations
ignistack init prod-env \
  -e WP_DEBUG=false \
  -e WP_DEBUG_LOG=false \
  -e SCRIPT_DEBUG=false
```

### Example 17: Data Migration Between Environments

```bash
# Export from development
docker exec ignistack-wp-dev \
  wp db export ~/dev-backup.sql --allow-root

# Copy to staging
docker cp \
  $(docker ps -q -f name=ignistack-wp-dev):/home/flexy/dev-backup.sql \
  /tmp/staging-backup.sql

# Import to staging
docker cp /tmp/staging-backup.sql \
  $(docker ps -q -f name=ignistack-wp-staging):/home/flexy/

docker exec ignistack-wp-staging \
  wp db import ~/staging-backup.sql --allow-root
```

## Troubleshooting Examples

### Example 18: Diagnose Issues

```bash
# Run full diagnostics
ignistack doctor

# Check container logs
ignistack logs ignistack-wp-my-project

# Follow logs in real-time
ignistack logs ignistack-wp-my-project --follow

# Show last 50 lines
ignistack logs ignistack-wp-my-project --tail 50
```

### Example 19: Restart and Reset

```bash
# Restart instance
ignistack restart my-project

# Stop and remove container (data preserved)
docker stop ignistack-wp-my-project
docker rm ignistack-wp-my-project

# Start fresh with existing data
ignistack start my-project
```

### Example 20: Debug Mode

```bash
# Enable WordPress debug
docker exec -it ignistack-wp-my-project bash
cd /home/flexy/wordpress-persistent
wp config set WP_DEBUG true --raw --allow-root
wp config set WP_DEBUG_LOG true --raw --allow-root
wp config set WP_DEBUG_DISPLAY true --raw --allow-root

# View debug log
tail -f wp-content/debug.log
```

## CI/CD Examples

### Example 21: GitHub Actions Workflow

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

      - name: Wait for WordPress
        run: |
          for i in {1..30}; do
            if curl -f http://localhost:8080/wp-admin; then
              echo "WordPress is ready"
              break
            fi
            echo "Waiting for WordPress... ($i/30)"
            sleep 2
          done

      - name: Run tests
        run: |
          docker exec ignistack-wp-ci-test wp core version --allow-root
          docker exec ignistack-wp-ci-test wp plugin list --allow-root
```

### Example 22: Automated Backups

```bash
#!/bin/bash
# backup.sh

INSTANCE_NAME="my-project"
BACKUP_DIR="$HOME/backups/ignistack"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# Export database
docker exec ignistack-wp-$INSTANCE_NAME \
  wp db export ~/backup.sql --allow-root

# Copy backup to host
docker cp \
  $(docker ps -q -f name=ignistack-wp-$INSTANCE_NAME):/home/flexy/backup.sql \
  "$BACKUP_DIR/${INSTANCE_NAME}_${DATE}.sql"

# Keep last 7 days
find "$BACKUP_DIR" -name "${INSTANCE_NAME}_*.sql" -mtime +7 -delete

echo "Backup completed: ${INSTANCE_NAME}_${DATE}.sql"
```

## Advanced Examples

### Example 23: Custom Plugin Development

```bash
# Create instance with mounted plugin directory
ignistack init plugin-dev --mount $(pwd)

# In container, symlink the plugin
docker exec -it ignistack-wp-plugin-dev bash
cd /home/flexy/workspace
ln -s "$(pwd)/my-custom-plugin" /home/flexy/wordpress-persistent/wp-content/plugins/my-custom-plugin

# Activate plugin
wp plugin activate my-custom-plugin --allow-root

# Watch for changes and auto-reload
tail -f wp-content/debug.log
```

### Example 24: Multi-Project Workspace

```bash
# Create a shared workspace
mkdir -p ~/workspace/project-{1,2,3}

# Initialize projects with different ports
for i in 1 2 3; do
  ignistack init "project-$i" \
    --mount ~/workspace/project-$i \
    --port $((8080 + i)) \
    --firebase-port $((5000 + i)) \
    --ttyd-port $((9681 + i))
done

# Start all projects
for i in 1 2 3; do
  ignistack start "project-$i"
done
```

### Example 25: Performance Testing

```bash
# Install query monitor
ignistack wp my-project plugin install query-monitor --activate

# Load test with Apache Bench
ab -n 1000 -c 10 http://localhost:8080/

# Check logs
ignistack logs ignistack-wp-my-project --tail 100

# Monitor resource usage
docker stats ignistack-wp-my-project
```

## Tips and Best Practices

### Naming Conventions
```bash
# Use descriptive names
ignistack create-instance dev-main-blog --port 8080
ignistack create-instance client-project-alpha --port 8081
ignistack create-instance experimental-feature --port 8082
```

### Port Management
```bash
# Document your port assignments
cat > ~/.ignistack-ports.json <<EOF
{
  "dev": 8080,
  "staging": 8081,
  "production": 8082,
  "experimental": 8083
}
EOF
```

### Regular Maintenance
```bash
# Update IgniStack image
docker pull ghcr.io/misterlex223/ignistack-sandbox:latest

# Clean up old images
docker image prune -a

# Backup before updates
./backup.sh
ignistack stop my-project
# Update...
ignistack start my-project
```

## Getting Help

```bash
# Show help for any command
ignistack help
ignistack wp --help
ignistack schema --help

# Run diagnostics
ignistack doctor

# Check container status
docker ps -a | grep ignistack

# View logs
ignistack logs <container-name>
```

For more information, visit:
- [Integration Guide](INTEGRATION-GUIDE.md)
- [WordPress Instances](WORDPRESS-INSTANCES.md)
- [SQLite Integration](SQLITE-INTEGRATION.md)
- [Schema System](SCHEMA-SYSTEM-INTEGRATION.md)
- [AI Integration](AI-INTEGRATION.md)
