# WordPress Persistent Instances Guide

## Overview

The ignistack-sandbox now supports **persistent WordPress installations** that survive container restarts. This allows you to create multiple isolated WordPress environments for different purposes (development, testing, production staging, etc.).

Each instance comes with essential plugins pre-installed, including:
- **Advanced Custom Fields (ACF)** - For defining custom data structures
- **sync-fire-wp** - For synchronizing WordPress content to Firestore
- **SQLite Database Integration** - For database functionality without MySQL

## Key Features

✅ **Persistent Data** - WordPress files and SQLite database survive container restarts
✅ **Multiple Instances** - Run different WordPress setups simultaneously
✅ **Isolated Environments** - Each instance has its own plugins, themes, and database
✅ **Easy Management** - Simple CLI commands to create, start, stop, and remove instances
✅ **Port Flexibility** - Configure custom ports for each instance

## Architecture

```
ignistack-sandbox/
├── wordpress-instances/           ← All persistent WordPress data
│   ├── dev/                       ← Development instance
│   │   ├── wp-content/
│   │   │   ├── database/
│   │   │   │   └── .ht.sqlite    ← SQLite database
│   │   │   ├── plugins/
│   │   │   ├── themes/
│   │   │   └── uploads/
│   │   ├── wp-config.php
│   │   └── .instance-info         ← Instance metadata
│   ├── testing/                    ← Testing instance
│   └── staging/                    ← Staging instance
└── host-scripts/
    ├── create-wp-instance.sh       ← Dedicated WordPress manager
    └── create-ignis-sandbox.sh     ← Main sandbox script (with WP support)
```

### How It Works

1. **Base WordPress** - Docker image contains a clean WordPress installation with SQLite plugin
2. **Persistent Volume** - Host directory mounted to `/home/flexy/wordpress-persistent` in container
3. **First Run** - Base WordPress copied to persistent volume
4. **Subsequent Runs** - Existing WordPress data reused from persistent volume

## Quick Start

### Method 1: Using the Dedicated WordPress Instance Script (Recommended)

```bash
# Create a new development instance
./host-scripts/create-wp-instance.sh create dev --port 8080

# Create a testing instance with custom ports
./host-scripts/create-wp-instance.sh create testing \
  --port 8081 \
  --ttyd-port 9682 \
  --cospec-port 9281

# List all instances
./host-scripts/create-wp-instance.sh list

# Stop an instance
./host-scripts/create-wp-instance.sh stop dev

# Start an existing instance
./host-scripts/create-wp-instance.sh start dev

# Show instance information
./host-scripts/create-wp-instance.sh info dev

# Remove an instance (CAUTION: Deletes all data!)
./host-scripts/create-wp-instance.sh remove old-project
```

### Method 2: Using the Main Sandbox Script

```bash
# Create sandbox with persistent WordPress instance
./host-scripts/create-ignis-sandbox.sh \
  --name igni-dev \
  --wp-instance dev \
  --port 8080 \
  --mount /path/to/project

# Without WordPress instance (ephemeral)
./host-scripts/create-ignis-sandbox.sh \
  --name igni-temp \
  --port 9090
```

## Detailed Usage

### Creating WordPress Instances

#### Basic Instance Creation

```bash
./host-scripts/create-wp-instance.sh create my-project
```

This creates:
- Instance name: `my-project`
- Container name: `ignistack-wp-my-project`
- Data location: `./wordpress-instances/my-project/`
- WordPress: http://localhost:80
- WebTTY: http://localhost:9681
- CoSpec AI: http://localhost:9280

#### Advanced Instance Creation

```bash
./host-scripts/create-wp-instance.sh create my-project \
  --port 8080 \
  --ttyd-port 9682 \
  --cospec-port 9281 \
  --firebase-port 5010 \
  --mount /path/to/code \
  --anthropic-token "your-token" \
  --firebase-token "your-firebase-token"
```

