#!/bin/bash

# IgniStack Sandbox Extension Script
# Extends the base Flexy Dev Sandbox with IgniStack (React + Firebase + WordPress with SQLite) capabilities

# Configure timezone at runtime if TZ environment variable is set
if [ -n "$TZ" ] && [ "$TZ" != "Etc/UTC" ]; then
    echo "Configuring timezone: $TZ"
    sudo ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
    echo $TZ | sudo tee /etc/timezone > /dev/null

    # Update PHP timezone configuration
    PHP_INI_DIR=$(php -r "echo PHP_CONFIG_FILE_SCAN_DIR;")
    if [ -d "$PHP_INI_DIR" ]; then
        echo "date.timezone = $TZ" | sudo tee $PHP_INI_DIR/99-timezone.ini > /dev/null
        echo "PHP timezone configured: $TZ"
    fi
fi

# Set working directory for IgniStack projects
export WORKING_DIRECTORY=${WORKING_DIRECTORY:-/home/flexy/workspace}

# Create IgniStack specific directory structure
echo "Setting up IgniStack project structure..."
mkdir -p /home/flexy/workspace

# Check if using external WordPress volume for persistence
if [ -n "$WP_INSTANCE_NAME" ] && [ -d "/home/flexy/wordpress-persistent" ]; then
    echo "Using persistent WordPress instance: $WP_INSTANCE_NAME"

    # If WordPress doesn't exist in persistent volume, copy from base installation
    if [ ! -f "/home/flexy/wordpress-persistent/wp-config.php" ]; then
        echo "Initializing new WordPress instance..."
        cp -r /home/flexy/wordpress/* /home/flexy/wordpress-persistent/

        # Create SQLite database directory
        mkdir -p /home/flexy/wordpress-persistent/wp-content/database

        echo "WordPress instance '$WP_INSTANCE_NAME' initialized"
    else
        echo "WordPress instance '$WP_INSTANCE_NAME' already exists, using existing data"
    fi

    # Use the persistent WordPress directory
    export WORDPRESS_DIR="/home/flexy/wordpress-persistent"
else
    echo "Using ephemeral WordPress instance (will be lost when container stops)"
    mkdir -p /home/flexy/wordpress
    mkdir -p /home/flexy/wordpress/wp-content/plugins
    mkdir -p /home/flexy/wordpress/wp-content/database
    export WORDPRESS_DIR="/home/flexy/wordpress"
fi

# Ensure git configuration is set (if not already set by base Flexy image)
if ! git config --global --get user.name > /dev/null 2>&1; then
    echo "Setting up Git configuration..."
    git config --global user.name "Flexy Developer"
    git config --global user.email "flexy@example.com"
fi

# The db.php drop-in is already installed by the Dockerfile from the official plugin
# No need to create a custom db.php here - the plugin's official drop-in will handle everything

# Check if wp-config.php already exists, if not create it for SQLite
if [ ! -f "$WORDPRESS_DIR/wp-config.php" ]; then
    echo "Creating wp-config.php for SQLite..."
    # Create a basic wp-config.php that works with SQLite
    cat > "$WORDPRESS_DIR/wp-config.php" << 'EOL'
<?php
// SQLite Database Configuration
define( 'DB_ENGINE', 'sqlite' );
define( 'DB_DIR', __DIR__ . '/wp-content/database' );
define( 'DB_FILE', '.ht.sqlite' );

// Database charset and collation
define( 'DB_CHARSET', 'utf8mb4' );
define( 'DB_COLLATE', '' );

// Set up authentication keys and salts
define( 'AUTH_KEY',         'cA2bR5k8J3vP7yE4sG9zN6mL1oH3qT6wB5nR8yU2aI7oL4pE9cW3sX6zJ1uM9oR5' );
define( 'SECURE_AUTH_KEY',  'xK7nQ2wE8rP5yT3uI6oL9pA4sG1zX2cV5bN8mQ9rH6eY3tU7iP0oL6aS4dF1gH9' );
define( 'LOGGED_IN_KEY',    'vM3nR7yT9uI4oL2pE6aS8dF0gH5jK1lP3oY6uT9iR2eW5qZ8xM1cV4bN7mQ0pL3' );
define( 'NONCE_KEY',        'pL4qA7sD0fG3hJ6kM9nR2tY5uI8oP1aS4wE7rT0yU3iO6pL9aS2dF5gH8jK1mN4' );
define( 'AUTH_SALT',        'tU7iO2pL5aS8dF1gH4jK7mN0qR3eT6yY9uI2oP5aS8wE1rT4yU7iO0pL3aS6dF9' );
define( 'SECURE_AUTH_SALT', 'iO6pL9aS2dF5gH8jK1mN4qR7eT0yY3uI6oP9aS2wE5rT8yU1iO4pL7aS0dF3gH6' );
define( 'LOGGED_IN_SALT',   'oP5aS8wE1rT4yU7iO0pL3aS6dF9gH2jK5mN8qR1eT4yY7uI0oP3aS6wE9rT2yU5' );
define( 'NONCE_SALT',       'aS3dF6gH9jK2mN5qR8eT1yY4uI7oP0aS3wE6rT9yU2iO5pL8aS1dF4gH7jK0mN3' );

$table_prefix = 'wp_';

define( 'WP_DEBUG', false );

/* That's all, stop editing! */
if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', dirname( __FILE__ ) . '/' );
}

