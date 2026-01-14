#!/usr/bin/env bash
# IgniStack CLI - Unified command interface for IgniStack Sandbox
# This script can be used as both a standalone CLI and a Claude Code Skill backend

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IGNISTACK_IMAGE="${IGNISTACK_IMAGE:-ghcr.io/misterlex223/ignistack-sandbox:latest}"
INSTANCES_ROOT="${IGNISTACK_INSTANCES_ROOT:-$HOME/.ignistack-instances}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        return 1
    fi

    if ! docker info &> /dev/null; then
        log_error "Docker is not running. Please start Docker."
        return 1
    fi

    return 0
}

ensure_instances_dir() {
    mkdir -p "$INSTANCES_ROOT"
}

pull_image() {
    local image="${1:-$IGNISTACK_IMAGE}"

    log_info "Pulling IgniStack image: $image"

    if docker image inspect "$image" &> /dev/null; then
        log_info "Image already exists locally. Use --force-pull to update."
        return 0
    fi

    if docker pull "$image"; then
        log_success "Image pulled successfully"
        return 0
    else
        log_error "Failed to pull image"
        return 1
    fi
}

get_container_name() {
    local instance_name="$1"
    echo "ignistack-wp-$instance_name"
}

get_instance_dir() {
    local instance_name="$1"
    echo "$INSTANCES_ROOT/$instance_name"
}

check_instance_exists() {
    local instance_name="$1"
    local instance_dir

    instance_dir="$(get_instance_dir "$instance_name")"

    if [[ ! -d "$instance_dir" ]]; then
        log_error "Instance '$instance_name' does not exist"
        return 1
    fi

    return 0
}

check_port_available() {
    local port="$1"
    local service="${2:-service}"

    if lsof -Pi :"$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
        log_warning "Port $port is already in use for $service"
        return 1
    fi

    return 0
}

read_instance_info() {
    local instance_dir="$1"
    local info_file="$instance_dir/.instance-info"

    if [[ ! -f "$info_file" ]]; then
        log_error "Instance info file not found: $info_file"
        return 1
    fi

    # Source the instance info file
    # shellcheck source=/dev/null
    source "$info_file"
}

# ============================================================================
# INSTANCE MANAGEMENT
# ============================================================================

cmd_init() {
    local project_name=""
    local port="8080"
    local mount_path=""
    local firebase_port="5000"
    local firebase_ui_port="4000"
    local ttyd_port="9681"
    local cospec_port="9280"
    local force_pull=false
    local image="$IGNISTACK_IMAGE"
    local env_vars=()

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --port)
                port="$2"
                shift 2
                ;;
            --mount)
                mount_path="$2"
                shift 2
                ;;
            --firebase-port)
                firebase_port="$2"
                shift 2
                ;;
            --firebase-ui-port)
                firebase_ui_port="$2"
                shift 2
                ;;
            --ttyd-port)
                ttyd_port="$2"
                shift 2
                ;;
            --cospec-port)
                cospec_port="$2"
                shift 2
                ;;
            --image)
                image="$2"
                shift 2
                ;;
            --force-pull)
                force_pull=true
                shift
                ;;
            -e|--env)
                env_vars+=("$2")
                shift 2
                ;;
            -*)
                log_error "Unknown option: $1"
                return 1
                ;;
            *)
                project_name="$1"
                shift
                ;;
        esac
    done

    # Validate project name
    if [[ -z "$project_name" ]]; then
        log_error "Project name is required"
        echo "Usage: $0 init <project-name> [options]"
        return 1
    fi

    # Check Docker
    if ! check_docker; then
        return 1
    fi

    # Pull image
    if [[ "$force_pull" == true ]]; then
        log_info "Pulling latest image..."
        if ! docker pull "$image"; then
            log_error "Failed to pull image"
            return 1
        fi
    else
        if ! pull_image "$image"; then
            return 1
        fi
    fi

    # Create instance
    log_info "Creating IgniStack environment for project: $project_name"
    cmd_create_instance "$project_name" \
        --port "$port" \
        --firebase-port "$firebase_port" \
        --firebase-ui-port "$firebase_ui_port" \
        --ttyd-port "$ttyd_port" \
        --cospec-port "$cospec_port"

    # Start instance
    log_info "Starting instance..."
    cmd_start "$project_name"

    # Display info
    cmd_info "$project_name"

    log_success "IgniStack environment initialized successfully!"
    log_info "WordPress Admin: http://localhost:$port/wp-admin"
    log_info "WebTTY: http://localhost:$ttyd_port"
}

