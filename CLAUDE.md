# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

IgniStack Sandbox is a Docker-based development environment for the IgniStack: React + Vite frontend, Firebase backend, and WordPress CMS with SQLite database. Key innovation: **WordPress uses SQLite instead of MySQL**, enabling portable, persistent WordPress instances without a database server.

### WordPress Plugin Ecosystem

The sandbox includes a powerful plugin stack for modern development:

1. **ignis-schema-wp** (https://github.com/misterlex223/ignis-schema-wp)
   - Schema-based custom post type definition using YAML/JSON
   - TypeScript type generation for React frontend
   - WP-CLI commands: `wp schema list|validate|register|export`
   - Built on top of ACF (required dependency)
   - Location: Should be installed at `wp-content/plugins/ignis-schema-wp/`

2. **ignis-ai** (`docker/plugins/ignis-ai/`)
   - AI-powered content generation using Claude
   - Automatic image alt text via vision API
   - ACF field group generator from natural language
   - SEO analysis and optimization
   - WP-CLI commands: `wp ignis-ai generate-alt-text|generate-content|generate-form`
   - Requires: `OPENAI_API_KEY` environment variable

3. **sync-fire-wp**
   - Real-time WordPress to Firestore synchronization
   - Syncs custom post types and ACF fields
   - Configured via WordPress admin

4. **ACF (Advanced Custom Fields)**
   - Core dependency for ignis-schema-wp
   - Provides field rendering engine
   - Pre-installed and activated

5. **SQLite Database Integration**
   - Enables WordPress to use SQLite instead of MySQL
   - Database location: `wp-content/database/.ht.sqlite`

## Core Architecture

### Multi-Instance WordPress System

The project implements a **persistent WordPress instance manager** where:

1. **Base WordPress** lives in Docker image at `/home/flexy/wordpress`
2. **Persistent instances** are mounted to `/home/flexy/wordpress-persistent` via host volumes
3. **Instance detection** happens in `docker/init.sh` via `WP_INSTANCE_NAME` environment variable
4. **First run**: Base WordPress copied to persistent volume, wp-config.php created with SQLite settings
5. **Subsequent runs**: Existing persistent data reused

Critical flow in `docker/init.sh`:
```bash
if [ -n "$WP_INSTANCE_NAME" ] && [ -d "/home/flexy/wordpress-persistent" ]; then
    export WORDPRESS_DIR="/home/flexy/wordpress-persistent"
    # Copy base if new, else reuse existing
else
    export WORDPRESS_DIR="/home/flexy/wordpress"  # Ephemeral
fi
```

### SQLite Integration (Critical Details)

**Do NOT copy `wp-includes/sqlite/db.php` directly!** Must use the `db.copy` template:

```dockerfile
# Correct approach in Dockerfile:
sed 's|{SQLITE_IMPLEMENTATION_FOLDER_PATH}|/path/to/plugin|g; \
     s|{SQLITE_PLUGIN}|sqlite-database-integration/load.php|g' \
    db.copy > wp-content/db.php
```

**Why**: The plugin's `wp-includes/sqlite/db.php` expects files at `dirname(__DIR__, 2)` which would be `/home/flexy/` when placed in `wp-content/`, causing "version.php not found" errors.

wp-config.php must use `__DIR__`:
```php
define( 'DB_DIR', __DIR__ . '/wp-content/database' );  // NOT hardcoded paths
```

## Command Reference

### Build and Deploy

```bash
# Build Docker image
./host-scripts/build-docker.sh

# Create persistent WordPress instance
./host-scripts/create-wp-instance.sh create <name> --port 8080

# Create ephemeral sandbox
./host-scripts/create-ignis-sandbox.sh --name temp --port 8080

# Create sandbox with persistent WordPress
./host-scripts/create-ignis-sandbox.sh \
  --name my-env \
  --wp-instance my-project \
  --port 8080 \
  --mount /path/to/code
```

### WordPress Instance Management

```bash
./host-scripts/create-wp-instance.sh list              # List all instances
./host-scripts/create-wp-instance.sh info <name>       # Show instance details
./host-scripts/create-wp-instance.sh start <name>      # Start instance
./host-scripts/create-wp-instance.sh stop <name>       # Stop instance
./host-scripts/create-wp-instance.sh remove <name>     # Delete instance (permanent!)
```

### Container Operations

```bash
docker logs <container-name>                            # View logs
docker exec -it <container-name> bash                   # Shell access
docker exec <container> wp core version                 # WP-CLI commands
```

### Schema System Operations

```bash
# List all schemas
docker exec <container> wp schema list --allow-root

# Validate schema syntax
docker exec <container> wp schema validate <post-type> --allow-root

# Register schema in WordPress
docker exec <container> wp schema register --post_type=<type> --allow-root

# Export TypeScript types
docker exec <container> wp schema export <post-type> \
  --output=/home/flexy/workspace/frontend/src/types \
  --allow-root

# Export all schemas
docker exec <container> wp schema export-all \
  --output=/home/flexy/workspace/frontend/src/types \
  --allow-root
```

### AI Operations

```bash
# Generate alt text for all images
docker exec <container> wp ignis-ai generate-alt-text --allow-root

# Generate content for specific field
docker exec <container> wp ignis-ai generate-content <post-id> <field-name> \
  --prompt="Generate compelling description" \
  --allow-root

# Generate ACF field group from description
docker exec <container> wp ignis-ai generate-form \
  "Product fields: name, price, SKU, description" \
  --post-type=product \
  --title="Product Information" \
  --allow-root
```

## Key Files and Their Roles

- **`docker/init.sh`**: Container entrypoint, handles persistent vs ephemeral WordPress detection
- **`host-scripts/create-wp-instance.sh`**: WordPress instance lifecycle manager (17KB, 500+ lines)
- **`host-scripts/create-ignis-sandbox.sh`**: General sandbox creator with `--wp-instance` support
- **`docker/Dockerfile`**: Installs WordPress + SQLite plugin, creates `db.php` from template
- **`~/.ignistack-instances/<name>/`**: Host directories containing persistent WordPress data (centralized location)

## Critical Implementation Details

### Database File Locations

- SQLite database: `wp-content/database/.ht.sqlite` (note the leading dot!)
- Instance metadata: `.instance-info` in instance root
- Documentation says `.ht.sqlite` consistently (not `wp-site.db` or other variants)

### Volume Mounting Pattern

```bash
# Persistent WordPress volume
-v $(pwd)/wordpress-instances/<name>:/home/flexy/wordpress-persistent

# Workspace volume (optional)
-v /host/path:/home/flexy/workspace

# Environment variables
-e WP_INSTANCE_NAME=<name>
-e ENABLE_WEBTTY=true
```

### Port Configuration

Instances support custom port mapping:
- WordPress: `--port 8080` → `-p 8080:80`
- WebTTY: `--ttyd-port 9681` → `-p 9681:9681`
- CoSpec AI: `--cospec-port 9280` → `-p 9280:9280`
- Firebase: `--firebase-port 5000` → `-p 5000:5000` and `-p 5001:5001`

### Container Naming Convention

Format: `ignistack-wp-<instance-name>`

Example: Instance "dev" → Container "ignistack-wp-dev"

## WordPress + SQLite Constraints

### Known Compatibility Issues

- **Jetpack**: Import failures (constraint violations)
- **Wordfence**: BLOB column incompatibilities
- **Large concurrent writes**: SQLite uses database-level locking

### When SQLite Integration Fails

1. Check `db.php` has correct plugin path (not literal `{SQLITE_IMPLEMENTATION_FOLDER_PATH}`)
2. Verify `wp-config.php` uses `__DIR__` not hardcoded paths
3. Check container logs for "version.php" or "constants.php" errors
4. Ensure SQLite plugin installed at: `wp-content/plugins/sqlite-database-integration/`

### Race Condition Fix (Container Startup)

```bash
# docker/init.sh must create log file before tailing
touch /home/flexy/wordpress.log
php -S 0.0.0.0:80 -t $WORDPRESS_DIR > /home/flexy/wordpress.log 2>&1 &
sleep 2
tail -f /home/flexy/wordpress.log  # Now file exists
```

## Instance Metadata Structure

`.instance-info` format:
```bash
INSTANCE_NAME=dev
CREATED_AT="2025-10-29 06:57:02"
WP_PORT=8080
TTYD_PORT=9681
COSPEC_PORT=9280
FIREBASE_PORT=5000
MOUNT_PATH=/path/to/code  # Optional
```

## Troubleshooting Checklist

### "WordPress shows installation screen every time"
- Check persistent volume is mounted: `docker inspect <container> | grep wordpress-persistent`
- Verify wp-config.php exists: `ls wordpress-instances/<name>/wp-config.php`

### "Parse error in wp-config.php"
- Used `EOL` instead of `'EOL'` in heredoc, causing bash variable expansion
- PHP variables like `$table_prefix` got interpreted as bash variables

### "Fatal error: Failed opening required '/home/flexy/version.php'"
- Copied `wp-includes/sqlite/db.php` directly instead of using `db.copy` template
- Plugin files not properly installed or paths not replaced in template

### "Port already allocated"
- Another container using the same port
- Stop containers: `docker stop $(docker ps -q --filter name=ignistack)`
- Use different port: `--port 8081` or `--firebase-port 5010`

### Container exits immediately
- Check for syntax errors: `docker logs <container>`
- Common: log file race condition (fixed by touching file first)

## Development Workflow

### Adding New WordPress Instance Features

1. Modify `docker/init.sh` for container-side logic
2. Update `host-scripts/create-wp-instance.sh` for host-side management
3. Rebuild image: `./host-scripts/build-docker.sh`
4. Test with new instance: `./host-scripts/create-wp-instance.sh create test-feature`

### Modifying SQLite Integration

1. Changes to `db.php`: Edit `db.copy` template in Dockerfile, not runtime
2. Changes to wp-config.php: Edit heredoc in `docker/init.sh`
3. Always use `'EOL'` (quoted) for heredocs containing PHP code
4. Test both first-run (new instance) and existing instance scenarios

### Testing Multiple Instances

```bash
# Create multiple instances with different ports
./host-scripts/create-wp-instance.sh create dev --port 8080
./host-scripts/create-wp-instance.sh create test --port 8081 --ttyd-port 9691
./host-scripts/create-wp-instance.sh create staging --port 8082 --ttyd-port 9701

# Verify all running
./host-scripts/create-wp-instance.sh list
```

## Documentation Structure

- **README.md**: Complete IgniStack overview, quick start, feature showcase, single source of truth (662 lines)
- **docs/WORDPRESS-INSTANCES.md**: Comprehensive instance management guide (770 lines)
- **docs/SQLITE-INTEGRATION.md**: Technical SQLite integration details, critical issues (442 lines)
- **docs/SCHEMA-SYSTEM-INTEGRATION.md**: ignis-schema-wp integration and usage guide (613 lines)
- **docs/AI-INTEGRATION.md**: ignis-ai plugin features and workflow (434 lines)

Refer users to appropriate doc based on their question:
- Overview & getting started → README.md
- Instance management → WORDPRESS-INSTANCES.md
- SQLite errors/config → SQLITE-INTEGRATION.md
- Schema system setup → SCHEMA-SYSTEM-INTEGRATION.md
- AI features → AI-INTEGRATION.md

## Environment Variables Reference

- `WP_INSTANCE_NAME`: Triggers persistent WordPress mode
- `WORDPRESS_DIR`: Set by init.sh, determines which WordPress to serve
- `OPENAI_API_KEY`: IgnisAI plugin API access (Claude via OpenAI compatibility)
- `ANTHROPIC_AUTH_TOKEN`: Claude Code CLI API access
- `FIREBASE_TOKEN`: Firebase CLI authentication
- `ENABLE_WEBTTY`: Starts ttyd web terminal
- `MARKDOWN_DIR`: CoSpec AI workspace (default: `/home/flexy/workspace`)

**Note**: `WORDPRESS_DB_*` variables no longer used (SQLite replaces MySQL)