require_once ABSPATH . 'wp-settings.php';
EOL
fi

# Create the SQLite database file if it doesn't exist
if [ ! -f "$WORDPRESS_DIR/wp-content/database/.ht.sqlite" ]; then
    # Create a proper SQLite database file
    sqlite3 $WORDPRESS_DIR/wp-content/database/.ht.sqlite "VACUUM;"
    chmod 664 $WORDPRESS_DIR/wp-content/database/.ht.sqlite
    echo "SQLite database initialized."
fi

# Auto-update GitHub plugins if enabled (development mode)
# Note: This happens BEFORE WordPress initialization to ensure fresh plugins
if [ "$AUTO_UPDATE_PLUGINS" = "true" ] || [ "$AUTO_UPDATE_PLUGINS" = "1" ]; then
    echo "=========================================="
    echo "Auto-updating GitHub plugins (development mode)..."
    echo "=========================================="

    # Strategy:
    # 1. If persistent instance will be used, update base WordPress first
    #    (so when it's copied to persistent, it has latest plugins)
    # 2. If persistent instance already exists, update it directly
    # 3. If ephemeral, update base WordPress

    if [ -n "$WP_INSTANCE_NAME" ] && [ -d "/home/flexy/wordpress-persistent" ]; then
        # Persistent instance mode
        if [ -f "/home/flexy/wordpress-persistent/wp-config.php" ]; then
            # Persistent instance already exists - update it directly
            echo "Updating plugins in existing persistent instance..."
            UPDATE_DIR="/home/flexy/wordpress-persistent"
        else
            # First-time setup - update base, then it will be copied
            echo "Updating plugins in base WordPress (will be copied to persistent)..."
            UPDATE_DIR="/home/flexy/wordpress"
        fi
    else
        # Ephemeral mode - update base WordPress
        echo "Updating plugins in base WordPress (ephemeral mode)..."
        UPDATE_DIR="/home/flexy/wordpress"
    fi

    # Export for the update script
    export WORDPRESS_DIR="$UPDATE_DIR"

    if command -v update-github-plugins.sh &> /dev/null; then
        update-github-plugins.sh dev || echo "Warning: Plugin update failed but continuing..."
    else
        echo "Warning: update-github-plugins.sh not found, skipping auto-update"
    fi

    # Restore WORDPRESS_DIR to the value set by the logic above (lines 14-38)
    if [ -n "$WP_INSTANCE_NAME" ] && [ -d "/home/flexy/wordpress-persistent" ]; then
        export WORDPRESS_DIR="/home/flexy/wordpress-persistent"
    else
        export WORDPRESS_DIR="/home/flexy/wordpress"
    fi
    echo "=========================================="
fi

