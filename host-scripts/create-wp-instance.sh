#!/bin/bash

# WordPress Instance Manager for IgniStack Sandbox
# Creates and manages persistent WordPress installations

set -e  # Exit on any error

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default configuration
WP_INSTANCES_DIR_DEFAULT="$PROJECT_ROOT/wordpress-instances"
IMAGE_NAME="ghcr.io/misterlex223/ignistack-sandbox"
DEFAULT_WP_PORT=80
DEFAULT_TTYD_PORT=9681
DEFAULT_COSPEC_PORT=9280
DEFAULT_FIREBASE_PORT_START=5000

# Initialize WP_INSTANCES_DIR to default value
WP_INSTANCES_DIR="$WP_INSTANCES_DIR_DEFAULT"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to display usage
show_usage() {
    echo "WordPress Instance Manager for IgniStack Sandbox"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  create <name>        Create a new WordPress instance"
    echo "  start <name>         Start an existing WordPress instance"
    echo "  stop <name>          Stop a running WordPress instance"
    echo "  remove <name>        Remove a WordPress instance (deletes data!)"
    echo "  list                 List all WordPress instances"
    echo "  info <name>          Show information about a WordPress instance"
    echo ""
    echo "Options for 'create' and 'start':"
    echo "  --port <PORT>               WordPress port (default: 80)"
    echo "  --ttyd-port <PORT>          ttyd terminal port (default: 9681)"
    echo "  --cospec-port <PORT>        CoSpec AI port (default: 9280)"
    echo "  --firebase-port <PORT>      Firebase emulator starting port (default: 5000)"
    echo "  --mount <PATH>              Mount additional host directory to /home/flexy/workspace"
    echo "                                If specified, WordPress instances will be stored in this directory"
    echo "  --anthropic-token <TOKEN>   Anthropic API token"
    echo "  --firebase-token <TOKEN>    Firebase CLI token"
    echo ""
    echo "Examples:"
    echo "  # Create a new development instance"
    echo "  $0 create dev --port 8080"
    echo ""
    echo "  # Create a testing instance with custom ports"
    echo "  $0 create testing --port 8081 --ttyd-port 9682 --cospec-port 9281"
    echo ""
    echo "  # Create instance with custom storage location"
    echo "  $0 create custom --mount /path/to/project --port 8082"
    echo ""
    echo "  # Start an existing instance"
    echo "  $0 start dev"
    echo ""
    echo "  # List all instances"
    echo "  $0 list"
    echo ""
    echo "  # Remove an instance"
    echo "  $0 remove old-project"
}

# Function to print colored message
print_message() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Function to create WordPress instances directory
ensure_instances_dir() {
    if [ ! -d "$WP_INSTANCES_DIR" ]; then
        print_message "$BLUE" "Creating WordPress instances directory: $WP_INSTANCES_DIR"
        mkdir -p "$WP_INSTANCES_DIR"
    fi
}

# Function to validate instance name
validate_instance_name() {
    local name=$1
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        print_message "$RED" "Error: Instance name can only contain letters, numbers, hyphens, and underscores"
        exit 1
    fi
}

# Function to check if instance exists in current WP_INSTANCES_DIR
instance_exists() {
    local name=$1
    [ -d "$WP_INSTANCES_DIR/$name" ]
}

# Function to find instance and its correct WP_INSTANCES_DIR
find_instance_dir() {
    local instance_name=$1
    local original_instances_dir="$WP_INSTANCES_DIR"
    local instance_dir="$WP_INSTANCES_DIR/$instance_name"
    
    # First check in the current WP_INSTANCES_DIR (which may have been set by command args)
    if [ -d "$instance_dir" ]; then
        echo "$instance_dir"
        return 0
    fi
    
    # Next try default directory
    if [ "$WP_INSTANCES_DIR" != "$WP_INSTANCES_DIR_DEFAULT" ]; then
        WP_INSTANCES_DIR="$WP_INSTANCES_DIR_DEFAULT"
        instance_dir="$WP_INSTANCES_DIR/$instance_name"
        
        if [ -d "$instance_dir" ]; then
            echo "$instance_dir"
            return 0
        fi
    fi
    
    # Next try default instances directory with wordpress-instances subdirectory
    WP_INSTANCES_DIR="$WP_INSTANCES_DIR_DEFAULT/wordpress-instances"
    instance_dir="$WP_INSTANCES_DIR/$instance_name"
    
    if [ -d "$instance_dir" ]; then
        echo "$instance_dir"
        return 0
    fi
    
    # Restore original directory and return failure
    WP_INSTANCES_DIR="$original_instances_dir"
    return 1
}

