# IgniStack Sandbox - QWEN Context

## Project Overview

IgniStack Sandbox is a containerized development environment designed for building applications using an IgniStack technology stack: React + Vite frontend, Firebase backend, and WordPress CMS. The project provides a complete development environment with AI tools and collaborative features.

### Key Features:
- **Frontend Development**: Complete Node.js, npm, npx environment for React + Vite development
- **Backend Development**: Firebase CLI tools for Firebase backend and emulation
- **CMS**: WordPress with PHP 8.1 and a key feature - SQLite database integration (no MySQL required!)
- **Synchronization**: Custom `sync-fire-wp` plugin to synchronize WordPress Custom Post Types to Firestore
- **AI Tools**: Claude Code and CoSpec AI Markdown Editor integration
- **Collaboration**: WebTTY support with tmux for shared terminal sessions
- **Version Control**: Git and GitHub CLI integration

### Core Architecture:
- Docker-based containerized environment
- Extends base Flexy Dev Sandbox image with IgniStack-specific tools
- SQLite integration for WordPress (eliminating the need for MySQL)
- Persistent WordPress instances capability

## Building and Running

### Prerequisites:
- Docker installed and running
- Anthropic API token (for Claude Code)
- Optional Firebase token for CLI

### Building the Image:
```bash
./host-scripts/build-docker.sh
```
Or manually:
```bash
docker build -t ignistack-dev-sandbox -f docker/Dockerfile .
```

### Creating a Container - Method 1 (Interactive):
```bash
./host-scripts/create-ignis-sandbox.sh
```

### Creating a Container - Method 2 (Command Line):
```bash
# With persistent WordPress
./host-scripts/create-ignis-sandbox.sh \
  --name my-ignistack-env \
  --wp-instance my-project \
  --port 8080 \
  --mount /path/to/your/project \
  --anthropic-token your-token

# Without persistent WordPress (ephemeral)
./host-scripts/create-ignis-sandbox.sh \
  --name temp-env \
  --port 8080
```

### Managing WordPress Instances:
```bash
# Create new instance
./host-scripts/create-wp-instance.sh create dev --port 8080

# List all instances
./host-scripts/create-wp-instance.sh list

# Start/stop instances
./host-scripts/create-wp-instance.sh start dev
./host-scripts/create-wp-instance.sh stop dev

# Show instance info
./host-scripts/create-wp-instance.sh info dev
```

### Manual Docker Command (ephemeral WordPress):
```bash
docker run -d --name ignistack-sandbox \
  -p 8080:80 \
  -p 9681:9681 \
  -p 9280:9280 \
  -v /path/to/your/project:/home/flexy/workspace \
  -e ANTHROPIC_AUTH_TOKEN=your-anthropic-token \
  -e FIREBASE_TOKEN=your-firebase-token \
  -e ENABLE_WEBTTY=true \
  ignistack-dev-sandbox
```

## Project Structure

```
ignistack-sandbox/
├── host-scripts/              # Host management scripts
│   ├── build-docker.sh        # Build Docker image
│   ├── create-ignis-sandbox.sh # Create sandbox container
│   └── create-wp-instance.sh  # Manage WordPress instances
├── docker/                    # Docker configuration
│   ├── Dockerfile             # Image definition
│   └── init.sh                # Container initialization
├── container-scripts/         # Scripts for inside container
│   ├── start-wp.sh            # Start WordPress
│   └── stop-wp.sh             # Stop WordPress
├── wordpress-instances/       # Persistent WordPress data (gitignored)
├── docs/                      # Documentation
│   ├── WORDPRESS-INSTANCES.md # WordPress instance guide
│   └── SQLITE-INTEGRATION.md  # SQLite technical guide
├── .gitignore
├── README.md
└── CLAUDE.md
```

## Key Technologies and Components

### 1. React + Vite Frontend Development:
- Node.js (LTS version)
- npm and npx
- All necessary dependencies for React + Vite development
- Works with mounted project directories

### 2. Firebase Backend:
- Firebase CLI tools installed
- Firebase emulator support
- Environment variables for authentication
- Integration with sync-fire-wp plugin

### 3. WordPress CMS with SQLite:
- PHP 8.1 with SQLite3 extension
- WordPress SQLite Database Integration plugin (official WordPress project)
- Custom `sync-fire-wp` plugin for Firestore synchronization
- **Key feature**: WordPress configured to use SQLite instead of MySQL

