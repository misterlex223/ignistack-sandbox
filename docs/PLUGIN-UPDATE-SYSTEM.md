# Plugin Update System

This document describes the dynamic plugin update system for GitHub-sourced WordPress plugins in the IgniStack Sandbox.

## Overview

The IgniStack Sandbox includes three WordPress plugins from GitHub:
1. **sqlite-database-integration** - WordPress SQLite integration
2. **ignis-schema-wp** - Schema-based custom post type system
3. **sync-fire-wp** - WordPress to Firestore synchronization

The update system supports two modes:
- **Development Mode**: Plugins auto-update on container startup
- **Production Mode**: Plugins locked to specific versions at build time

## Development Mode (Auto-Update)

### Enabling Auto-Update

When creating a sandbox, add the `--auto-update-plugins` flag:

```bash
# Create sandbox with auto-updating plugins
./host-scripts/create-ignis-sandbox.sh \
  --name dev-env \
  --auto-update-plugins \
  --mount /path/to/code

# With persistent WordPress instance
./host-scripts/create-ignis-sandbox.sh \
  --name dev-env \
  --wp-instance my-project \
  --auto-update-plugins \
  --port 8080
```

### How It Works

1. Container starts up
2. Before WordPress initialization, the update script runs
3. Each plugin is checked against the latest GitHub version
4. If updates are available, plugins are:
   - Backed up (timestamped backup directory)
   - Deactivated
   - Updated to latest version
   - Composer dependencies installed (if needed)
   - Reactivated

### Update Process Details

```bash
# On container startup with AUTO_UPDATE_PLUGINS=true
[INFO] Updating plugin: ignis-schema-wp
[INFO] Current version: abc12345
[INFO] Cloning from https://github.com/misterlex223/ignis-schema-wp (branch/tag: main)...
[INFO] Latest version: def67890
[INFO] Deactivating plugin before update...
[INFO] Backing up current version to .../ignis-schema-wp.backup-20251105-143022
[INFO] Installing Composer dependencies...
[INFO] Reactivating plugin...
[INFO] ✓ Plugin ignis-schema-wp updated successfully (abc12345 → def67890)
```

### Manual Update in Running Container

You can also manually trigger updates inside a running container:

```bash
# Enter the container
docker exec -it <container-name> bash

# Run update script
update-github-plugins.sh

# Or update with custom environment
WORDPRESS_DIR=/path/to/wordpress update-github-plugins.sh
```

## Production Mode (Version Locking)

### Building with Specific Versions

Lock plugins to specific versions at build time using Docker build arguments:

```bash
# Build with specific plugin versions
./host-scripts/build-docker.sh \
  --build-arg SQLITE_VERSION=2.1.0 \
  --build-arg IGNIS_SCHEMA_VERSION=v1.2.3 \
  --build-arg SYNC_FIRE_VERSION=v2.0.1

# Or directly with docker build
docker build \
  --build-arg SQLITE_VERSION=2.1.0 \
  --build-arg IGNIS_SCHEMA_VERSION=v1.2.3 \
  --build-arg SYNC_FIRE_VERSION=v2.0.1 \
  -t ignistack-dev-sandbox:v1.0.0 \
  -f docker/Dockerfile .
```

### Available Build Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `SQLITE_VERSION` | `main` | Branch/tag for SQLite plugin |
| `IGNIS_SCHEMA_VERSION` | `main` | Branch/tag for ignis-schema-wp |
| `SYNC_FIRE_VERSION` | `main` | Branch/tag for sync-fire-wp |

### Version Formats

All version arguments accept:
- Branch names: `main`, `develop`, `feature/new-api`
- Tags: `v1.0.0`, `v2.1.3`
- Commit hashes: `abc123def456` (first 7-8 characters)

### Production Workflow Example

```bash
# Step 1: Build production image with locked versions
docker build \
  --build-arg SQLITE_VERSION=2.1.0 \
  --build-arg IGNIS_SCHEMA_VERSION=v1.5.0 \
  --build-arg SYNC_FIRE_VERSION=v3.2.1 \
  -t ignistack-prod:2024-11-05 \
  -f docker/Dockerfile .

# Step 2: Create production instance (no auto-update flag)
docker run -d \
  --name ignistack-prod \
  -p 8080:80 \
  -v $(pwd)/wordpress-prod:/home/flexy/wordpress-persistent \
  -e WP_INSTANCE_NAME=production \
  ignistack-prod:2024-11-05

# Step 3: Verify plugin versions
docker exec ignistack-prod wp plugin list --path=/home/flexy/wordpress-persistent
```

## Hybrid Approach

Combine both approaches for maximum flexibility:

### Use Case: Development with Occasional Version Lock