# Function to get container name
get_container_name() {
    local instance_name=$1
    echo "ignistack-wp-${instance_name}"
}

# Function to check if container is running
container_is_running() {
    local container_name=$1
    [ "$(docker ps -q -f name=^${container_name}$)" ]
}

# Function to create a new WordPress instance
create_instance() {
    local instance_name=$1
    shift

    validate_instance_name "$instance_name"

    # Parse options first to determine if a mount path is specified
    local wp_port=$DEFAULT_WP_PORT
    local ttyd_port=$DEFAULT_TTYD_PORT
    local cospec_port=$DEFAULT_COSPEC_PORT
    local firebase_port=$DEFAULT_FIREBASE_PORT_START
    local mount_path=""
    local anthropic_token=""
    local firebase_token=""
    local temp_args=()

    # Store original arguments to process multiple times
    local original_args=("$@")

    # Parse options to check if mount path is provided
    while [[ $# -gt 0 ]]; do
        case $1 in
            --port)
                wp_port=$2
                temp_args+=("$1" "$2")
                shift 2
                ;;
            --ttyd-port)
                ttyd_port=$2
                temp_args+=("$1" "$2")
                shift 2
                ;;
            --cospec-port)
                cospec_port=$2
                temp_args+=("$1" "$2")
                shift 2
                ;;
            --firebase-port)
                firebase_port=$2
                temp_args+=("$1" "$2")
                shift 2
                ;;
            --mount)
                mount_path=$2
                temp_args+=("$1" "$2")
                shift 2
                ;;
            --anthropic-token)
                anthropic_token=$2
                temp_args+=("$1" "$2")
                shift 2
                ;;
            --firebase-token)
                firebase_token=$2
                temp_args+=("$1" "$2")
                shift 2
                ;;
            *)
                temp_args+=("$1")
                shift
                ;;
        esac
    done

    # If mount path is provided, set WP_INSTANCES_DIR to mount_path/wordpress-instances
    if [ -n "$mount_path" ] && [ -d "$mount_path" ]; then
        WP_INSTANCES_DIR="$mount_path/wordpress-instances"
        print_message "$BLUE" "Using mount path with wordpress-instances subdirectory: $WP_INSTANCES_DIR"
    fi

    ensure_instances_dir

    if instance_exists "$instance_name"; then
        print_message "$RED" "Error: WordPress instance '$instance_name' already exists"
        print_message "$YELLOW" "Use '$0 start $instance_name' to start it or '$0 remove $instance_name' to delete it"
        exit 1
    fi

    print_message "$BLUE" "Creating WordPress instance: $instance_name"

    # Create instance directory
    local instance_dir="$WP_INSTANCES_DIR/$instance_name"
    mkdir -p "$instance_dir"

    # Create instance metadata
    cat > "$instance_dir/.instance-info" <<EOF