# Check if WordPress is already installed by checking for wp-config.php
if [ ! -f "$WORDPRESS_DIR/wp-config.php" ] || [ ! -f "$WORDPRESS_DIR/wp-settings.php" ]; then
    echo "WordPress not found in $WORDPRESS_DIR. Copying from base installation..."
    cp -r /home/flexy/wordpress/* $WORDPRESS_DIR/
    
    # Create SQLite database directory if it doesn't exist
    mkdir -p $WORDPRESS_DIR/wp-content/database
    
    # Create wp-config.php for SQLite if it doesn't exist
    if [ ! -f "$WORDPRESS_DIR/wp-config.php" ]; then
        echo "Creating wp-config.php for SQLite..."
        cat > "$WORDPRESS_DIR/wp-config.php" << 'EOL'
<?php
// SQLite Database Configuration
define( 'DB_ENGINE', 'sqlite' );
define( 'DB_DIR', __DIR__ . '/wp-content/database' );
define( 'DB_FILE', '.ht.sqlite' );

// Database charset and collation
define( 'DB_CHARSET', 'utf8mb4' );
define( 'DB_COLLATE', '' );

// Set up authentication keys and salts
define( 'AUTH_KEY',         'cA2bR5k8J3vP7yE4sG9zN6mL1oH3qT6wB5nR8yU2aI7oL4pE9cW3sX6zJ1uM9oR5' );
define( 'SECURE_AUTH_KEY',  'xK7nQ2wE8rP5yT3uI6oL9pA4sG1zX2cV5bN8mQ9rH6eY3tU7iP0oL6aS4dF1gH9' );
define( 'LOGGED_IN_KEY',    'vM3nR7yT9uI4oL2pE6aS8dF0gH5jK1lP3oY6uT9iR2eW5qZ8xM1cV4bN7mQ0pL3' );
define( 'NONCE_KEY',        'pL4qA7sD0fG3hJ6kM9nR2tY5uI8oP1aS4wE7rT0yU3iO6pL9aS2dF5gH8jK1mN4' );
define( 'AUTH_SALT',        'tU7iO2pL5aS8dF1gH4jK7mN0qR3eT6yY9uI2oP5aS8wE1rT4yU7iO0pL3aS6dF9' );
define( 'SECURE_AUTH_SALT', 'iO6pL9aS2dF5gH8jK1mN4qR7eT0yY3uI6oP9aS2wE5rT8yU1iO4pL7aS0dF3gH6' );
define( 'LOGGED_IN_SALT',   'oP5aS8wE1rT4yU7iO0pL3aS6dF9gH2jK5mN8qR1eT4yY7uI0oP3aS6wE9rT2yU5' );
define( 'NONCE_SALT',       'aS3dF6gH9jK2mN5qR8eT1yY4uI7oP0aS3wE6rT9yU2iO5pL8aS1dF4gH7jK0mN3' );

$table_prefix = 'wp_';

define( 'WP_DEBUG', false );

/* That's all, stop editing! */
if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', dirname( __FILE__ ) . '/' );
}

require_once ABSPATH . 'wp-settings.php';
EOL
    fi
fi

# Create the SQLite database file if it doesn't exist
if [ ! -f "$WORDPRESS_DIR/wp-content/database/.ht.sqlite" ]; then
    # Create a proper SQLite database file
    sqlite3 $WORDPRESS_DIR/wp-content/database/.ht.sqlite "VACUUM;"
    chmod 664 $WORDPRESS_DIR/wp-content/database/.ht.sqlite
    echo "SQLite database initialized."
fi

# Show IgniStack specific information
echo "==========================================="
echo "IgniStack Development Environment Ready"
echo "==========================================="
echo "Additional tools available in IgniStack:"
echo "- Firebase CLI (firebase)"
echo "- WP-CLI (wp) for WordPress management"
echo "- PHP 8.4 with SQLite3 support"
echo "- sync-fire-wp plugin for WordPress-Firestore sync"
echo ""
echo "Key directories:"
echo "- WordPress installation: $WORDPRESS_DIR"
echo "- SQLite database: $WORDPRESS_DIR/wp-content/database/.ht.sqlite"
echo "- Project directory: $WORKING_DIRECTORY"
if [ -n "$WP_INSTANCE_NAME" ]; then
    echo "- WordPress instance: $WP_INSTANCE_NAME (persistent)"
else
    echo "- WordPress instance: ephemeral (not persistent)"
fi
echo ""
echo "IgniStack workflows:"
echo "- WordPress server will auto-start on port 80"
echo "- Start Firebase Emulator: firebase emulators:start" 
echo "- Setup WordPress: Visit http://localhost and complete installation"
echo "- Enable WordPress-Firestore sync: Activate 'sync-fire-wp' plugin in wp-admin"
echo "==========================================="

# Start the base environment setup first (which sets up all other services)
echo "Starting base environment..."
/usr/local/bin/init.sh "$@" &

# Wait a bit for the base environment to initialize
sleep 5

# Check if WordPress is installed (wp-config.php exists) and install if needed
if [ ! -f "$WORDPRESS_DIR/wp-config.php" ] || [ ! -f "$WORDPRESS_DIR/wp-settings.php" ]; then
    echo "Error: WordPress files not found in $WORDPRESS_DIR"
    exit 1