**Options:**
- `--port` - WordPress HTTP port (default: 80)
- `--ttyd-port` - WebTTY terminal port (default: 9681)
- `--cospec-port` - CoSpec AI editor port (default: 9280)
- `--firebase-port` - Firebase emulator starting port (default: 5000)
- `--mount` - Additional host directory to mount to `/home/flexy/workspace`
- `--anthropic-token` - Claude AI API token
- `--firebase-token` - Firebase CLI authentication token

### Managing Instances

#### List All Instances

```bash
./host-scripts/create-wp-instance.sh list
```

Output example:
```
WordPress Instances:
====================
NAME                 STATUS          CONTAINER                      SIZE
----                 ------          ---------                      ----
dev                  running         ignistack-wp-dev               156M
testing              stopped         ignistack-wp-testing           142M
staging              running         ignistack-wp-staging           189M
```

#### Show Instance Information

```bash
./host-scripts/create-wp-instance.sh info dev
```

Output example:
```
WordPress Instance Information
==============================
Instance: dev
Location: /path/to/wordpress-instances/dev
Container: ignistack-wp-dev
Status: Running

Container details:
NAMES                   STATUS              PORTS
ignistack-wp-dev       Up 2 hours          0.0.0.0:8080->80/tcp, ...

Instance metadata:
INSTANCE_NAME=dev
CREATED_AT=2024-10-28 15:30:45
WP_PORT=8080
TTYD_PORT=9681
COSPEC_PORT=9280

Disk usage:
156M    /path/to/wordpress-instances/dev

✓ WordPress is installed
✓ SQLite database exists (12M)
```

#### Start/Stop Instances

```bash
# Stop an instance
./host-scripts/create-wp-instance.sh stop dev

# Start an instance
./host-scripts/create-wp-instance.sh start dev

# Start with different ports (overrides saved settings)
./host-scripts/create-wp-instance.sh start dev --port 9090
```

#### Remove an Instance

```bash
./host-scripts/create-wp-instance.sh remove old-project
```

**WARNING:** This permanently deletes all WordPress data including:
- All posts, pages, and media
- All plugins and themes
- SQLite database
- Configuration files

You will be asked to confirm by typing `yes`.

## Common Use Cases

### Use Case 1: Development and Testing Environments

Create separate instances for development and testing:

```bash
# Development instance
./host-scripts/create-wp-instance.sh create dev \
  --port 8080 \
  --mount ~/projects/my-plugin

# Testing instance (separate database, plugins, etc.)
./host-scripts/create-wp-instance.sh create test \
  --port 8081 \
  --mount ~/projects/my-plugin
```

Now you can:
- Develop plugins in `dev` instance (port 8080)
- Test changes in `test` instance (port 8081)
- Both share the same plugin code via `--mount`
- But have completely separate WordPress databases and configurations

### Use Case 2: Multiple Client Projects

```bash
# Client A project
./host-scripts/create-wp-instance.sh create client-a \
  --port 8080 \
  --mount ~/clients/a/custom-theme

# Client B project
./host-scripts/create-wp-instance.sh create client-b \
  --port 8081 \
  --mount ~/clients/b/custom-theme

# Client C project (stopped when not needed)
./host-scripts/create-wp-instance.sh create client-c --port 8082
./host-scripts/create-wp-instance.sh stop client-c
```

### Use Case 3: Plugin/Theme Development

```bash
# Create instance for your plugin
./host-scripts/create-wp-instance.sh create my-plugin-dev \
  --port 8080 \
  --mount ~/dev/my-awesome-plugin

# Access container to symlink your plugin
docker exec -it ignistack-wp-my-plugin-dev bash
cd /home/flexy/wordpress-persistent/wp-content/plugins
ln -s /home/flexy/workspace/my-awesome-plugin ./
exit

# Your plugin code is now live in WordPress
# Edit files in ~/dev/my-awesome-plugin and see changes immediately
```

### Use Case 4: Long-term Projects

```bash
# Create a persistent instance for a long-term project
./host-scripts/create-wp-instance.sh create blog-redesign --port 8080

# Work on it, install plugins, create content...
# Stop when not needed
./host-scripts/create-wp-instance.sh stop blog-redesign

# Start again weeks later - all data intact
./host-scripts/create-wp-instance.sh start blog-redesign --port 8080
```