INSTANCE_NAME=$instance_name
CREATED_AT="$(date '+%Y-%m-%d %H:%M:%S')"
WP_PORT=$wp_port
TTYD_PORT=$ttyd_port
COSPEC_PORT=$cospec_port
FIREBASE_PORT=$firebase_port
EOF

    if [ -n "$mount_path" ]; then
        echo "MOUNT_PATH=$mount_path" >> "$instance_dir/.instance-info"
    fi
    
    # If WP_INSTANCES_DIR is different from default, record it in instance info
    if [ "$WP_INSTANCES_DIR" != "$WP_INSTANCES_DIR_DEFAULT" ]; then
        echo "WP_INSTANCES_DIR_VAR=$WP_INSTANCES_DIR" >> "$instance_dir/.instance-info"
    fi

    print_message "$GREEN" "✓ WordPress instance directory created: $instance_dir"
    print_message "$BLUE" "Starting container..."

    # Start the instance with original arguments
    start_instance "$instance_name" "${original_args[@]}"
}

# Function to start a WordPress instance
start_instance() {
    local instance_name=$1
    shift

    validate_instance_name "$instance_name"

    # Parse command-line options to check for mount path that might change instances dir
    local wp_port=""
    local ttyd_port=""
    local cospec_port=""
    local firebase_port=""
    local mount_path=""
    local anthropic_token=""
    local firebase_token=""
    local temp_args=("$@")
    
    # First pass: check if mount option is provided to potentially update WP_INSTANCES_DIR
    local args_copy=("$@")
    local has_mount_option=false
    while [[ ${#args_copy[@]} -gt 0 ]]; do
        case ${args_copy[0]} in
            --mount)
                mount_path=${args_copy[1]}
                # If mount path is provided and is a valid directory, update WP_INSTANCES_DIR to include subdirectory
                if [ -n "$mount_path" ] && [ -d "$mount_path" ]; then
                    WP_INSTANCES_DIR="$mount_path/wordpress-instances"
                    has_mount_option=true
                    print_message "$BLUE" "Using mount path with wordpress-instances subdirectory: $WP_INSTANCES_DIR"
                fi
                ;;
        esac
        if [[ ${#args_copy[@]} -gt 1 ]]; then
            args_copy=("${args_copy[@]:2}")
        else
            break
        fi
    done

    # Check if instance exists with current WP_INSTANCES_DIR
    if ! instance_exists "$instance_name"; then
        # If not found and we didn't receive a mount option in this call, try default instances directory
        if [ "$has_mount_option" = false ]; then
            local original_instances_dir="$WP_INSTANCES_DIR"
            WP_INSTANCES_DIR="$WP_INSTANCES_DIR_DEFAULT"
            
            if ! instance_exists "$instance_name"; then
                # If still not found, restore original and error out
                WP_INSTANCES_DIR="$original_instances_dir"
                print_message "$RED" "Error: WordPress instance '$instance_name' does not exist in $WP_INSTANCES_DIR"
                print_message "$YELLOW" "Use '$0 create $instance_name' to create it first"
                exit 1
            fi
        else
            # If mount option was provided but instance not found in the derived path, error out
            print_message "$RED" "Error: WordPress instance '$instance_name' does not exist in $WP_INSTANCES_DIR"
            print_message "$YELLOW" "Use '$0 create $instance_name' to create it first"
            exit 1
        fi
    fi

    local container_name=$(get_container_name "$instance_name")

    if container_is_running "$container_name"; then
        print_message "$YELLOW" "WordPress instance '$instance_name' is already running"
        print_message "$BLUE" "Container: $container_name"
        docker ps -f name=^${container_name}$ --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        return 0
    fi

    # Load instance metadata
    local instance_dir="$WP_INSTANCES_DIR/$instance_name"
    if [ -f "$instance_dir/.instance-info" ]; then
        # Source the instance info to get stored values
        source "$instance_dir/.instance-info"
        
        # If the instance info file contains WP_INSTANCES_DIR, use that as the base directory
        if [ -n "$WP_INSTANCES_DIR_VAR" ]; then
            WP_INSTANCES_DIR="$WP_INSTANCES_DIR_VAR"
            instance_dir="$WP_INSTANCES_DIR/$instance_name"
        fi
    else
        print_message "$RED" "Error: Instance metadata file missing: $instance_dir/.instance-info"
        exit 1
    fi

    # Parse command-line options (override metadata if provided)
    while [[ $# -gt 0 ]]; do
        case $1 in
            --port)
                WP_PORT=$2
                shift 2
                ;;
            --ttyd-port)
                TTYD_PORT=$2
                shift 2
                ;;
            --cospec-port)
                COSPEC_PORT=$2
                shift 2
                ;;
            --firebase-port)
                FIREBASE_PORT=$2
                shift 2
                ;;
            --mount)
                MOUNT_PATH=$2
                shift 2
                ;;
            --anthropic-token)
                ANTHROPIC_TOKEN=$2
                shift 2
                ;;
            --firebase-token)
                FIREBASE_TOKEN=$2
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    print_message "$BLUE" "Starting WordPress instance: $instance_name"
    print_message "$BLUE" "Container name: $container_name"

    # Check if image exists
    if ! docker images --format "{{.Repository}}" | grep -q "^${IMAGE_NAME}$"; then
        print_message "$RED" "Error: Docker image '$IMAGE_NAME' not found"
        print_message "$YELLOW" "Please build the image first using: ./host-scripts/build-docker.sh"
        exit 1
    fi

    # Build docker run command
    local docker_cmd="docker run -d --name $container_name"

    # Add port mappings
    docker_cmd="$docker_cmd -p ${WP_PORT:-$DEFAULT_WP_PORT}:80"
    docker_cmd="$docker_cmd -p ${TTYD_PORT:-$DEFAULT_TTYD_PORT}:9681"
    docker_cmd="$docker_cmd -p ${COSPEC_PORT:-$DEFAULT_COSPEC_PORT}:9280"
    docker_cmd="$docker_cmd -p ${FIREBASE_PORT:-$DEFAULT_FIREBASE_PORT_START}:5000"
    docker_cmd="$docker_cmd -p $(( ${FIREBASE_PORT:-$DEFAULT_FIREBASE_PORT_START} + 1 )):5001"

    # Mount WordPress persistent volume
    docker_cmd="$docker_cmd -v $instance_dir:/home/flexy/wordpress-persistent"

    # Mount workspace if specified
    if [ -n "$MOUNT_PATH" ] && [ -d "$MOUNT_PATH" ]; then
        docker_cmd="$docker_cmd -v $MOUNT_PATH:/home/flexy/workspace"
        print_message "$BLUE" "Mounting workspace: $MOUNT_PATH"
    fi

    # Set environment variables
    docker_cmd="$docker_cmd -e WP_INSTANCE_NAME=$instance_name"
    docker_cmd="$docker_cmd -e WORDPRESS_SITE_URL=http://localhost:${WP_PORT:-$DEFAULT_WP_PORT}"
    docker_cmd="$docker_cmd -e ENABLE_WEBTTY=true"

    if [ -n "$OPENAI_API_KEY" ]; then
        docker_cmd="$docker_cmd -e OPENAI_API_KEY=$OPENAI_API_KEY"    
    fi

    if [ -n "$ANTHROPIC_TOKEN" ]; then
        docker_cmd="$docker_cmd -e ANTHROPIC_AUTH_TOKEN=$ANTHROPIC_TOKEN"
    fi

    if [ -n "$FIREBASE_TOKEN" ]; then
        docker_cmd="$docker_cmd -e FIREBASE_TOKEN=$FIREBASE_TOKEN"
    fi

    # Add image name
    docker_cmd="$docker_cmd $IMAGE_NAME"

    # Execute docker run
    print_message "$BLUE" "Executing: $docker_cmd"
    eval $docker_cmd

    # Wait for container to start
    sleep 3

    if container_is_running "$container_name"; then
        print_message "$GREEN" "✓ WordPress instance '$instance_name' started successfully!"
        print_message "$GREEN" ""
        print_message "$GREEN" "Access points:"
        print_message "$GREEN" "  WordPress:    http://localhost:${WP_PORT:-$DEFAULT_WP_PORT}"
        print_message "$GREEN" "  WebTTY:       http://localhost:${TTYD_PORT:-$DEFAULT_TTYD_PORT}"
        print_message "$GREEN" "  CoSpec AI:    http://localhost:${COSPEC_PORT:-$DEFAULT_COSPEC_PORT}"
        print_message "$GREEN" "  Firebase UI:  http://localhost:${FIREBASE_PORT:-$DEFAULT_FIREBASE_PORT_START}"
        print_message "$GREEN" ""
        print_message "$BLUE" "Instance data: $instance_dir"
        print_message "$BLUE" "Container: $container_name"
    else
        print_message "$RED" "✗ Failed to start WordPress instance '$instance_name'"
        print_message "$YELLOW" "Checking logs..."
        docker logs "$container_name" 2>&1 | tail -20
        exit 1
    fi
}

