# Multi-stage build for IgniStack Dev Sandbox (React + Firebase + WordPress with SQLite)
# Extends the base Flexy Dev Sandbox image with IgniStack specific tools
FROM flexy-dev-sandbox

# Set environment variables to avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Configure timezone data to avoid interactive prompts
RUN sudo ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ | sudo tee /etc/timezone

# Install PHP and WordPress specific dependencies with SQLite support
RUN sudo apt-get update && sudo apt-get install -y \
    tzdata \
    php8.1 \
    php8.1-sqlite3 \
    php8.1-curl \
    php8.1-xml \
    php8.1-mbstring \
    php8.1-zip \
    sqlite3 \
    unzip \
    && sudo rm -rf /var/lib/apt/lists/*

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

# Clone the custom sync-fire-wp plugin
RUN git clone https://github.com/misterlex223/sync-fire-wp.git /home/flexy/wordpress/wp-content/plugins/sync-fire-wp

# Setup project directory
WORKDIR /home/flexy/workspace

# Setup basic git config
# RUN git config --global user.name "Flexy" && \
#     git config --global user.email "flexy@example.com"

# Copy and set up IgniStack specific init script
COPY docker/init.sh /tmp/init-ignistack.sh
RUN sudo mv /tmp/init-ignistack.sh /usr/local/bin/init-ignistack.sh && \
    sudo chmod +x /usr/local/bin/init-ignistack.sh

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