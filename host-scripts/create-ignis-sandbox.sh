#!/bin/bash

# IgniStack Sandbox Creation Script
# Creates a Flexy sandbox container customized for React + Firebase + WordPress stack

set -e  # Exit on any error

# Function to display usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -n, --name NAME              Container name (default: ignistack-sandbox-<timestamp>)"
    echo "  -i, --image NAME             Image name (default: ignistack-dev-sandbox)"
    echo "  -p, --port PORT              Host port to expose (default: 8080)"
    echo "  -m, --mount PATH             Host path to mount to container (optional)"
    echo "  --workspace-path PATH        Container workspace path (default: /home/flexy/workspace)"
    echo "  -a, --anthropic-token TOKEN  Anthropic API token (optional)"
    echo "  -g, --github-token TOKEN     GitHub token (optional)"
    echo "  -f, --firebase-token TOKEN   Firebase token (optional)"
    echo "  -w, --wordpress-db-host HOST WordPress DB host (default: localhost)"
    echo "  --wp-db-user USER            WordPress DB user (default: root)"
    echo "  --wp-db-pass PASS            WordPress DB password (default: '')"
    echo "  --wp-db-name NAME            WordPress DB name (default: wordpress)"
    echo "  --wp-instance NAME           Create persistent WordPress instance"
    echo "  -t, --ttyd                   Expose ttyd port (port 9681)"
    echo "  -c, --cospec                 Expose CoSpec AI ports (ports 9280)"
    echo "  -s, --webtty                 Enable WebTTY mode"
    echo "  -h, --help                   Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --name igni-dev-env --mount /home/user/project --port 8081"
    echo "  $0 --anthropic-token your-token --firebase-token your-firebase-token --webtty"
    echo "  $0 --name igni-env --cospec --mount /home/user/ignistack-project --wordpress-db-host mysql-container"
}