# Function to stop a WordPress instance
stop_instance() {
    local instance_name=$1

    validate_instance_name "$instance_name"

    # Find the instance directory
    local original_instances_dir="$WP_INSTANCES_DIR"
    local instance_dir
    instance_dir=$(find_instance_dir "$instance_name")
    if [ $? -ne 0 ]; then
        WP_INSTANCES_DIR="$original_instances_dir"
        print_message "$RED" "Error: WordPress instance '$instance_name' does not exist"
        exit 1
    fi

    local container_name=$(get_container_name "$instance_name")

    if ! container_is_running "$container_name"; then
        print_message "$YELLOW" "WordPress instance '$instance_name' is not running"
        return 0
    fi

    print_message "$BLUE" "Stopping WordPress instance: $instance_name"
    docker stop "$container_name"
    docker rm "$container_name"
    print_message "$GREEN" "✓ WordPress instance '$instance_name' stopped"
}

# Function to remove a WordPress instance
remove_instance() {
    local instance_name=$1

    validate_instance_name "$instance_name"

    # Find the instance directory
    local original_instances_dir="$WP_INSTANCES_DIR"
    local instance_dir
    instance_dir=$(find_instance_dir "$instance_name")
    if [ $? -ne 0 ]; then
        WP_INSTANCES_DIR="$original_instances_dir"
        print_message "$RED" "Error: WordPress instance '$instance_name' does not exist"
        exit 1
    fi

    local container_name=$(get_container_name "$instance_name")

    # Stop container if running
    if container_is_running "$container_name"; then
        print_message "$YELLOW" "Stopping running container..."
        docker stop "$container_name" 2>/dev/null || true
        docker rm "$container_name" 2>/dev/null || true
    fi


    print_message "$RED" "WARNING: This will permanently delete all data for instance '$instance_name'"
    print_message "$YELLOW" "Location: $instance_dir"
    read -p "Are you sure? (type 'yes' to confirm): " confirm

    if [ "$confirm" != "yes" ]; then
        print_message "$BLUE" "Cancelled"
        exit 0
    fi

    print_message "$BLUE" "Removing WordPress instance: $instance_name"
    rm -rf "$instance_dir"
    print_message "$GREEN" "✓ WordPress instance '$instance_name' removed"
}