```bash
# Development: Auto-update by default
./host-scripts/create-ignis-sandbox.sh \
  --name dev \
  --auto-update-plugins

# Testing: Lock to specific version for stability
docker build \
  --build-arg IGNIS_SCHEMA_VERSION=v1.5.0 \
  -t ignistack-dev-sandbox:test \
  -f docker/Dockerfile .

./host-scripts/create-ignis-sandbox.sh \
  --name test \
  --image ignistack-dev-sandbox:test
  # No --auto-update-plugins flag
```

## Update Script Reference

### Command-Line Usage

```bash
# Basic usage (updates all plugins)
update-github-plugins.sh

# With custom WordPress directory
WORDPRESS_DIR=/path/to/wordpress update-github-plugins.sh

# Update to specific versions via environment
PLUGIN_VERSION_IGNIS_SCHEMA_WP=v1.2.0 \
PLUGIN_VERSION_SYNC_FIRE_WP=v2.1.0 \
  update-github-plugins.sh
```

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `WORDPRESS_DIR` | WordPress installation path | `/home/flexy/wordpress` |
| `PLUGIN_VERSION_SQLITE_DATABASE_INTEGRATION` | Specific version for SQLite plugin | `v2.1.0` or `main` |
| `PLUGIN_VERSION_IGNIS_SCHEMA_WP` | Specific version for schema plugin | `v1.5.0` or `develop` |
| `PLUGIN_VERSION_SYNC_FIRE_WP` | Specific version for sync plugin | `v3.0.0` or `feature/new-api` |

### Exit Codes

- `0`: All plugins updated successfully
- `1`: One or more plugins failed to update

### Output Format

The script provides colored output:
- 🟢 **[INFO]** - Informational messages
- 🟡 **[WARN]** - Warnings (non-fatal issues)
- 🔴 **[ERROR]** - Errors (failures)

## Backup and Recovery

### Automatic Backups

Every time a plugin is updated, the old version is automatically backed up:

```bash
# Backup location format
wp-content/plugins/<plugin-name>.backup-YYYYMMDD-HHMMSS/
```

Example:
```
wp-content/plugins/
├── ignis-schema-wp/                    # Current version
├── ignis-schema-wp.backup-20251105-143022/  # Backup from 14:30
└── ignis-schema-wp.backup-20251104-091533/  # Backup from yesterday
```

### Manual Recovery

If an update causes issues, restore from backup:

```bash
# Enter the container
docker exec -it <container-name> bash

# Navigate to plugins directory
cd /home/flexy/wordpress/wp-content/plugins

# Find available backups
ls -la | grep backup

# Deactivate current plugin
wp plugin deactivate ignis-schema-wp --path=/home/flexy/wordpress

# Restore from backup
rm -rf ignis-schema-wp
cp -r ignis-schema-wp.backup-20251105-143022 ignis-schema-wp

# Reactivate plugin
wp plugin activate ignis-schema-wp --path=/home/flexy/wordpress
```

### Cleanup Old Backups

Backups are not automatically cleaned up. To remove old backups:

```bash
# Remove backups older than 7 days
find /home/flexy/wordpress/wp-content/plugins -name "*.backup-*" -mtime +7 -exec rm -rf {} \;

# Remove all backups for a specific plugin
rm -rf /home/flexy/wordpress/wp-content/plugins/ignis-schema-wp.backup-*
```

## Troubleshooting

### Update Fails During Container Startup

**Symptom**: Container starts but plugins aren't updated

**Solution**:
```bash
# Check container logs
docker logs <container-name> | grep -A 20 "Auto-updating GitHub plugins"

# Manually run update script
docker exec -it <container-name> update-github-plugins.sh
```

### Plugin Activation Fails After Update

**Symptom**: `Failed to reactivate plugin` message

**Possible causes**:
1. Plugin has breaking changes
2. Composer dependencies not installed
3. PHP version incompatibility

**Solution**:
```bash
# Check plugin status
docker exec <container-name> wp plugin status --path=/home/flexy/wordpress

# Check for errors
docker exec <container-name> wp plugin activate <plugin-name> --path=/home/flexy/wordpress

# Restore from backup if needed (see "Manual Recovery" above)
```

### Build Fails with "Branch/tag not found"

**Symptom**: `Failed to clone repository. Branch/tag 'vX.Y.Z' may not exist.`

**Solution**:
```bash
# Verify the tag exists on GitHub
curl -s https://api.github.com/repos/misterlex223/ignis-schema-wp/tags | grep name

# Use correct branch/tag name
docker build --build-arg IGNIS_SCHEMA_VERSION=v1.0.0 ...
```

### Composer Install Fails

**Symptom**: `Composer install failed` warning

**Causes**:
- Network issues
- Invalid composer.json
- Missing PHP extensions

