# WordPress SQLite Integration Guide

## Table of Contents
1. [Concept Overview](#concept-overview)
2. [Architecture & Design](#architecture--design)
3. [Implementation Methods](#implementation-methods)
4. [Critical Issues & Solutions](#critical-issues--solutions)
5. [Configuration Guide](#configuration-guide)
6. [Production Considerations](#production-considerations)

---

## Concept Overview

### What is WordPress SQLite Integration?

WordPress was originally designed to work exclusively with MySQL/MariaDB databases. The **WordPress SQLite Database Integration** plugin provides a database abstraction layer that allows WordPress to use SQLite instead of MySQL.

### Why Use SQLite with WordPress?

**Advantages:**
- **No separate database server required** - Single-file database
- **Portable** - Entire site in one directory
- **Simplified development** - Easy backup, clone, and restore
- **Lower resource footprint** - Perfect for development environments
- **Easy deployment** - No database server configuration needed

**Limitations:**
- **Not suitable for high-traffic production sites** - Limited concurrency
- **Plugin compatibility issues** - Some plugins expect MySQL-specific features
- **Performance constraints** - Slower with large datasets
- **Single writer at a time** - SQLite uses file-level locking

### Official Plugin

- **Repository:** https://github.com/WordPress/sqlite-database-integration
- **Status:** Beta/Experimental (October 2024)
- **Maintained by:** WordPress Performance Team
- **Goal:** Eventually integrate into WordPress core

---

## Architecture & Design

### WordPress Database Layer

```
┌─────────────────────────────────────┐
│     WordPress Application           │
└──────────────┬──────────────────────┘
               │
               ↓
┌─────────────────────────────────────┐
│  wp-includes/wp-db.php (MySQL)      │  ← Standard WordPress
│           OR                         │
│  wp-content/db.php (Drop-in)        │  ← SQLite Override
└──────────────┬──────────────────────┘
               │
               ↓
┌─────────────────────────────────────┐
│  SQLite Translation Layer           │
│  - Query Parser                      │
│  - SQL Translator (MySQL → SQLite)  │
│  - Result Formatter                  │
└──────────────┬──────────────────────┘
               │
               ↓
┌─────────────────────────────────────┐
│  SQLite Database File               │
│  (.ht.sqlite)                       │
└─────────────────────────────────────┘
```

### Drop-in Mechanism

WordPress supports "drop-ins" - special files in `wp-content/` that override core functionality:

- **Location:** `/wp-content/db.php`
- **Purpose:** Replace the default MySQL database class
- **Priority:** WordPress checks for `db.php` before loading `wp-includes/wp-db.php`

### Plugin Structure

```
wp-content/
├── db.php                           ← Drop-in file (generated from db.copy)
├── plugins/
│   └── sqlite-database-integration/
│       ├── load.php                 ← Main plugin entry
│       ├── activate.php             ← Activation handler
│       ├── db.copy                  ← Drop-in template
│       ├── version.php              ← Version constants
│       ├── constants.php            ← Configuration constants
│       └── wp-includes/
│           └── sqlite/
│               ├── db.php           ← Core SQLite implementation
│               ├── class-wp-sqlite-db.php
│               ├── class-wp-sqlite-translator.php
│               ├── class-wp-sqlite-lexer.php
│               └── ... (other classes)
└── database/
    └── .ht.sqlite                   ← SQLite database file
```

---

## Implementation Methods

### Method 1: Manual Installation (Recommended for Docker)

This is the approach used in ignistack-sandbox.

#### Step 1: Install Plugin Files

```dockerfile
# Clone the official plugin
RUN git clone https://github.com/WordPress/sqlite-database-integration.git /tmp/sqlite-plugin

# Copy to plugins directory
RUN mkdir -p /home/flexy/wordpress/wp-content/plugins/sqlite-database-integration && \
    cp -r /tmp/sqlite-plugin/* /home/flexy/wordpress/wp-content/plugins/sqlite-database-integration/
```

#### Step 2: Generate db.php Drop-in

**CRITICAL:** Do NOT copy `wp-includes/sqlite/db.php` directly to `wp-content/db.php`!

The plugin provides a **template file** `db.copy` with placeholders that must be replaced:

```dockerfile
# Use db.copy template and replace placeholders
RUN sed 's|{SQLITE_IMPLEMENTATION_FOLDER_PATH}|/home/flexy/wordpress/wp-content/plugins/sqlite-database-integration|g; \
         s|{SQLITE_PLUGIN}|sqlite-database-integration/load.php|g' \
    /tmp/sqlite-plugin/db.copy > /home/flexy/wordpress/wp-content/db.php
```

**What this does:**
- `{SQLITE_IMPLEMENTATION_FOLDER_PATH}` → Full path to plugin directory
- `{SQLITE_PLUGIN}` → Plugin activation path

#### Step 3: Create Database Directory

```dockerfile
RUN mkdir -p /home/flexy/wordpress/wp-content/database
```

#### Step 4: Configure wp-config.php

```php
<?php
// SQLite Database Configuration
define( 'DB_ENGINE', 'sqlite' );
define( 'DB_DIR', '/home/flexy/wordpress/wp-content/database' );
define( 'DB_FILE', '.ht.sqlite' );

// Database charset and collation
define( 'DB_CHARSET', 'utf8mb4' );
define( 'DB_COLLATE', '' );

// Authentication keys and salts (generate your own!)
define( 'AUTH_KEY', 'put your unique phrase here' );
// ... (other auth keys)

$table_prefix = 'wp_';

define( 'WP_DEBUG', false );

if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', dirname( __FILE__ ) . '/' );
}

require_once ABSPATH . 'wp-settings.php';
```

### Method 2: WordPress Admin Installation

1. Upload plugin to `/wp-content/plugins/sqlite-database-integration/`
2. Activate the plugin via WordPress admin
3. Plugin automatically creates the `db.php` drop-in
4. WordPress will use SQLite for future operations

**Note:** This method requires an existing WordPress installation with MySQL first.

---

## Critical Issues & Solutions

### Issue 1: Wrong db.php Source File ❌

**Problem:**
```dockerfile
# WRONG - This will fail!
cp /tmp/sqlite-plugin/db.php /home/flexy/wordpress/wp-content/db.php
```

**Error:**
```
cp: cannot stat '/tmp/sqlite-plugin/db.php': No such file or directory
```

**Why it fails:**
- No `db.php` exists at repository root
- The actual implementation is at `wp-includes/sqlite/db.php`
- That file is designed for core integration, not plugin-based installation

**Solution:** ✅
Use the `db.copy` template instead:
```dockerfile
cp /tmp/sqlite-plugin/db.copy /tmp/db.php
sed -i 's|{SQLITE_IMPLEMENTATION_FOLDER_PATH}|/full/path/to/plugin|g' /tmp/db.php
sed -i 's|{SQLITE_PLUGIN}|sqlite-database-integration/load.php|g' /tmp/db.php
cp /tmp/db.php /home/flexy/wordpress/wp-content/db.php
```

---

### Issue 2: Using wp-includes/sqlite/db.php Directly ❌

**Problem:**
```dockerfile
# WRONG - This will cause fatal errors!
cp /tmp/sqlite-plugin/wp-includes/sqlite/db.php /home/flexy/wordpress/wp-content/db.php
```

**Error:**
```
PHP Fatal error: Failed opening required '/home/flexy/version.php'
in /home/flexy/wordpress/wp-content/db.php on line 12
```

**Why it fails:**

The `wp-includes/sqlite/db.php` file contains:
```php
require_once dirname( __DIR__, 2 ) . '/version.php';
require_once dirname( __DIR__, 2 ) . '/constants.php';
```

When placed at `/wp-content/db.php`, it looks for files at:
- `dirname(__DIR__, 2)` = `/home/flexy/`
- Required: `/home/flexy/version.php` ❌ (doesn't exist)
- Required: `/home/flexy/constants.php` ❌ (doesn't exist)

**Actual locations:**
- `/wp-content/plugins/sqlite-database-integration/version.php` ✅
- `/wp-content/plugins/sqlite-database-integration/constants.php` ✅

**Solution:** ✅
Use `db.copy` which has correct relative path handling:
```php
$sqlite_plugin_implementation_folder_path = '/wp-content/plugins/sqlite-database-integration';
if ( ! file_exists( $sqlite_plugin_implementation_folder_path ) ) {
    $sqlite_plugin_implementation_folder_path = realpath( __DIR__ . '/plugins/sqlite-database-integration' );
}
require_once $sqlite_plugin_implementation_folder_path . '/wp-includes/sqlite/db.php';
```

---

### Issue 3: Missing wp-config.php Constants ❌

**Problem:**
```php
<?php
// Missing SQLite configuration
define( 'DB_CHARSET', 'utf8mb4' );
define( 'DB_COLLATE', '' );
```

**Why it fails:**
- WordPress doesn't know to use SQLite
- Database file location undefined
- Falls back to MySQL connection (which fails)

**Solution:** ✅
```php
<?php
// Tell WordPress to use SQLite
define( 'DB_ENGINE', 'sqlite' );
define( 'DB_DIR', '/full/path/to/wp-content/database' );
define( 'DB_FILE', '.ht.sqlite' );

define( 'DB_CHARSET', 'utf8mb4' );
define( 'DB_COLLATE', '' );
```

---

### Issue 4: Log File Race Condition ❌

**Problem:**
```bash
# Start PHP server and immediately tail log
php -S 0.0.0.0:80 > /home/flexy/wordpress.log 2>&1 &
tail -f /home/flexy/wordpress.log  # File might not exist yet!
```

**Error:**
```
tail: cannot open '/home/flexy/wordpress.log' for reading: No such file or directory
tail: no files remaining
```

**Why it fails:**
- PHP server starts in background (`&`)
- `tail` runs immediately before log file is created
- `tail -f` fails if file doesn't exist
- Container exits because main process failed

**Solution:** ✅
```bash
# Create log file first
touch /home/flexy/wordpress.log

# Start PHP server in background
php -S 0.0.0.0:80 > /home/flexy/wordpress.log 2>&1 &
WP_PID=$!

# Wait for server to start
sleep 2

# Now tail the log (file definitely exists)
tail -f /home/flexy/wordpress.log
```

---

### Issue 5: Placeholder Not Replaced ❌

**Problem:**
```php
// In db.php after copying db.copy without sed replacement
$sqlite_plugin_implementation_folder_path = '{SQLITE_IMPLEMENTATION_FOLDER_PATH}';
```

**Why it fails:**
- PHP treats `{SQLITE_IMPLEMENTATION_FOLDER_PATH}` as literal string
- Path doesn't exist: `/wp-content/plugins/{SQLITE_IMPLEMENTATION_FOLDER_PATH}/wp-includes/sqlite/db.php`
- SQLite integration fails to load

**Solution:** ✅
Always replace placeholders:
```bash
sed 's|{SQLITE_IMPLEMENTATION_FOLDER_PATH}|/actual/path|g;
     s|{SQLITE_PLUGIN}|sqlite-database-integration/load.php|g' \
    db.copy > db.php
```

---

### Issue 6: Database File Permissions ❌

**Problem:**
```bash
mkdir -p /home/flexy/wordpress/wp-content/database
# Directory created with wrong permissions
```

**Potential Error:**
```
SQLite: Unable to open database file
Warning: touch(): Permission denied
```

**Why it fails:**
- Web server user (www-data, flexy, etc.) needs write access
- Database directory must be writable
- Database file must be writable

**Solution:** ✅
```bash
mkdir -p /home/flexy/wordpress/wp-content/database
chmod 755 /home/flexy/wordpress/wp-content/database
# Database file will be created with proper permissions by PHP
```

For manual database creation:
```bash
sqlite3 /home/flexy/wordpress/wp-content/database/.ht.sqlite "VACUUM;"
chmod 664 /home/flexy/wordpress/wp-content/database/.ht.sqlite
chown www-data:www-data /home/flexy/wordpress/wp-content/database/.ht.sqlite
```

---

## Configuration Guide

### Minimal wp-config.php for SQLite

```php
<?php
// SQLite Configuration
define( 'DB_ENGINE', 'sqlite' );
define( 'DB_DIR', __DIR__ . '/wp-content/database' );
define( 'DB_FILE', '.ht.sqlite' );

// Charset
define( 'DB_CHARSET', 'utf8mb4' );
define( 'DB_COLLATE', '' );

// Security Keys (generate at: https://api.wordpress.org/secret-key/1.1/salt/)
define( 'AUTH_KEY',         'put your unique phrase here' );
define( 'SECURE_AUTH_KEY',  'put your unique phrase here' );
define( 'LOGGED_IN_KEY',    'put your unique phrase here' );
define( 'NONCE_KEY',        'put your unique phrase here' );
define( 'AUTH_SALT',        'put your unique phrase here' );
define( 'SECURE_AUTH_SALT', 'put your unique phrase here' );
define( 'LOGGED_IN_SALT',   'put your unique phrase here' );
define( 'NONCE_SALT',       'put your unique phrase here' );

// Table prefix
$table_prefix = 'wp_';

// Debugging
define( 'WP_DEBUG', false );

// Absolute path
if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', __DIR__ . '/' );
}

require_once ABSPATH . 'wp-settings.php';
```

### Advanced Configuration

```php
<?php
// SQLite Configuration with custom settings
define( 'DB_ENGINE', 'sqlite' );

// Custom database location (must be writable)
define( 'DB_DIR', '/var/lib/wordpress/database' );

// Custom database filename
define( 'DB_FILE', 'wordpress.db' );

// Enable WAL mode for better concurrency (optional)
define( 'SQLITE_USE_WAL_MODE', true );

// Enable foreign keys (optional)
define( 'SQLITE_FOREIGN_KEYS', true );

// Database timeout in milliseconds (optional)
define( 'SQLITE_BUSY_TIMEOUT', 5000 );
```

### Environment-Specific Configuration

```php
<?php
// Development
if ( defined( 'WP_ENV' ) && 'development' === WP_ENV ) {
    define( 'DB_ENGINE', 'sqlite' );
    define( 'DB_DIR', __DIR__ . '/wp-content/database' );
    define( 'DB_FILE', 'dev.sqlite' );
    define( 'WP_DEBUG', true );
}

// Production (use MySQL)
if ( defined( 'WP_ENV' ) && 'production' === WP_ENV ) {
    define( 'DB_NAME', 'wordpress_prod' );
    define( 'DB_USER', 'wp_user' );
    define( 'DB_PASSWORD', 'secure_password' );
    define( 'DB_HOST', 'mysql.example.com' );
    define( 'WP_DEBUG', false );
}
```

---

## Production Considerations

### When to Use SQLite

✅ **Good Use Cases:**
- Local development environments
- Staging/testing environments
- Small personal blogs (< 1000 visits/day)
- Documentation sites
- Portfolio websites
- Prototypes and demos
- CI/CD testing pipelines

❌ **Not Recommended For:**
- High-traffic production sites
- E-commerce sites with concurrent transactions
- Multi-author blogs with simultaneous editing
- Sites with heavy write operations
- Sites requiring horizontal scaling
- Multisite installations

### Performance Considerations

**Concurrency Limitations:**
```
MySQL/MariaDB:
- Multiple concurrent reads: ✅ Excellent
- Multiple concurrent writes: ✅ Good
- Reader/Writer locks: Fine-grained (row-level)

SQLite:
- Multiple concurrent reads: ✅ Good
- Multiple concurrent writes: ⚠️ Limited (one at a time)
- Reader/Writer locks: Coarse-grained (database-level)
```

**Database Size:**
- **< 100MB:** SQLite performs well
- **100MB - 1GB:** Acceptable for read-heavy workloads
- **> 1GB:** Consider MySQL for better performance

### Backup Strategy

**SQLite Advantages:**
```bash
# Simple file copy backup
cp /path/to/.ht.sqlite /backups/site-$(date +%Y%m%d).sqlite

# Zip entire WordPress directory
tar -czf wordpress-backup.tar.gz /path/to/wordpress/
```

**Important:**
- Backup entire `wp-content/database/` directory
- Use `sqlite3 .ht.sqlite ".backup backup.sqlite"` for consistent backups
- Stop writes during backup for data consistency

### Migration Paths

**SQLite → MySQL:**
1. Export data using WP All-in-One Migration plugin
2. Set up new WordPress with MySQL
3. Import data
4. Update wp-config.php
5. Remove SQLite plugin

**MySQL → SQLite:**
1. Install SQLite plugin on MySQL site
2. Activate plugin (creates db.php)
3. Export MySQL data
4. Configure wp-config.php for SQLite
5. Import data

### Plugin Compatibility

**Known Issues:**
- **Jetpack:** Import failures (constraint violations)
- **Wordfence:** BLOB column incompatibilities
- **WooCommerce:** Concurrency issues with orders

**Well-Supported Plugins:**
- **Advanced Custom Fields (ACF):** Works well with SQLite, included by default in IgniStack sandbox
  - Perfect for defining custom data structures
  - May be slower with very large datasets due to SQLite limitations
  - Full functionality preserved in development environments

**Testing Checklist:**
- [ ] Test all plugins in staging environment
- [ ] Monitor error logs for SQLite-specific issues
- [ ] Check Site Health page for compatibility warnings
- [ ] Verify critical workflows (checkout, forms, etc.)

### Monitoring & Debugging

**Enable Debug Mode:**
```php
define( 'WP_DEBUG', true );
define( 'WP_DEBUG_LOG', true );
define( 'WP_DEBUG_DISPLAY', false );
define( 'SCRIPT_DEBUG', true );
```

**Check SQLite Status:**
```bash
# Enter container
docker exec -it container-name bash

# Check database file
ls -lh /home/flexy/wordpress/wp-content/database/.ht.sqlite

# Query database
sqlite3 /home/flexy/wordpress/wp-content/database/.ht.sqlite "SELECT * FROM wp_options WHERE option_name = 'siteurl';"

# Check integrity
sqlite3 /home/flexy/wordpress/wp-content/database/.ht.sqlite "PRAGMA integrity_check;"
```

**Monitor Performance:**
```php
// Add to wp-config.php
define( 'SAVEQUERIES', true );

// Add to theme footer
if ( defined( 'SAVEQUERIES' ) && SAVEQUERIES ) {
    global $wpdb;
    echo "<!-- Total queries: " . count( $wpdb->queries ) . " -->";
    echo "<!-- Total time: " . array_sum( wp_list_pluck( $wpdb->queries, 1 ) ) . " -->";
}
```

---

## Troubleshooting

### Problem: WordPress Installation Fails

**Symptoms:**
- White screen during installation
- "Error establishing database connection"

**Check:**
1. Verify `db.php` exists: `ls -l /wp-content/db.php`
2. Check permissions: `ls -ld /wp-content/database/`
3. Review PHP error log: `tail -f /var/log/php-error.log`
4. Test SQLite extension: `php -m | grep sqlite`

### Problem: Database File Not Created

**Symptoms:**
- `/wp-content/database/.ht.sqlite` doesn't exist after installation

**Solutions:**
```bash
# Check directory permissions
chmod 755 /wp-content/database/

# Create file manually
touch /wp-content/database/.ht.sqlite
chmod 664 /wp-content/database/.ht.sqlite

# Initialize database
sqlite3 /wp-content/database/.ht.sqlite "VACUUM;"
```

### Problem: Plugin Activation Fails

**Symptoms:**
- "The plugin does not have a valid header"
- SQLite integration not working

**Solutions:**
1. Verify plugin structure:
```bash
wp-content/plugins/sqlite-database-integration/
├── load.php  # Must exist
├── db.copy
└── wp-includes/sqlite/db.php
```

2. Check `db.php` placeholder replacement:
```bash
grep '{SQLITE' /wp-content/db.php
# Should return nothing if properly replaced
```

### Problem: Query Syntax Errors

**Symptoms:**
- SQL errors in debug log
- Features not working

**Common Issues:**
- MySQL-specific syntax (e.g., `SHOW TABLES`)
- Unsupported functions (e.g., `FOUND_ROWS()`)
- Character set issues

**Solutions:**
- Update plugin to latest version
- Report issues to: https://github.com/WordPress/sqlite-database-integration/issues
- Use MySQL for problematic features

---

## Complete Working Example (Docker)

```dockerfile
# Dockerfile for WordPress with SQLite
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    php8.1 \
    php8.1-sqlite3 \
    php8.1-curl \
    php8.1-xml \
    php8.1-mbstring \
    php8.1-zip \
    sqlite3 \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Download WordPress
WORKDIR /var/www/html
RUN wget https://wordpress.org/latest.tar.gz && \
    tar -xzf latest.tar.gz --strip-components=1 && \
    rm latest.tar.gz

# Install SQLite plugin
RUN git clone https://github.com/WordPress/sqlite-database-integration.git /tmp/sqlite-plugin && \
    mkdir -p /var/www/html/wp-content/plugins/sqlite-database-integration && \
    cp -r /tmp/sqlite-plugin/* /var/www/html/wp-content/plugins/sqlite-database-integration/ && \
    sed 's|{SQLITE_IMPLEMENTATION_FOLDER_PATH}|/var/www/html/wp-content/plugins/sqlite-database-integration|g; \
         s|{SQLITE_PLUGIN}|sqlite-database-integration/load.php|g' \
        /tmp/sqlite-plugin/db.copy > /var/www/html/wp-content/db.php && \
    mkdir -p /var/www/html/wp-content/database && \
    rm -rf /tmp/sqlite-plugin

# Configure WordPress
RUN cat > /var/www/html/wp-config.php <<'EOF'
<?php
define( 'DB_ENGINE', 'sqlite' );
define( 'DB_DIR', '/var/www/html/wp-content/database' );
define( 'DB_FILE', '.ht.sqlite' );
define( 'DB_CHARSET', 'utf8mb4' );
define( 'DB_COLLATE', '' );

// Generate your own keys at: https://api.wordpress.org/secret-key/1.1/salt/
define( 'AUTH_KEY', 'put-your-unique-key-here' );
define( 'SECURE_AUTH_KEY', 'put-your-unique-key-here' );
define( 'LOGGED_IN_KEY', 'put-your-unique-key-here' );
define( 'NONCE_KEY', 'put-your-unique-key-here' );
define( 'AUTH_SALT', 'put-your-unique-key-here' );
define( 'SECURE_AUTH_SALT', 'put-your-unique-key-here' );
define( 'LOGGED_IN_SALT', 'put-your-unique-key-here' );
define( 'NONCE_SALT', 'put-your-unique-key-here' );

$table_prefix = 'wp_';
define( 'WP_DEBUG', false );

if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', __DIR__ . '/' );
}

require_once ABSPATH . 'wp-settings.php';
EOF

EXPOSE 80

CMD ["php", "-S", "0.0.0.0:80"]
```

**Build and Run:**
```bash
docker build -t wordpress-sqlite .
docker run -d -p 80:80 wordpress-sqlite
```

---

## References

- **Official Plugin:** https://github.com/WordPress/sqlite-database-integration
- **WordPress Drop-ins:** https://developer.wordpress.org/reference/functions/get_dropins/
- **SQLite Documentation:** https://www.sqlite.org/docs.html
- **WordPress Database Class:** https://developer.wordpress.org/reference/classes/wpdb/

---

## Summary of Critical Points

1. ✅ **Always use `db.copy` template**, not `wp-includes/sqlite/db.php`
2. ✅ **Replace placeholders** with actual paths using `sed`
3. ✅ **Define SQLite constants** in `wp-config.php`
4. ✅ **Pre-create log files** to avoid race conditions
5. ✅ **Set proper permissions** on database directory
6. ✅ **Test plugin compatibility** before production use
7. ⚠️ **Not suitable for high-traffic production** sites
8. ✅ **Perfect for development** environments

---

**Document Version:** 1.0
**Last Updated:** October 2024
**Based on:** WordPress 6.6.x + SQLite Integration Plugin 2.1.15