## Data Management

### Backup an Instance

```bash
# Stop the instance first (recommended for consistency)
./host-scripts/create-wp-instance.sh stop my-instance

# Backup the entire instance directory
tar -czf my-instance-backup-$(date +%Y%m%d).tar.gz \
  wordpress-instances/my-instance/

# Or use rsync
rsync -av wordpress-instances/my-instance/ /backup/location/
```

### Restore an Instance

```bash
# Extract backup
tar -xzf my-instance-backup-20241028.tar.gz -C wordpress-instances/

# Start the instance
./host-scripts/create-wp-instance.sh start my-instance
```

### Clone an Instance

```bash
# Stop source instance (optional but recommended)
./host-scripts/create-wp-instance.sh stop source-instance

# Copy the instance directory
cp -r wordpress-instances/source-instance wordpress-instances/new-instance

# Start the new instance with different ports
./host-scripts/create-wp-instance.sh start new-instance --port 8082
```

### Export WordPress Data

```bash
# Access the container
docker exec -it ignistack-wp-my-instance bash

# Use WP-CLI to export
cd /home/flexy/wordpress-persistent
wp export --dir=/home/flexy/workspace/export

# Or dump SQLite database
sqlite3 wp-content/database/.ht.sqlite .dump > /home/flexy/workspace/backup.sql
```

## Ephemeral vs Persistent WordPress

### Ephemeral WordPress (Default)

```bash
# Create container without --wp-instance
./host-scripts/create-ignis-sandbox.sh --name temp-wp --port 8080
```

**Characteristics:**
- ❌ Data lost when container is removed
- ✅ Fast to create
- ✅ No disk space used on host
- ✅ Good for quick tests

**Use when:**
- Testing WordPress core
- Quick plugin compatibility checks
- Learning WordPress
- Disposable environments

### Persistent WordPress

```bash
# Create container with --wp-instance
./host-scripts/create-ignis-sandbox.sh \
  --name persistent-wp \
  --wp-instance my-project \
  --port 8080
```

**Characteristics:**
- ✅ Data persists between container restarts
- ✅ Can stop/start without losing data
- ✅ Multiple instances possible
- ❌ Uses host disk space
- ❌ Slightly slower initial setup (one-time copy)

**Use when:**
- Real projects
- Long-term development
- Need to preserve data
- Client work
- Multiple isolated environments

## Troubleshooting

### Instance Won't Start

**Problem:** Container fails to start or exits immediately

**Solutions:**

1. Check if port is already in use:
```bash
lsof -i :8080  # Check if port 8080 is used
```

2. Check container logs:
```bash
docker logs ignistack-wp-instance-name
```

3. Verify image exists:
```bash
docker images | grep ignistack-dev-sandbox
# If not found, rebuild:
./host-scripts/build-docker.sh
```

4. Check instance directory permissions:
```bash
ls -ld wordpress-instances/instance-name
# Should be readable/writable
```

### WordPress Shows Installation Screen Every Time

**Problem:** WordPress asks to install even though you already installed it

**Possible Causes:**

1. **Wrong volume mount** - Check container is using persistent volume:
```bash
docker inspect ignistack-wp-instance-name | grep wordpress-persistent
```

2. **wp-config.php missing** - Check if file exists:
```bash
ls -l wordpress-instances/instance-name/wp-config.php
```

3. **Database path wrong** - Verify database file exists:
```bash
ls -l wordpress-instances/instance-name/wp-content/database/.ht.sqlite
```

### Cannot Access WordPress (Connection Refused)

**Problem:** Browser shows connection refused at http://localhost:port

**Solutions:**

1. Verify container is running:
```bash
docker ps | grep ignistack-wp
```

2. Check port mapping:
```bash
docker port ignistack-wp-instance-name
```

3. Check WordPress server logs:
```bash
docker logs ignistack-wp-instance-name | tail -50
```

4. Test from inside container:
```bash
docker exec ignistack-wp-instance-name curl http://localhost:80
```

### Database Corruption

**Problem:** SQLite database errors or corruption

**Solutions:**

