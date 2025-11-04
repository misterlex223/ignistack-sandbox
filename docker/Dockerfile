# Multi-stage build for IgniStack Dev Sandbox (React + Firebase + WordPress with SQLite)
# Extends the base Flexy Dev Sandbox image with IgniStack specific tools
FROM ghcr.io/misterlex223/flexy-sandbox:latest

# Set environment variables to avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Configure timezone data to avoid interactive prompts
RUN sudo ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ | sudo tee /etc/timezone

# Install PHP and WordPress specific dependencies with SQLite support
RUN sudo apt-get update && sudo apt-get install -y \
    tzdata \
    sqlite3 \
    unzip \
    libyaml-dev \
    && sudo rm -rf /var/lib/apt/lists/*

# Install YAML, gRPC, and Protobuf PHP extensions
# Strategy: Use pre-built packages from ondrej/php PPA which includes php-grpc
RUN sudo apt-get update && \
    # Add ondrej/php PPA which has pre-compiled php-grpc packages
    sudo add-apt-repository -y ppa:ondrej/php && \
    sudo apt-get update && \
    # Install pre-compiled extensions (MUCH faster than PECL compilation)
    sudo apt-get install -y php-yaml php-protobuf \
        php8.4 \
        php8.4-grpc \
        php8.4-sqlite3 \
        php8.4-curl \
        php8.4-xml \
        php8.4-mbstring \
        php8.4-zip \
        php8.4-dev && \
    sudo apt-get remove -y zlib1g-dev build-essential && \
    sudo apt-get autoremove -y && \
    sudo rm -rf /var/lib/apt/lists/*

# Install WordPress CLI
RUN curl -s -o /tmp/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x /tmp/wp-cli.phar && \
    sudo mv /tmp/wp-cli.phar /usr/local/bin/wp

# Install IgniStack specific global npm packages (Firebase tools)
RUN npm install -g firebase-tools

# Prepare WordPress directory
WORKDIR /home/flexy
RUN mkdir -p wordpress

# Download latest WordPress
RUN wget https://wordpress.org/latest.tar.gz && \
    tar -xzf latest.tar.gz -C /home/flexy/wordpress --strip-components=1 && \
    rm latest.tar.gz

# Create schemas directory
RUN mkdir -p /home/flexy/wordpress/wp-content/schemas/post-types

# Install the WordPress SQLite Database Integration plugin properly
RUN git clone https://github.com/WordPress/sqlite-database-integration.git /tmp/sqlite-plugin && \
    # Create plugin directory
    mkdir -p /home/flexy/wordpress/wp-content/plugins/sqlite-database-integration && \
    # Copy plugin files to the plugins directory
    cp -r /tmp/sqlite-plugin/* /home/flexy/wordpress/wp-content/plugins/sqlite-database-integration/ && \
    # Use db.copy template and replace placeholders to create the drop-in
    sed 's|{SQLITE_IMPLEMENTATION_FOLDER_PATH}|/home/flexy/wordpress/wp-content/plugins/sqlite-database-integration|g; s|{SQLITE_PLUGIN}|sqlite-database-integration/load.php|g' \
        /tmp/sqlite-plugin/db.copy > /home/flexy/wordpress/wp-content/db.php && \
    # Create database directory for SQLite file
    mkdir -p /home/flexy/wordpress/wp-content/database && \
    rm -rf /tmp/sqlite-plugin

# Install Composer for PHP dependency management
RUN curl -sS https://getcomposer.org/installer | php && \
    sudo mv composer.phar /usr/local/bin/composer && \
    sudo chmod +x /usr/local/bin/composer

# Install Advanced Custom Fields plugin
RUN mkdir -p /home/flexy/wordpress/wp-content/plugins && \
    cd /tmp && \
    wget https://downloads.wordpress.org/plugin/advanced-custom-fields.zip && \
    unzip advanced-custom-fields.zip -d /home/flexy/wordpress/wp-content/plugins/ && \
    rm advanced-custom-fields.zip

# Clone the ignis-schema-wp plugin
RUN git clone https://github.com/misterlex223/ignis-schema-wp.git /tmp/ignis-schema-wp && \
    # Create plugin directory
    sudo mkdir -p /home/flexy/wordpress/wp-content/plugins/ignis-schema-wp && \
    # Move the actual plugin files from the subdirectory to the correct location
    sudo cp -r /tmp/ignis-schema-wp/ignis-schema-wp/* /home/flexy/wordpress/wp-content/plugins/ignis-schema-wp && \
    # Clean up temp directory
    rm -rf /tmp/ignis-schema-wp

# Clone the custom sync-fire-wp plugin and install dependencies
RUN git clone https://github.com/misterlex223/sync-fire-wp.git /tmp/sync-fire-wp && \
    # Create plugin directory
    mkdir -p /home/flexy/wordpress/wp-content/plugins/sync-fire-wp && \
    # Move the actual plugin files from the subdirectory to the correct location
    cp -r /tmp/sync-fire-wp/sync-fire-wp/* /home/flexy/wordpress/wp-content/plugins/sync-fire-wp && \
    # Install Composer dependencies
    cd /home/flexy/wordpress/wp-content/plugins/sync-fire-wp && \
    composer install --no-dev --optimize-autoloader && \
    # Clean up temp directory
    rm -rf /tmp/sync-fire-wp

# Install IgnisAI plugin
COPY docker/plugins/ignis-ai /home/flexy/wordpress/wp-content/plugins/ignis-ai
RUN sudo chown -R flexy:flexy /home/flexy/wordpress/wp-content/plugins/ignis-ai && \
    cd /home/flexy/wordpress/wp-content/plugins/ignis-ai && \
    composer install --no-dev --optimize-autoloader

# Setup project directory
WORKDIR /home/flexy/workspace

# Create docs directory and copy documentation
RUN mkdir -p /home/flexy/docs

# Setup basic git config
# RUN git config --global user.name "Flexy" && \
#     git config --global user.email "flexy@example.com"

# Copy and set up IgniStack specific init script
COPY docker/init.sh /tmp/init-ignistack.sh
RUN sudo mv /tmp/init-ignistack.sh /usr/local/bin/init-ignistack.sh && \
    sudo chmod +x /usr/local/bin/init-ignistack.sh

# Copy documentation files to container
COPY docs/ACF-LLM.md /home/flexy/docs/ACF-LLM.md

# Create start/stop scripts for WordPress
COPY container-scripts/start-wp.sh /tmp/start-wp.sh
COPY container-scripts/stop-wp.sh /tmp/stop-wp.sh
RUN sudo mv /tmp/start-wp.sh /home/flexy/start-wp.sh && \
    sudo mv /tmp/stop-wp.sh /home/flexy/stop-wp.sh && \
    sudo chmod +x /home/flexy/start-wp.sh /home/flexy/stop-wp.sh

# Expose ports
EXPOSE 80 9681 9280 5000 5001 8080

# Set environment variables specific to IgniStack
ENV MARKDOWN_DIR="/home/flexy/workspace"
ENV WORKING_DIRECTORY="/home/flexy/workspace"

# Override the base image's entrypoint to use the IgniStack extension script
ENTRYPOINT ["/usr/local/bin/init-ignistack.sh"]