fi

# Check if WordPress is installed by checking if tables exist in the database
DB_FILE="$WORDPRESS_DIR/wp-content/database/.ht.sqlite"
if [ -f "$DB_FILE" ]; then
    TABLES_EXIST=$(sqlite3 "$DB_FILE" "SELECT name FROM sqlite_master WHERE type='table';" | grep -c "wp_users")
else
    TABLES_EXIST=0
fi

if [ "$TABLES_EXIST" -eq 0 ]; then
    echo "WordPress not installed. Installing WordPress with default settings..."
    
    # Determine the site URL based on environment variable or use localhost with default port 80
    # The host script can pass the external port via environment variable
    if [ -n "$WORDPRESS_SITE_URL" ]; then
        # Normalize the URL by removing port 80 if specified since it's the default HTTP port
        if [ "$WORDPRESS_SITE_URL" = "http://localhost:80" ] || [ "$WORDPRESS_SITE_URL" = "https://localhost:80" ]; then
            SITE_URL="http://localhost"
        elif [[ "$WORDPRESS_SITE_URL" =~ ^https://localhost:80$ ]]; then
            SITE_URL="https://localhost"
        else
            SITE_URL="$WORDPRESS_SITE_URL"
        fi
    else
        # If PORT environment variable is set (by host scripts), use it; otherwise default to 80
        EXTERNAL_PORT="${PORT:-80}"
        if [ "$EXTERNAL_PORT" = "80" ]; then
            SITE_URL="http://localhost"
        else
            SITE_URL="http://localhost:$EXTERNAL_PORT"
        fi
    fi
    
    echo "Installing WordPress with site URL: $SITE_URL"
    wp core install --path="$WORDPRESS_DIR" --url="$SITE_URL" --title="IgniStack Sandbox" --admin_user=admin --admin_password=password123 --admin_email=admin@example.com --skip-email
    if [ $? -eq 0 ]; then
        echo "WordPress installed successfully."
    
        # Set permalink structure to 'post name' to enable proper REST API access at /wp-json/
        echo "Setting permalink structure to 'post name'..."
        wp option update permalink_structure '/%postname%/' --path="$WORDPRESS_DIR"
        if [ $? -eq 0 ]; then
            echo "Permalink structure set successfully."
        else
            echo "Failed to set permalink structure."
        fi
    fi
else
    echo "WordPress is already installed."
    
    # Update the site URL if it's different from what's configured
    if [ -n "$WORDPRESS_SITE_URL" ]; then
        # Normalize the URL by removing port 80 if specified since it's the default HTTP port
        if [ "$WORDPRESS_SITE_URL" = "http://localhost:80" ] || [ "$WORDPRESS_SITE_URL" = "https://localhost:80" ]; then
            NORMALIZED_SITE_URL="http://localhost"
        elif [[ "$WORDPRESS_SITE_URL" =~ ^https://localhost:80$ ]]; then
            NORMALIZED_SITE_URL="https://localhost"
        else
            NORMALIZED_SITE_URL="$WORDPRESS_SITE_URL"
        fi
        
        CURRENT_SITE_URL=$(wp option get siteurl --path="$WORDPRESS_DIR" 2>/dev/null)
        if [ "$CURRENT_SITE_URL" != "$NORMALIZED_SITE_URL" ]; then
            echo "Updating site URL to: $NORMALIZED_SITE_URL"
            wp option update siteurl "$NORMALIZED_SITE_URL" --path="$WORDPRESS_DIR"
            wp option update home "$NORMALIZED_SITE_URL" --path="$WORDPRESS_DIR"
        fi
    else
        # If no explicit site URL is provided, ensure the port is properly configured
        EXTERNAL_PORT="${PORT:-80}"
        if [ "$EXTERNAL_PORT" = "80" ]; then
            EXPECTED_SITE_URL="http://localhost"
        else
            EXPECTED_SITE_URL="http://localhost:$EXTERNAL_PORT"
        fi
        
        CURRENT_SITE_URL=$(wp option get siteurl --path="$WORDPRESS_DIR" 2>/dev/null)
        if [ "$CURRENT_SITE_URL" != "$EXPECTED_SITE_URL" ]; then
            echo "Updating site URL to: $EXPECTED_SITE_URL"
            wp option update siteurl "$EXPECTED_SITE_URL" --path="$WORDPRESS_DIR"
            wp option update home "$EXPECTED_SITE_URL" --path="$WORDPRESS_DIR"
        fi
    fi
    
    # Ensure permalinks are set to 'post name' structure for proper REST API access
    CURRENT_PERMALINK=$(wp option get permalink_structure --path="$WORDPRESS_DIR" 2>/dev/null)
    if [ "$CURRENT_PERMALINK" != "/%postname%/" ]; then
        echo "Updating permalink structure to 'post name'..."
        wp option update permalink_structure '/%postname%/' --path="$WORDPRESS_DIR"
        if [ $? -eq 0 ]; then
            echo "Permalink structure updated successfully."
        else
            echo "Failed to update permalink structure."
        fi
    fi
fi

# Ensure the sync-fire-wp plugin is in the right location and activate it
PLUGIN_DIR="$WORDPRESS_DIR/wp-content/plugins/sync-fire-wp"
if [ -d "$PLUGIN_DIR/sync-fire-wp" ]; then
    # Move the actual plugin files up one level if they're nested
    cp -r "$PLUGIN_DIR/sync-fire-wp"/* "$PLUGIN_DIR/"
    rm -rf "$PLUGIN_DIR/sync-fire-wp"
    rm -f "$PLUGIN_DIR"/Dockerfile "$PLUGIN_DIR"/docker-compose.yml "$PLUGIN_DIR"/package-plugin.sh "$PLUGIN_DIR"/teardown-wp-dev.sh "$PLUGIN_DIR"/xdebug.ini.example "$PLUGIN_DIR"/.gitignore "$PLUGIN_DIR"/composer.json "$PLUGIN_DIR"/composer.lock "$PLUGIN_DIR"/README.md "$PLUGIN_DIR"/SETTINGS.md
    rm -rf "$PLUGIN_DIR"/docs
fi

# Check if sync-fire-wp plugin is available and activate it if not already active
if [ -f "$PLUGIN_DIR/sync-fire.php" ]; then
    PLUGIN_STATUS=$(wp plugin status sync-fire-wp --path="$WORDPRESS_DIR" 2>/dev/null | grep -o "Active")
    if [ -z "$PLUGIN_STATUS" ]; then
        echo "Activating sync-fire-wp plugin..."
        wp plugin activate sync-fire-wp --path="$WORDPRESS_DIR"
        if [ $? -eq 0 ]; then
            echo "sync-fire-wp plugin activated successfully."
        else
            echo "Failed to activate sync-fire-wp plugin."
        fi
    else
        echo "sync-fire-wp plugin is already active."
    fi
else
    echo "Warning: sync-fire-wp plugin not found at $PLUGIN_DIR/sync-fire.php"
fi

# Check if Advanced Custom Fields plugin is available and activate it if not already active
ACF_PLUGIN_DIR="$WORDPRESS_DIR/wp-content/plugins/advanced-custom-fields"
if [ -f "$ACF_PLUGIN_DIR/acf.php" ]; then
    ACF_PLUGIN_STATUS=$(wp plugin status advanced-custom-fields --path="$WORDPRESS_DIR" 2>/dev/null | grep -o "Active")
    if [ -z "$ACF_PLUGIN_STATUS" ]; then
        echo "Activating Advanced Custom Fields plugin..."
        wp plugin activate advanced-custom-fields --path="$WORDPRESS_DIR"
        if [ $? -eq 0 ]; then
            echo "Advanced Custom Fields plugin activated successfully."
        else
            echo "Failed to activate Advanced Custom Fields plugin."
        fi
    else
        echo "Advanced Custom Fields plugin is already active."
    fi
else
    echo "Warning: Advanced Custom Fields plugin not found at $ACF_PLUGIN_DIR/acf.php"
fi

# Check if ignis-schema-wp plugin is available and activate it if not already active
SCHEMA_PLUGIN_DIR="$WORDPRESS_DIR/wp-content/plugins/ignis-schema-wp"
if [ -f "$SCHEMA_PLUGIN_DIR/wordpress-schema-system.php" ]; then
    # Ensure ACF is active first (required dependency)
    if ! wp plugin is-active advanced-custom-fields --path="$WORDPRESS_DIR" 2>/dev/null; then
        echo "Activating ACF plugin (required dependency for schema system)..."
        wp plugin activate advanced-custom-fields --path="$WORDPRESS_DIR"
    fi

    SCHEMA_PLUGIN_STATUS=$(wp plugin status ignis-schema-wp --path="$WORDPRESS_DIR" 2>/dev/null | grep -o "Active")
    if [ -z "$SCHEMA_PLUGIN_STATUS" ]; then
        echo "Activating ignis-schema-wp plugin..."
        wp plugin activate ignis-schema-wp --path="$WORDPRESS_DIR"
        if [ $? -eq 0 ]; then
            echo "ignis-schema-wp plugin activated successfully."
        else
            echo "Failed to activate ignis-schema-wp plugin."
        fi
    else
        echo "ignis-schema-wp plugin is already active."
    fi

    # Copy example schemas if schemas directory is empty
    SCHEMAS_DIR="$WORDPRESS_DIR/wp-content/schemas/post-types"
    if [ -d "$SCHEMAS_DIR" ]; then
        SCHEMA_COUNT=$(ls -1 "$SCHEMAS_DIR" 2>/dev/null | wc -l)
        if [ "$SCHEMA_COUNT" -eq 0 ]; then
            echo "Copying example schemas..."
            PLUGIN_SCHEMAS_DIR="$SCHEMA_PLUGIN_DIR/schemas/post-types"
            if [ -d "$PLUGIN_SCHEMAS_DIR" ]; then
                cp "$PLUGIN_SCHEMAS_DIR"/*.yaml "$SCHEMAS_DIR/" 2>/dev/null || true
                cp "$PLUGIN_SCHEMAS_DIR"/*.yml "$SCHEMAS_DIR/" 2>/dev/null || true
                cp "$PLUGIN_SCHEMAS_DIR"/*.json "$SCHEMAS_DIR/" 2>/dev/null || true
                echo "Example schemas copied to $SCHEMAS_DIR"
            fi
        fi
    fi
else
    echo "Warning: ignis-schema-wp plugin not found at $SCHEMA_PLUGIN_DIR/wordpress-schema-system.php"
fi

# Check if ignis-ai plugin is available and activate it if not already active
IGNISAI_PLUGIN_DIR="$WORDPRESS_DIR/wp-content/plugins/ignis-ai"
if [ -f "$IGNISAI_PLUGIN_DIR/ignis-ai.php" ]; then
    # Ensure ACF is active first (recommended for full functionality)
    if ! wp plugin is-active advanced-custom-fields --path="$WORDPRESS_DIR" 2>/dev/null; then
        echo "Activating ACF plugin (recommended for IgnisAI)..."
        wp plugin activate advanced-custom-fields --path="$WORDPRESS_DIR"
    fi

    IGNISAI_PLUGIN_STATUS=$(wp plugin status ignis-ai --path="$WORDPRESS_DIR" 2>/dev/null | grep -o "Active")
    if [ -z "$IGNISAI_PLUGIN_STATUS" ]; then
        echo "Activating ignis-ai plugin..."
        wp plugin activate ignis-ai --path="$WORDPRESS_DIR"
        if [ $? -eq 0 ]; then
            echo "ignis-ai plugin activated successfully."

            # Configure API key from environment if available
            if [ -n "$OPENAI_API_KEY" ]; then
                echo "Configuring IgnisAI with OPENAI_API_KEY..."
                wp option update ignis_ai_enabled 1 --path="$WORDPRESS_DIR"
                wp option update ignis_ai_auto_alt_text 1 --path="$WORDPRESS_DIR"
                echo "IgnisAI configured successfully."
            else
                echo "Note: OPENAI_API_KEY not set. IgnisAI will need manual configuration."
            fi
        else
            echo "Failed to activate ignis-ai plugin."
        fi
    else
        echo "ignis-ai plugin is already active."
    fi
else
    echo "Warning: ignis-ai plugin not found at $IGNISAI_PLUGIN_DIR/ignis-ai.php"
fi

# Start WordPress server after the base environment is set up
echo "Starting WordPress server..."
cd $WORDPRESS_DIR

# Create log file first to avoid race condition
touch /home/flexy/wordpress.log

# Start PHP server in background, serving from the WordPress directory
php -S 0.0.0.0:80 -t $WORDPRESS_DIR > /home/flexy/wordpress.log 2>&1 &
WP_PID=$!
echo "WordPress server started on port 80 with PID $WP_PID (serving from $WORDPRESS_DIR)"

# Wait a moment for the server to start
sleep 2

# Keep the container running by tailing the log file
tail -f /home/flexy/wordpress.log