1. Check database integrity:
```bash
docker exec ignistack-wp-instance-name \
  sqlite3 /home/flexy/wordpress-persistent/wp-content/database/.ht.sqlite \
  "PRAGMA integrity_check;"
```

2. If corrupted, restore from backup or recreate:
```bash
# Stop instance
./host-scripts/create-wp-instance.sh stop instance-name

# Backup corrupted database
mv wordpress-instances/instance-name/wp-content/database/.ht.sqlite \
   wordpress-instances/instance-name/wp-content/database/.ht.sqlite.corrupted

# Start instance (will create new database)
./host-scripts/create-wp-instance.sh start instance-name
```

### Disk Space Issues

**Problem:** Running out of disk space

**Check instance sizes:**
```bash
du -sh wordpress-instances/*
```

**Clean up:**
```bash
# Remove unused instances
./host-scripts/create-wp-instance.sh remove old-instance

# Clean WordPress uploads
rm -rf wordpress-instances/instance-name/wp-content/uploads/*

# Clean WordPress cache (if using cache plugin)
```

## Best Practices

### 1. Use Meaningful Instance Names

✅ Good:
- `client-acme-website`
- `blog-redesign-2024`
- `plugin-development`

❌ Bad:
- `test123`
- `wordpress1`
- `temp`

### 2. Document Your Instances

Create a README in your instance directory:
```bash
cat > wordpress-instances/my-project/README.md <<EOF
# My Project WordPress Instance

## Purpose
Development environment for client website redesign

## Plugins Installed
- Advanced Custom Fields (pre-installed in sandbox)
- WooCommerce
- Custom sync-fire-wp plugin

## Access
- WordPress: http://localhost:8080
- Admin: http://localhost:8080/wp-admin
- Username: admin
- Password: [stored in password manager]

## Notes
- Connected to Firebase project: my-project-123
- Using custom theme in /home/flexy/workspace/my-theme
EOF
```

### 3. Regular Backups

Set up automatic backups:
```bash
# Create backup script
cat > backup-wordpress.sh <<'EOF'
#!/bin/bash
BACKUP_DIR="/backups/wordpress"
mkdir -p "$BACKUP_DIR"

for instance in wordpress-instances/*; do
  name=$(basename "$instance")
  echo "Backing up $name..."
  tar -czf "$BACKUP_DIR/${name}-$(date +%Y%m%d).tar.gz" "$instance"
done
EOF

chmod +x backup-wordpress.sh

# Run weekly via cron
# 0 2 * * 0 /path/to/backup-wordpress.sh
```

### 4. Stop Unused Instances

Save resources by stopping instances you're not using:
```bash
# Stop all instances
for container in $(docker ps --filter name=ignistack-wp- --format "{{.Names}}"); do
  docker stop "$container"
done

# Or stop specific instances
./host-scripts/create-wp-instance.sh stop old-project
```

### 5. Use Version Control for Custom Code

Keep your custom plugins/themes in git:
```bash
# Your custom plugin
cd ~/dev/my-plugin
git init
git add .
git commit -m "Initial commit"

# Mount it in instance
./host-scripts/create-wp-instance.sh create dev \
  --port 8080 \
  --mount ~/dev/my-plugin

# Symlink in container
docker exec ignistack-wp-dev bash -c \
  "ln -s /home/flexy/workspace /home/flexy/wordpress-persistent/wp-content/plugins/my-plugin"
```

### 6. Test Plugin Compatibility

Before installing a plugin in production:
```bash
# Create test instance
./host-scripts/create-wp-instance.sh create plugin-test --port 8090

# Install and test plugin
# If issues, remove instance without affecting others
./host-scripts/create-wp-instance.sh remove plugin-test
```

## Advanced Configuration

### Custom WordPress Configuration

Edit `wp-config.php` in your instance:
```bash
# Edit wp-config.php
nano wordpress-instances/my-instance/wp-config.php
```