cmd_create_instance() {
    local instance_name=""
    local port="8080"
    local firebase_port="5000"
    local firebase_ui_port="4000"
    local ttyd_port="9681"
    local cospec_port="9280"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --port)
                port="$2"
                shift 2
                ;;
            --firebase-port)
                firebase_port="$2"
                shift 2
                ;;
            --firebase-ui-port)
                firebase_ui_port="$2"
                shift 2
                ;;
            --ttyd-port)
                ttyd_port="$2"
                shift 2
                ;;
            --cospec-port)
                cospec_port="$2"
                shift 2
                ;;
            -*)
                log_error "Unknown option: $1"
                return 1
                ;;
            *)
                instance_name="$1"
                shift
                ;;
        esac
    done

    # Validate instance name
    if [[ -z "$instance_name" ]]; then
        log_error "Instance name is required"
        echo "Usage: $0 create-instance <name> [options]"
        return 1
    fi

    # Validate instance name format
    if [[ ! "$instance_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Instance name can only contain letters, numbers, hyphens, and underscores"
        return 1
    fi

    # Check if instance already exists
    local instance_dir
    instance_dir="$(get_instance_dir "$instance_name")"

    if [[ -d "$instance_dir" ]]; then
        log_error "Instance '$instance_name' already exists at $instance_dir"
        return 1
    fi

    # Create instances directory
    ensure_instances_dir

    # Create instance directory
    log_info "Creating instance directory: $instance_dir"
    mkdir -p "$instance_dir"

    # Create instance info file
    local info_file="$instance_dir/.instance-info"
    cat > "$info_file" <<EOF
INSTANCE_NAME="$instance_name"
CREATED_AT="$(date '+%Y-%m-%d %H:%M:%S')"
WP_PORT="$port"
FIREBASE_PORT="$firebase_port"
FIREBASE_UI_PORT="$firebase_ui_port"
TTYD_PORT="$ttyd_port"
COSPEC_PORT="$cospec_port"
IMAGE="$IGNISTACK_IMAGE"
EOF

    log_success "Instance '$instance_name' created successfully"
    log_info "Instance directory: $instance_dir"
}

cmd_list() {
    ensure_instances_dir

    local instances
    instances=("$INSTANCES_ROOT"/*)

    if [[ ! -d "${instances[0]}" ]]; then
        log_info "No instances found"
        return 0
    fi

    echo "AVAILABLE INSTANCES:"
    echo

    for instance_dir in "${instances[@]}"; do
        [[ ! -d "$instance_dir" ]] && continue

        local instance_name
        instance_name="$(basename "$instance_dir")"

        if [[ ! -f "$instance_dir/.instance-info" ]]; then
            continue
        fi

        # Read instance info
        WP_PORT=""
        TTYD_PORT=""
        # shellcheck source=/dev/null
        source "$instance_dir/.instance-info"

        local container_name
        container_name="$(get_container_name "$instance_name")"

        echo "Name: $instance_name"

        # Check if container is running
        if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
            echo -e "Status: ${GREEN}Running${NC}"
        elif docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
            echo -e "Status: ${YELLOW}Stopped${NC}"
        else
            echo -e "Status: ${RED}Not created${NC}"
        fi

        echo "WordPress: http://localhost:${WP_PORT:-8080}"
        echo "WebTTY: http://localhost:${TTYD_PORT:-9681}"
        echo "Container: $container_name"
        echo "Directory: $instance_dir"
        echo
    done
}

cmd_start() {
    local instance_name="$1"

    if [[ -z "$instance_name" ]]; then
        log_error "Instance name is required"
        echo "Usage: $0 start <name>"
        return 1
    fi

    # Check if instance exists
    if ! check_instance_exists "$instance_name"; then
        return 1
    fi

    local instance_dir
    instance_dir="$(get_instance_dir "$instance_name")"

    # Read instance info
    WP_PORT=""
    TTYD_PORT=""
    COSPEC_PORT=""
    FIREBASE_PORT=""
    FIREBASE_UI_PORT=""
    IMAGE=""
    # shellcheck source=/dev/null
    source "$instance_dir/.instance-info"

    local container_name
    container_name="$(get_container_name "$instance_name")"

    # Check if container already exists
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        log_warning "Container '$container_name' is already running"
        return 0
    fi

    # Remove existing container if it exists but is stopped
    if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        log_info "Removing existing container..."
        docker rm "$container_name" >/dev/null
    fi

    # Pull image if needed
    if [[ -n "$IMAGE" ]]; then
        if ! docker image inspect "$IMAGE" &> /dev/null; then
            log_info "Pulling image: $IMAGE"
            docker pull "$IMAGE"
        fi
    fi

    # Build docker run command
    local docker_cmd="docker run -d \
        --name '$container_name' \
        -p '${WP_PORT}:80' \
        -p '${TTYD_PORT}:9681' \
        -p '${COSPEC_PORT}:9280' \
        -p '${FIREBASE_PORT}:5000' \
        -p '${FIREBASE_UI_PORT}:4000' \
        -e 'WP_INSTANCE_NAME=$instance_name' \
        -e 'ENABLE_WEBTTY=true' \
        -v '$instance_dir:/home/flexy/wordpress-persistent' \
        '${IGNISTACK_IMAGE}'"

    log_info "Starting container: $container_name"

    if eval "$docker_cmd"; then
        log_success "Container started successfully"
        return 0
    else
        log_error "Failed to start container"
        return 1
    fi
}

cmd_stop() {
    local instance_name="$1"

    if [[ -z "$instance_name" ]]; then
        log_error "Instance name is required"
        echo "Usage: $0 stop <name>"
        return 1
    fi

    local container_name
    container_name="$(get_container_name "$instance_name")"

    if ! docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        log_warning "Container '$container_name' is not running"
        return 0
    fi

    log_info "Stopping container: $container_name"

    if docker stop "$container_name"; then
        log_success "Container stopped successfully"
        return 0
    else
        log_error "Failed to stop container"
        return 1
    fi
}

cmd_restart() {
    local instance_name="$1"

    if [[ -z "$instance_name" ]]; then
        log_error "Instance name is required"
        echo "Usage: $0 restart <name>"
        return 1
    fi

    cmd_stop "$instance_name"
    cmd_start "$instance_name"
}

cmd_remove() {
    local instance_name="$1"
    local force=false

    if [[ "$1" == "--force" ]]; then
        force=true
        instance_name="$2"
    fi

    if [[ -z "$instance_name" ]]; then
        log_error "Instance name is required"
        echo "Usage: $0 remove <name>"
        return 1
    fi

    # Check if instance exists
    if ! check_instance_exists "$instance_name"; then
        return 1
    fi

    local container_name
    container_name="$(get_container_name "$instance_name")"

    # Stop container if running
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        log_info "Stopping container..."
        docker stop "$container_name" >/dev/null
    fi

    # Remove container if exists
    if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        log_info "Removing container..."
        docker rm "$container_name" >/dev/null
    fi

    # Remove instance directory
    local instance_dir
    instance_dir="$(get_instance_dir "$instance_name")"

    if [[ "$force" != true ]]; then
        echo -e "${RED}WARNING: This will permanently delete all data for instance '$instance_name'${NC}"
        read -p "Are you sure? (yes/no): " confirm

        if [[ "$confirm" != "yes" ]]; then
            log_info "Removal cancelled"
            return 0
        fi
    fi

    log_info "Removing instance directory: $instance_dir"
    rm -rf "$instance_dir"

    log_success "Instance '$instance_name' removed successfully"
}

cmd_info() {
    local instance_name="$1"

    if [[ -z "$instance_name" ]]; then
        log_error "Instance name is required"
        echo "Usage: $0 info <name>"
        return 1
    fi

    # Check if instance exists
    if ! check_instance_exists "$instance_name"; then
        return 1
    fi

    local instance_dir
    instance_dir="$(get_instance_dir "$instance_name")"

    # Read instance info
    if ! read_instance_info "$instance_dir"; then
        return 1
    fi

    local container_name
    container_name="$(get_container_name "$instance_name")"

    echo "INSTANCE INFO:"
    echo
    echo "Name: $INSTANCE_NAME"
    echo "Created: $CREATED_AT"
    echo "Directory: $instance_dir"
    echo
    echo "SERVICES:"
    echo "  WordPress: http://localhost:${WP_PORT}"
    echo "  WordPress Admin: http://localhost:${WP_PORT}/wp-admin"
    echo "  WebTTY: http://localhost://${TTYD_PORT}"
    echo "  CoSpec AI: http://localhost://${COSPEC_PORT}"
    echo "  Firebase: http://localhost:${FIREBASE_PORT}"
    echo "  Firebase UI: http://localhost:${FIREBASE_UI_PORT}"
    echo
    echo "CONTAINER:"
    echo "  Name: $container_name"

    # Check container status
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        echo -e "  Status: ${GREEN}Running${NC}"
        echo "  ID: $(docker ps --filter name="$container_name" --format '{{.ID}}')"
    elif docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        echo -e "  Status: ${YELLOW}Stopped${NC}"
    else
        echo -e "  Status: ${RED}Not created${NC}"
    fi
}

# ============================================================================
# DEVELOPMENT COMMANDS
# ============================================================================

cmd_wp() {
    local instance_name="${1:-}"
    shift || true

    if [[ -z "$instance_name" ]]; then
        log_error "Instance name is required"
        echo "Usage: $0 wp <instance-name> <wp-cli-command>"
        return 1
    fi

    local container_name
    container_name="$(get_container_name "$instance_name")"

    if ! docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        log_error "Container '$container_name' is not running"
        return 1
    fi

    docker exec "$container_name" wp "$@" --allow-root
}

cmd_schema() {
    local action="$1"
    shift

    local instance_name="${1:-}"
    shift || true

    case "$action" in
        list)
            cmd_wp "$instance_name" schema list --allow-root
            ;;
        validate)
            if [[ -z "${1:-}" ]]; then
                log_error "Post type is required for validation"
                return 1
            fi
            cmd_wp "$instance_name" schema validate "$@" --allow-root
            ;;
        register)
            if [[ -z "${1:-}" ]]; then
                log_error "Post type is required for registration"
                return 1
            fi
            cmd_wp "$instance_name" schema register --post_type="$@" --allow-root
            ;;
        export)
            if [[ -z "${1:-}" ]]; then
                log_error "Post type is required for export"
                return 1
            fi
            cmd_wp "$instance_name" schema export "$@" --allow-root
            ;;
        export-all)
            cmd_wp "$instance_name" schema export-all "$@" --allow-root
            ;;
        *)
            log_error "Unknown schema action: $action"
            echo "Available actions: list, validate, register, export, export-all"
            return 1
            ;;
    esac
}

cmd_ai() {
    local action="$1"
    shift

    local instance_name="${1:-}"
    shift || true

    case "$action" in
        generate-alt-text)
            cmd_wp "$instance_name" ignis-ai generate-alt-text --allow-root
            ;;
        generate-content)
            if [[ -z "${1:-}" ]] || [[ -z "${2:-}" ]]; then
                log_error "Post ID and field name are required"
                return 1
            fi
            cmd_wp "$instance_name" ignis-ai generate-content "$@" --allow-root
            ;;
        generate-form)
            if [[ -z "${1:-}" ]]; then
                log_error "Description is required"
                return 1
            fi
            cmd_wp "$instance_name" ignis-ai generate-form "$@" --allow-root
            ;;
        *)
            log_error "Unknown AI action: $action"
            echo "Available actions: generate-alt-text, generate-content, generate-form"
            return 1
            ;;
    esac
}

# ============================================================================
# TROUBLESHOOTING COMMANDS
# ============================================================================

cmd_logs() {
    local container_name="$1"
    local follow=false
    local tail_lines=""

    if [[ "$1" == "--follow" ]] || [[ "$2" == "--follow" ]]; then
        follow=true
    fi

    if [[ "$1" == "--tail" ]]; then
        tail_lines="$2"
        shift 2
    fi

    if [[ -z "$container_name" ]]; then
        log_error "Container name is required"
        echo "Usage: $0 logs <container-name> [--follow] [--tail <lines>]"
        return 1
    fi

    if [[ "$follow" == true ]]; then
        docker logs -f "$container_name"
    elif [[ -n "$tail_lines" ]]; then
        docker logs --tail "$tail_lines" "$container_name"
    else
        docker logs "$container_name"
    fi
}

cmd_shell() {
    local container_name="$1"

    if [[ -z "$container_name" ]]; then
        log_error "Container name is required"
        echo "Usage: $0 shell <container-name>"
        return 1
    fi

    log_info "Opening shell in container: $container_name"
    docker exec -it "$container_name" bash
}

cmd_doctor() {
    log_info "Running IgniStack diagnostics..."
    echo

    # Check Docker
    echo -n "Docker installation: "
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}OK${NC} ($(docker --version))"
    else
        echo -e "${RED}FAILED${NC} - Docker not installed"
        return 1
    fi

    echo -n "Docker daemon: "
    if docker info &> /dev/null; then
        echo -e "${GREEN}Running${NC}"
    else
        echo -e "${RED}Not running${NC}"
        return 1
    fi

    # Check image
    echo -n "IgniStack image: "
    if docker image inspect "$IGNISTACK_IMAGE" &> /dev/null; then
        echo -e "${GREEN}OK${NC} ($IGNISTACK_IMAGE)"
    else
        echo -e "${YELLOW}Not found${NC} - Run '$0 init' to pull"
    fi

    # Check instances directory
    echo -n "Instances directory: "
    if [[ -d "$INSTANCES_ROOT" ]]; then
        echo -e "${GREEN}OK${NC} ($INSTANCES_ROOT)"
    else
        echo -e "${YELLOW}Not found${NC} - Will be created on first use"
    fi

    # List instances
    echo
    echo "Instances:"
    if [[ -d "$INSTANCES_ROOT" ]]; then
        local count=0
        for instance_dir in "$INSTANCES_ROOT"/*; do
            [[ ! -d "$instance_dir" ]] && continue
            local name
            name="$(basename "$instance_dir")"
            echo "  - $name"
            ((count++))
        done
        if [[ $count -eq 0 ]]; then
            echo "  (none)"
        fi
    else
        echo "  (none)"
    fi

    echo
    log_success "Diagnostics complete"
}

# ============================================================================
# MAIN
# ============================================================================

show_help() {
    cat <<EOF
IgniStack CLI - Unified command interface for IgniStack Sandbox

USAGE:
    $0 <command> [options]

COMMANDS:
    Environment Setup:
        init <project-name>         Initialize a new IgniStack environment
        create-instance <name>      Create a new WordPress instance
        list                        List all instances

    Instance Management:
        start <name>                Start an instance
        stop <name>                 Stop an instance
        restart <name>              Restart an instance
        info <name>                 Show instance details
        remove <name>               Remove an instance (permanent!)

    Development:
        wp <name> <command>         Run WP-CLI command in instance
        schema <action> <name>      Manage schemas (list, validate, register, export)
        ai <action> <name>          Run AI operations

    Troubleshooting:
        logs <container>            Show container logs
        shell <container>           Open shell in container
        doctor                      Run diagnostics

    help                            Show this help message

EXAMPLES:
    $0 init my-project --port 8080
    $0 create-instance production --port 8081
    $0 start my-project
    $0 wp my-project plugin list
    $0 schema export-all my-project

For more information, visit: https://github.com/misterlex223/ignistack-sandbox
EOF
}

main() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi

    local command="$1"
    shift

    case "$command" in
        init)
            cmd_init "$@"
            ;;
        create-instance)
            cmd_create_instance "$@"
            ;;
        list|ls)
            cmd_list
            ;;
        start)
            cmd_start "$@"
            ;;
        stop)
            cmd_stop "$@"
            ;;
        restart)
            cmd_restart "$@"
            ;;
        info)
            cmd_info "$@"
            ;;
        remove|rm)
            cmd_remove "$@"
            ;;
        wp)
            cmd_wp "$@"
            ;;
        schema)
            cmd_schema "$@"
            ;;
        ai)
            cmd_ai "$@"
            ;;
        logs)
            cmd_logs "$@"
            ;;
        shell)
            cmd_shell "$@"
            ;;
        doctor)
            cmd_doctor
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
}

main "$@"