**Solution**:
```bash
# Enter container and manually install
docker exec -it <container-name> bash
cd /home/flexy/wordpress/wp-content/plugins/<plugin-name>
composer install --no-dev --optimize-autoloader -vvv
```

## Best Practices

### Development Workflow

1. **Use auto-update for rapid development**
   ```bash
   ./host-scripts/create-ignis-sandbox.sh \
     --name dev \
     --auto-update-plugins \
     --mount /path/to/code
   ```

2. **Test with locked versions before production**
   ```bash
   # Lock to current stable versions
   docker build \
     --build-arg IGNIS_SCHEMA_VERSION=v1.5.0 \
     -t ignistack:staging \
     -f docker/Dockerfile .
   ```

3. **Keep backups before major updates**
   ```bash
   # Manual backup before enabling auto-update
   docker cp <container>:/home/flexy/wordpress/wp-content/plugins \
     ./plugins-backup-$(date +%Y%m%d)
   ```

### Production Workflow

1. **Always pin versions in production**
   ```bash
   docker build \
     --build-arg SQLITE_VERSION=2.1.0 \
     --build-arg IGNIS_SCHEMA_VERSION=v1.5.0 \
     --build-arg SYNC_FIRE_VERSION=v3.0.0 \
     -t ignistack:prod-$(date +%Y%m%d) \
     -f docker/Dockerfile .
   ```

2. **Never use auto-update in production**
   - Omit `--auto-update-plugins` flag
   - Disable `AUTO_UPDATE_PLUGINS` environment variable

3. **Document plugin versions**
   ```bash
   # Save plugin versions for audit trail
   docker exec <prod-container> \
     wp plugin list --path=/home/flexy/wordpress \
     > plugin-versions-$(date +%Y%m%d).txt
   ```

4. **Test updates in staging first**
   ```bash
   # Staging with new versions
   docker build --build-arg IGNIS_SCHEMA_VERSION=v1.6.0 -t ignistack:staging ...

   # If tests pass, promote to production
   docker tag ignistack:staging ignistack:prod-v1.6.0
   ```

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Build IgniStack Image

on:
  push:
    branches: [main]
    tags: ['v*']

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Build with version locking
        run: |
          docker build \
            --build-arg SQLITE_VERSION=2.1.0 \
            --build-arg IGNIS_SCHEMA_VERSION=${{ github.ref_name }} \
            --build-arg SYNC_FIRE_VERSION=v3.0.0 \
            -t ignistack:${{ github.sha }} \
            -f docker/Dockerfile .

      - name: Run tests
        run: |
          docker run -d --name test ignistack:${{ github.sha }}
          docker exec test wp plugin list --path=/home/flexy/wordpress
          docker exec test wp plugin status ignis-schema-wp --path=/home/flexy/wordpress

      - name: Push image
        if: github.ref_type == 'tag'
        run: |
          docker tag ignistack:${{ github.sha }} ignistack:${{ github.ref_name }}
          docker push ignistack:${{ github.ref_name }}
```

## Advanced Usage

### Updating Only Specific Plugins

Modify the update script to skip certain plugins:

```bash
# Create custom update script
cat > /tmp/update-schema-only.sh << 'EOF'
#!/bin/bash
export WORDPRESS_DIR=/home/flexy/wordpress
PLUGIN_VERSION_IGNIS_SCHEMA_WP=main \
PLUGIN_VERSION_SQLITE_DATABASE_INTEGRATION=skip \
PLUGIN_VERSION_SYNC_FIRE_WP=skip \
  update-github-plugins.sh
EOF

chmod +x /tmp/update-schema-only.sh
docker cp /tmp/update-schema-only.sh <container>:/tmp/
docker exec <container> /tmp/update-schema-only.sh
```

### Custom Plugin Sources

To add support for additional GitHub plugins, modify the update script:

```bash
# In container-scripts/update-github-plugins.sh
declare -A PLUGINS=(
    ["sqlite-database-integration"]="WordPress/sqlite-database-integration"
    ["ignis-schema-wp"]="misterlex223/ignis-schema-wp"
    ["sync-fire-wp"]="misterlex223/sync-fire-wp"
    ["your-custom-plugin"]="yourorg/your-plugin"  # Add here
)
```

Then rebuild the image to include the modified script.

## Version History

- **2024-11-05**: Initial release of plugin update system
  - Development mode with auto-update on startup
  - Production mode with version locking via build args
  - Automatic backup before updates
  - Composer dependency management

## Related Documentation

- [WordPress Instances](WORDPRESS-INSTANCES.md) - Managing persistent WordPress instances
- [SQLite Integration](SQLITE-INTEGRATION.md) - SQLite database configuration
- [Schema System](SCHEMA-SYSTEM-INTEGRATION.md) - Using ignis-schema-wp
- [AI Integration](AI-INTEGRATION.md) - Using ignis-ai features