Add custom configurations:
```php
// Enable debug mode
define( 'WP_DEBUG', true );
define( 'WP_DEBUG_LOG', true );
define( 'WP_DEBUG_DISPLAY', false );

// Increase memory limit
define( 'WP_MEMORY_LIMIT', '256M' );

// Custom table prefix
$table_prefix = 'custom_';

// Disable file editing
define( 'DISALLOW_FILE_EDIT', true );
```

### Using Custom Ports for Multiple Instances

Run multiple instances simultaneously:
```bash
# Development instance
./host-scripts/create-wp-instance.sh create dev \
  --port 8080 \
  --ttyd-port 9681 \
  --cospec-port 9280

# Testing instance
./host-scripts/create-wp-instance.sh create test \
  --port 8081 \
  --ttyd-port 9691 \
  --cospec-port 9290

# Staging instance
./host-scripts/create-wp-instance.sh create staging \
  --port 8082 \
  --ttyd-port 9701 \
  --cospec-port 9300
```

All three run simultaneously with different ports!

### Sharing Instances Across Team

Use a shared directory:
```bash
# Create instances in shared location
mkdir -p /shared/team-wordpress-instances

# Modify script or use symlink
ln -s /shared/team-wordpress-instances wordpress-instances

# Team members can start the same instances
./host-scripts/create-wp-instance.sh start shared-dev --port 8080
```

## Migration from Ephemeral to Persistent

If you started with ephemeral WordPress and want to make it persistent:

```bash
# 1. Export WordPress data from running ephemeral container
docker exec ignistack-sandbox-temp bash -c \
  "cd /home/flexy/wordpress && wp export --dir=/tmp/wp-export"

# 2. Copy export to host
docker cp ignistack-sandbox-temp:/tmp/wp-export ./wordpress-export

# 3. Create new persistent instance
./host-scripts/create-wp-instance.sh create my-persistent --port 8080

# 4. Import data to new instance
docker cp ./wordpress-export ignistack-wp-my-persistent:/tmp/
docker exec ignistack-wp-my-persistent bash -c \
  "cd /home/flexy/wordpress-persistent && wp import /tmp/wordpress-export/*.xml"

# 5. Remove old ephemeral container
docker stop ignistack-sandbox-temp
docker rm ignistack-sandbox-temp
```

## FAQ

**Q: Can I run multiple instances at the same time?**
A: Yes! Just use different ports for each instance.

**Q: How much disk space does each instance use?**
A: Fresh instance: ~140MB. With content: 150-500MB typically.

**Q: Can I move an instance to another machine?**
A: Yes, just copy the `wordpress-instances/name/` directory.

**Q: Can I use MySQL instead of SQLite for an instance?**
A: Not directly. The SQLite integration is baked into the image. For MySQL, you'd need to modify the Dockerfile.

**Q: What happens if I delete a container but not the instance directory?**
A: The data is safe! Just start the instance again with the same name.

**Q: Can I rename an instance?**
A: Yes, just rename the directory in `wordpress-instances/` and update the `.instance-info` file.

**Q: How do I upgrade WordPress in an instance?**
A: Use WP-CLI: `docker exec ignistack-wp-name wp core update`

**Q: Can I share plugins between instances?**
A: Not automatically, but you can symlink from a shared location.

## Summary

The WordPress persistent instances feature gives you:
- 🎯 **Flexibility** - Multiple isolated WordPress environments
- 💾 **Persistence** - Data survives container restarts
- 🚀 **Simplicity** - Easy CLI management
- 🔧 **Control** - Full access to WordPress files and database
- 📦 **Portability** - Easy backup, restore, and migration

Perfect for:
- Plugin and theme development
- Client projects
- Testing and staging
- Learning WordPress
- Long-term projects

---

**Quick Reference:**

```bash
# Create
./host-scripts/create-wp-instance.sh create NAME --port PORT

# List
./host-scripts/create-wp-instance.sh list

# Start
./host-scripts/create-wp-instance.sh start NAME

# Stop
./host-scripts/create-wp-instance.sh stop NAME

# Info
./host-scripts/create-wp-instance.sh info NAME

# Remove
./host-scripts/create-wp-instance.sh remove NAME
```

For more information, see `SQLITE-INTEGRATION.md` for database details.