# Check if any arguments were provided
if [[ $# -eq 0 ]]; then
    # Interactive mode - guide the user through setup
    echo "No command line arguments provided. Starting interactive setup..."
    echo ""
    
    # Default values for interactive mode
    CONTAINER_NAME="ignistack-sandbox-$(date +%s)"
    IMAGE_NAME="ignistack-dev-sandbox"
    HOST_PORT=8080
    MOUNT_PATH=""
    WORKSPACE_PATH="/home/flexy/workspace"
    ANTHROPIC_TOKEN=""
    GITHUB_TOKEN=""
    FIREBASE_TOKEN=""
    WORDPRESS_DB_HOST="localhost"
    WORDPRESS_DB_USER="root"
    WORDPRESS_DB_PASS=""
    WORDPRESS_DB_NAME="wordpress"
    WP_INSTANCE_NAME=""
    EXPOSE_TTYD=false
    EXPOSE_COSPEC=false
    ENABLE_WEBTTY=true
    TTYD_HOST_PORT=9681
    COSPEC_FRONTEND_PORT=9280
    
    # Prompt for container name
    read -p "Container name (default: $CONTAINER_NAME): " input_name
    if [ -n "$input_name" ]; then
        CONTAINER_NAME="$input_name"
    fi
    
    # Prompt for image name
    read -p "Image name (default: $IMAGE_NAME): " input_image
    if [ -n "$input_image" ]; then
        IMAGE_NAME="$input_image"
    fi
    
    # Prompt for host port
    read -p "Host port to expose (default: $HOST_PORT): " input_port
    if [ -n "$input_port" ]; then
        HOST_PORT="$input_port"
    fi
    
    # Prompt for mount path
    read -p "Host path to mount to container (optional, press Enter to skip): " input_mount
    if [ -n "$input_mount" ]; then
        MOUNT_PATH="$input_mount"
    fi
    
    # Prompt for container workspace path
    read -p "Container workspace path (default: /home/flexy/workspace): " input_workspace
    if [ -n "$input_workspace" ]; then
        WORKSPACE_PATH="$input_workspace"
    fi
    
    # Prompt for Anthropic token
    read -p "Anthropic API token (optional, press Enter to skip): " input_anthropic
    if [ -n "$input_anthropic" ]; then
        ANTHROPIC_TOKEN="$input_anthropic"
    fi
    
    # Prompt for GitHub token
    read -p "GitHub token (optional, press Enter to skip): " input_github
    if [ -n "$input_github" ]; then
        GITHUB_TOKEN="$input_github"
    fi
    
    # Prompt for Firebase token
    read -p "Firebase token (optional, press Enter to skip): " input_firebase
    if [ -n "$input_firebase" ]; then
        FIREBASE_TOKEN="$input_firebase"
    fi
    
    # Prompt for WordPress DB config
    read -p "WordPress DB host (default: $WORDPRESS_DB_HOST): " input_wp_host
    if [ -n "$input_wp_host" ]; then
        WORDPRESS_DB_HOST="$input_wp_host"
    fi
    
    read -p "WordPress DB user (default: $WORDPRESS_DB_USER): " input_wp_user
    if [ -n "$input_wp_user" ]; then
        WORDPRESS_DB_USER="$input_wp_user"
    fi
    
    read -p "WordPress DB password (default: $WORDPRESS_DB_PASS): " input_wp_pass
    if [ -n "$input_wp_pass" ]; then
        WORDPRESS_DB_PASS="$input_wp_pass"
    fi
    
    read -p "WordPress DB name (default: $WORDPRESS_DB_NAME): " input_wp_name
    if [ -n "$input_wp_name" ]; then
        WORDPRESS_DB_NAME="$input_wp_name"
    fi
    
    # Prompt for TTYD exposure
    read -p "Expose ttyd port (port 9681)? (y/N): " input_ttyd
    if [[ "$input_ttyd" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        EXPOSE_TTYD=true
        # Prompt for host port mapping for ttyd
        read -p "Host port for ttyd (default: 9681): " ttyd_host_port
        if [ -z "$ttyd_host_port" ]; then
            TTYD_HOST_PORT=9681
        else
            TTYD_HOST_PORT="$ttyd_host_port"
        fi
    fi
    
    # Prompt for CoSpec exposure
    read -p "Expose CoSpec AI ports (9280)? (y/N): " input_cospec
    if [[ "$input_cospec" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        EXPOSE_COSPEC=true
        # Prompt for host port mapping for CoSpec
        read -p "Host port for CoSpec frontend (default: 9280): " cospec_port
        if [ -z "$cospec_port" ]; then
            COSPEC_FRONTEND_PORT=9280
        else
            COSPEC_FRONTEND_PORT="$cospec_port"
        fi
    fi
    
    # Prompt for WebTTY mode
    read -p "Enable WebTTY mode? (Y/n): " input_webtty
    if [[ "$input_webtty" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        ENABLE_WEBTTY=true
    fi
    
else
    # Parse command line arguments like before
    # Default values
    CONTAINER_NAME="ignistack-sandbox-$(date +%s)"
    IMAGE_NAME="ignistack-dev-sandbox"
    HOST_PORT=8080
    MOUNT_PATH=""
    WORKSPACE_PATH="/home/flexy/workspace"
    ANTHROPIC_TOKEN=""
    GITHUB_TOKEN=""
    FIREBASE_TOKEN=""
    WORDPRESS_DB_HOST="localhost"
    WORDPRESS_DB_USER="root"
    WORDPRESS_DB_PASS=""
    WORDPRESS_DB_NAME="wordpress"
    WP_INSTANCE_NAME=""
    EXPOSE_TTYD=false
    EXPOSE_COSPEC=false
    ENABLE_WEBTTY=false
    # Default ports - CLI mode doesn't ask for custom ports, so use defaults
    TTYD_HOST_PORT=9681
    COSPEC_FRONTEND_PORT=9280

    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            -n|--name)
                CONTAINER_NAME="$2"
                shift 2
                ;;
            -i|--image)
                IMAGE_NAME="$2"
                shift 2
                ;;
            -p|--port)
                HOST_PORT="$2"
                shift 2
                ;;
            -m|--mount)
                MOUNT_PATH="$2"
                shift 2
                ;;
            -a|--anthropic-token)
                ANTHROPIC_TOKEN="$2"
                shift 2
                ;;
            -g|--github-token)
                GITHUB_TOKEN="$2"
                shift 2
                ;;
            -f|--firebase-token)
                FIREBASE_TOKEN="$2"
                shift 2
                ;;
            --wp-db-host)
                WORDPRESS_DB_HOST="$2"
                shift 2
                ;;
            --wp-db-user)
                WORDPRESS_DB_USER="$2"
                shift 2
                ;;
            --wp-db-pass)
                WORDPRESS_DB_PASS="$2"
                shift 2
                ;;
            --wp-db-name)
                WORDPRESS_DB_NAME="$2"
                shift 2
                ;;
            --wp-instance)
                WP_INSTANCE_NAME="$2"
                shift 2
                ;;
            -t|--ttyd)
                EXPOSE_TTYD=true
                shift
                ;;
            -c|--cospec)
                EXPOSE_COSPEC=true
                shift
                ;;
            -s|--webtty)
                ENABLE_WEBTTY=true
                shift
                ;;
            --workspace-path)
                WORKSPACE_PATH="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $key"
                show_usage
                exit 1
                ;;
        esac
    done