### 4. AI Development Tools:
- Claude Code CLI integration
- CoSpec AI Markdown Editor
- Environment variable for Anthropic API token

### 5. Collaboration Features:
- ttyd and tmux for WebTTY functionality
- Shared terminal sessions capability
- Multiple exposed ports for different services

## Working with the Development Environment

### Setting Up WordPress:
1. Access WordPress at `http://localhost:[YOUR_PORT]`
2. Complete the WordPress installation (no database configuration needed due to SQLite)
3. Log in to WordPress admin panel
4. Activate the `sync-fire-wp` plugin for Firebase synchronization

### Working with Firebase:
1. If needed, log in to Firebase:
   ```bash
   firebase login
   ```
   Or use a token if specified when creating the container.

2. Initialize your Firebase project:
   ```bash
   firebase init
   ```

3. Start the Firebase emulators:
   ```bash
   firebase emulators:start
   ```

### Working with React + Vite:
1. Navigate to your mounted project directory:
   ```bash
   cd /home/flexy/workspace/your-react-app
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Start the development server:
   ```bash
   npm run dev
   ```

## WordPress SQLite Integration

The sandbox uses an innovative approach to run WordPress without MySQL by leveraging the official WordPress SQLite Database Integration plugin. This allows:

- No separate database server required
- Portable single-file database
- Easy backup and restore
- Multiple isolated WordPress instances

The integration works by replacing WordPress's default database implementation with a SQLite drop-in (`db.php`) that translates MySQL queries to SQLite-compatible ones.

## Development Conventions

### Environment Variables:
- `ANTHROPIC_AUTH_TOKEN`: Token for Claude Code API access
- `FIREBASE_TOKEN`: Token for Firebase CLI (optional)
- `WP_INSTANCE_NAME`: WordPress instance name for persistent storage
- `ENABLE_WEBTTY`: Set to `true` to enable WebTTY mode
- `MARKDOWN_DIR`: Directory for CoSpec AI markdown files

### Exposed Ports:
- `80`: WordPress HTTP server (mapped to host port, e.g., 8080)
- `9681`: ttyd WebTTY service
- `9280`: CoSpec AI frontend
- `5000`: Firebase Emulator UI
- `5001`: Firebase Emulator API

### Persistent WordPress Instances:
The system provides sophisticated management of multiple WordPress installations:
- Each instance has isolated data
- Instances survive container restarts
- Easy CLI management for creating, starting, stopping, and removing instances
- Custom port mappings for running multiple instances simultaneously

## Key Scripts and Their Purpose

### Host Scripts:
- `build-docker.sh`: Builds the Docker image
- `create-ignis-sandbox.sh`: Creates and manages the main sandbox container
- `create-wp-instance.sh`: Manages persistent WordPress instances

### Container Scripts:
- `start-wp.sh` and `stop-wp.sh`: Control WordPress inside the container

### Docker Configuration:
- `Dockerfile`: Defines the container image with all necessary tools
- `init.sh`: Sets up the container environment on startup

## Troubleshooting

### Common Issues:
1. **Docker not running**: Check with `docker info`
2. **Port conflicts**: Ensure specified ports are not already in use
3. **Token issues**: Ensure API tokens are correctly specified
4. **WordPress install fails**: Check if SQLite integration is working properly

### Persistent WordPress Issues:
- Verify `wordpress-instances/` directory has proper permissions
- Check that the `.instance-info` file exists and is properly configured
- Ensure the SQLite database file exists in the instance directory

### Container Startup Issues:
- Check container logs: `docker logs [container-name]`
- Verify image exists: `docker images | grep ignistack-dev-sandbox`
- Ensure all required volumes and ports are configured properly

## Testing and Validation

To verify everything is working properly:
1. Build the image successfully
2. Create a container with the desired configuration
3. Access WordPress via browser and complete setup
4. Verify Firebase tools work inside the container
5. Test React/Vite development workflow
6. If using persistent instances, verify data survives container restarts

## Security Considerations

- All tokens should be passed as environment variables, not stored in containers
- The SQLite database file should have appropriate permissions
- Container should be run in trusted environments for development only
- Port exposure should be limited to necessary services
- The sync-fire-wp plugin should be configured with appropriate Firebase security rules