# Function to list all WordPress instances
list_instances() {
    print_message "$BLUE" "WordPress Instances:"
    print_message "$BLUE" "===================="

    local total_instances=0
    
    # List instances from current WP_INSTANCES_DIR
    if [ -d "$WP_INSTANCES_DIR" ] && [ "$(ls -A $WP_INSTANCES_DIR 2>/dev/null)" ]; then
        print_message "$BLUE" "Instances in current directory ($WP_INSTANCES_DIR):"
        printf "%-20s %-15s %-30s %-10s\n" "NAME" "STATUS" "CONTAINER" "SIZE"
        printf "%-20s %-15s %-30s %-10s\n" "----" "------" "---------" "----"

        for instance_dir in "$WP_INSTANCES_DIR"/*; do
            if [ -d "$instance_dir" ]; then
                local instance_name=$(basename "$instance_dir")
                local container_name=$(get_container_name "$instance_name")
                local status="stopped"
                local size=$(du -sh "$instance_dir" 2>/dev/null | cut -f1)

                if container_is_running "$container_name"; then
                    status="${GREEN}running${NC}"
                else
                    status="${YELLOW}stopped${NC}"
                fi

                printf "%-20s %-24s %-30s %-10s\n" "$instance_name" "$(echo -e $status)" "$container_name" "$size"
                ((total_instances++))
            fi
        done
    fi

    # List instances from default directory if it's different from current
    if [ "$WP_INSTANCES_DIR" != "$WP_INSTANCES_DIR_DEFAULT" ] && [ -d "$WP_INSTANCES_DIR_DEFAULT" ]; then
        local default_instances=$(find "$WP_INSTANCES_DIR_DEFAULT" -mindepth 1 -maxdepth 1 -type d)
        if [ -n "$default_instances" ]; then
            print_message "$BLUE" "\nInstances in default directory ($WP_INSTANCES_DIR_DEFAULT):"
            printf "%-20s %-15s %-30s %-10s\n" "NAME" "STATUS" "CONTAINER" "SIZE"
            printf "%-20s %-15s %-30s %-10s\n" "----" "------" "---------" "----"
            
            for instance_dir in "$WP_INSTANCES_DIR_DEFAULT"/*; do
                if [ -d "$instance_dir" ]; then
                    local instance_name=$(basename "$instance_dir")
                    local container_name=$(get_container_name "$instance_name")
                    local status="stopped"
                    local size=$(du -sh "$instance_dir" 2>/dev/null | cut -f1)

                    if container_is_running "$container_name"; then
                        status="${GREEN}running${NC}"
                    else
                        status="${YELLOW}stopped${NC}"
                    fi

                    printf "%-20s %-24s %-30s %-10s\n" "$instance_name" "$(echo -e $status)" "$container_name" "$size"
                    ((total_instances++))
                fi
            done
        fi
    fi

    # List instances from default wordpress-instances subdirectory if it's different
    local wp_instances_subdir="$WP_INSTANCES_DIR_DEFAULT/wordpress-instances"
    if [ "$WP_INSTANCES_DIR" != "$wp_instances_subdir" ] && [ -d "$wp_instances_subdir" ]; then
        local wp_instances=$(find "$wp_instances_subdir" -mindepth 1 -maxdepth 1 -type d)
        if [ -n "$wp_instances" ]; then
            print_message "$BLUE" "\nInstances in default wordpress-instances subdirectory ($wp_instances_subdir):"
            printf "%-20s %-15s %-30s %-10s\n" "NAME" "STATUS" "CONTAINER" "SIZE"
            printf "%-20s %-15s %-30s %-10s\n" "----" "------" "---------" "----"
            
            for instance_dir in "$wp_instances_subdir"/*; do
                if [ -d "$instance_dir" ]; then
                    local instance_name=$(basename "$instance_dir")
                    local container_name=$(get_container_name "$instance_name")
                    local status="stopped"
                    local size=$(du -sh "$instance_dir" 2>/dev/null | cut -f1)

                    if container_is_running "$container_name"; then
                        status="${GREEN}running${NC}"
                    else
                        status="${YELLOW}stopped${NC}"
                    fi

                    printf "%-20s %-24s %-30s %-10s\n" "$instance_name" "$(echo -e $status)" "$container_name" "$size"
                    ((total_instances++))
                fi
            done
        fi
    fi

    if [ $total_instances -eq 0 ]; then
        print_message "$YELLOW" "No WordPress instances found"
        print_message "$BLUE" "Create one with: $0 create <name>"
    else
        print_message "$GREEN" "\nTotal instances found: $total_instances"
    fi
}

# Function to show instance information
show_instance_info() {
    local instance_name=$1

    validate_instance_name "$instance_name"

    # Find the instance directory
    local original_instances_dir="$WP_INSTANCES_DIR"
    local instance_dir
    instance_dir=$(find_instance_dir "$instance_name")
    if [ $? -ne 0 ]; then
        WP_INSTANCES_DIR="$original_instances_dir"
        print_message "$RED" "Error: WordPress instance '$instance_name' does not exist"
        exit 1
    fi

    local container_name=$(get_container_name "$instance_name")

    print_message "$BLUE" "WordPress Instance Information"
    print_message "$BLUE" "=============================="
    print_message "$GREEN" "Instance: $instance_name"
    print_message "$BLUE" "Location: $instance_dir"
    print_message "$BLUE" "Container: $container_name"

    if container_is_running "$container_name"; then
        print_message "$GREEN" "Status: Running"
        print_message "$BLUE" ""
        print_message "$BLUE" "Container details:"
        docker ps -f name=^${container_name}$ --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        print_message "$YELLOW" "Status: Stopped"
    fi

    print_message "$BLUE" ""
    print_message "$BLUE" "Instance metadata:"
    if [ -f "$instance_dir/.instance-info" ]; then
        cat "$instance_dir/.instance-info"
    else
        print_message "$YELLOW" "No metadata file found"
    fi

    print_message "$BLUE" ""
    print_message "$BLUE" "Disk usage:"
    du -sh "$instance_dir"

    if [ -f "$instance_dir/wp-config.php" ]; then
        print_message "$GREEN" "✓ WordPress is installed"
    else
        print_message "$YELLOW" "⚠ WordPress not yet installed (visit the web interface to complete setup)"
    fi

    if [ -f "$instance_dir/wp-content/database/.ht.sqlite" ]; then
        local db_size=$(du -h "$instance_dir/wp-content/database/.ht.sqlite" | cut -f1)
        print_message "$GREEN" "✓ SQLite database exists (${db_size})"
    fi
}

# Main script logic
main() {
    if [ $# -eq 0 ]; then
        show_usage
        exit 0
    fi

    local command=$1
    shift

    # Check if a mount path is provided as a global option to set WP_INSTANCES_DIR
    # This is done by parsing the arguments to look for --mount
    local original_args=("$@")
    local args_copy=("$@")
    local has_mount_option=false
    while [[ ${#args_copy[@]} -gt 0 ]]; do
        case ${args_copy[0]} in
            --mount)
                local mount_path=${args_copy[1]}
                # If mount path is provided and is a valid directory, update WP_INSTANCES_DIR to include subdirectory
                if [ -n "$mount_path" ] && [ -d "$mount_path" ]; then
                    WP_INSTANCES_DIR="$mount_path/wordpress-instances"
                    has_mount_option=true
                    print_message "$BLUE" "Using mount path with wordpress-instances subdirectory: $WP_INSTANCES_DIR"
                fi
                ;;
        esac
        if [[ ${#args_copy[@]} -gt 1 ]]; then
            args_copy=("${args_copy[@]:2}")
        else
            break
        fi
    done

    case $command in
        create)
            if [ $# -eq 0 ]; then
                print_message "$RED" "Error: Instance name required"
                show_usage
                exit 1
            fi
            create_instance "${original_args[@]}"
            ;;
        start)
            if [ $# -eq 0 ]; then
                print_message "$RED" "Error: Instance name required"
                show_usage
                exit 1
            fi
            start_instance "${original_args[@]}"
            ;;
        stop)
            if [ $# -eq 0 ]; then
                print_message "$RED" "Error: Instance name required"
                show_usage
                exit 1
            fi
            stop_instance "$1"
            ;;
        remove)
            if [ $# -eq 0 ]; then
                print_message "$RED" "Error: Instance name required"
                show_usage
                exit 1
            fi
            remove_instance "$1"
            ;;
        list)
            list_instances
            ;;
        info)
            if [ $# -eq 0 ]; then
                print_message "$RED" "Error: Instance name required"
                show_usage
                exit 1
            fi
            show_instance_info "$1"
            ;;
        -h|--help|help)
            show_usage
            ;;
        *)
            print_message "$RED" "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