fi

echo "Creating IgniStack sandbox container: $CONTAINER_NAME"
echo "Using image: $IMAGE_NAME"
echo "Host port: $HOST_PORT"

# Check if image exists
if ! docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "$IMAGE_NAME"; then
    echo "Warning: Image '$IMAGE_NAME' not found."
    read -r -p "Do you want to build it first? [y/N] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "Building image: $IMAGE_NAME"
        # Use the build script to build the image
        if [ -f "host-scripts/build-docker.sh" ]; then
            ./host-scripts/build-docker.sh
        else
            echo "Please build the image manually using: docker build -t $IMAGE_NAME -f docker/Dockerfile ."
            exit 1
        fi
    else
        echo "Please build the image first or specify an existing image."
        exit 1
    fi
fi

# Check if container with same name already exists
if [ "$(docker ps -aq -f name=$CONTAINER_NAME)" ]; then
    echo "A container with name '$CONTAINER_NAME' already exists."
    read -r -p "Do you want to remove it first? [y/N] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "Removing existing container: $CONTAINER_NAME"
        docker rm -f "$CONTAINER_NAME" > /dev/null
    else
        echo "Please choose a different name or remove the existing container."
        exit 1
    fi
fi

# Build docker run command
RUN_CMD="docker run -d --name $CONTAINER_NAME -p $HOST_PORT:80"

# Add WordPress instance volume if specified
if [ -n "$WP_INSTANCE_NAME" ]; then
    # Get script directory and create wordpress-instances path
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
    WP_INSTANCES_DIR="$PROJECT_ROOT/wordpress-instances"
    WP_INSTANCE_DIR="$WP_INSTANCES_DIR/$WP_INSTANCE_NAME"

    # Create instance directory if it doesn't exist
    mkdir -p "$WP_INSTANCE_DIR"

    RUN_CMD="$RUN_CMD -v $WP_INSTANCE_DIR:/home/flexy/wordpress-persistent"
    RUN_CMD="$RUN_CMD -e WP_INSTANCE_NAME=$WP_INSTANCE_NAME"
    echo "Using persistent WordPress instance: $WP_INSTANCE_NAME"
    echo "WordPress data will be stored in: $WP_INSTANCE_DIR"
fi

# Add mount if specified
if [ -n "$MOUNT_PATH" ]; then
    if [ ! -d "$MOUNT_PATH" ]; then
        echo "Error: Mount path does not exist: $MOUNT_PATH"
        exit 1
    fi
    RUN_CMD="$RUN_CMD -v $MOUNT_PATH:$WORKSPACE_PATH"
    echo "Mounting: $MOUNT_PATH -> $WORKSPACE_PATH"
fi

# Add Anthropic token if specified
if [ -n "$ANTHROPIC_TOKEN" ]; then
    RUN_CMD="$RUN_CMD -e ANTHROPIC_AUTH_TOKEN=$ANTHROPIC_TOKEN"
    echo "Setting Anthropic token"
fi

# Add GitHub token if specified
if [ -n "$GITHUB_TOKEN" ]; then
    RUN_CMD="$RUN_CMD -e GITHUB_TOKEN=$GITHUB_TOKEN"
    echo "Setting GitHub token"
fi

# Add Firebase token if specified
if [ -n "$FIREBASE_TOKEN" ]; then
    RUN_CMD="$RUN_CMD -e FIREBASE_TOKEN=$FIREBASE_TOKEN"
    echo "Setting Firebase token"
fi

# Add WordPress DB configuration if specified
if [ -n "$WORDPRESS_DB_HOST" ]; then
    RUN_CMD="$RUN_CMD -e WORDPRESS_DB_HOST=$WORDPRESS_DB_HOST"
    echo "Setting WordPress DB host: $WORDPRESS_DB_HOST"
fi
if [ -n "$WORDPRESS_DB_USER" ]; then
    RUN_CMD="$RUN_CMD -e WORDPRESS_DB_USER=$WORDPRESS_DB_USER"
    echo "Setting WordPress DB user: $WORDPRESS_DB_USER"
fi
if [ -n "$WORDPRESS_DB_PASS" ]; then
    RUN_CMD="$RUN_CMD -e WORDPRESS_DB_PASS=$WORDPRESS_DB_PASS"
    echo "Setting WordPress DB password"
fi
if [ -n "$WORDPRESS_DB_NAME" ]; then
    RUN_CMD="$RUN_CMD -e WORDPRESS_DB_NAME=$WORDPRESS_DB_NAME"
    echo "Setting WordPress DB name: $WORDPRESS_DB_NAME"
fi

# Add WebTTY mode if enabled
if [ "$ENABLE_WEBTTY" = true ]; then
    RUN_CMD="$RUN_CMD -e ENABLE_WEBTTY=true"
    echo "Enabling WebTTY mode"
fi

# Expose ttyd port if requested
if [ "$EXPOSE_TTYD" = true ]; then
    RUN_CMD="$RUN_CMD -p ${TTYD_HOST_PORT}:9681"
    echo "Exposing ttyd port: ${TTYD_HOST_PORT}:9681"
fi

# Expose CoSpec AI ports if requested
if [ "$EXPOSE_COSPEC" = true ]; then
    RUN_CMD="$RUN_CMD -p ${COSPEC_FRONTEND_PORT}:9280"
    echo "Exposing CoSpec ports: ${COSPEC_FRONTEND_PORT}:9280"
fi

# Add the image name to the command
RUN_CMD="$RUN_CMD $IMAGE_NAME"

echo "Executing: $RUN_CMD"
echo ""

# Execute the docker run command
eval $RUN_CMD

# Wait a moment for container to start
sleep 3

# Check if container is running
if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
    echo "Container created successfully: $CONTAINER_NAME"
    echo "Access your sandbox at: http://localhost:$HOST_PORT"
    
    if [ "$EXPOSE_TTYD" = true ]; then
        echo "ttyd terminal available at: http://localhost:$TTYD_HOST_PORT"
    fi
    
    if [ "$EXPOSE_COSPEC" = true ]; then
        echo "CoSpec AI available at: http://localhost:$COSPEC_FRONTEND_PORT"
    fi
    
    echo ""
    echo "To access the container shell:"
    echo "  docker exec -it $CONTAINER_NAME /bin/bash"
    
    echo ""
    echo "To stop the container:"
    echo "  docker stop $CONTAINER_NAME"
    
    echo ""
    echo "For WordPress setup:"
    echo "  1. Access WordPress at: http://localhost:8080 (if running inside container)"
    echo "  2. Configure with database settings: host=$WORDPRESS_DB_HOST, user=$WORDPRESS_DB_USER, pass=$WORDPRESS_DB_PASS, name=$WORDPRESS_DB_NAME"
    echo "  3. Activate the 'sync-fire-wp' plugin in the WordPress admin panel"
    
    echo ""
    echo "For Firebase development:"
    echo "  1. Run 'firebase login' inside the container or use --firebase-token"
    echo "  2. Use 'firebase init' to set up your project"
    echo "  3. Run 'firebase emulators:start' to start local development servers"
else
    echo "Error: Failed to start container: $CONTAINER_NAME"
    docker logs "$CONTAINER_NAME" 2>&1 | tail -20
    exit 1
fi