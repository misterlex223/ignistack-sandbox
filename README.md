# IgniStack Sandbox

A customized Flexy sandbox environment for developing applications using the IgniStack: React + Vite frontend, Firebase backend, and WordPress CMS with SQLite database and the `sync-fire-wp` plugin for synchronization.

## Features

- **Frontend Development**: Node.js, npm, npx, and all necessary tools for React + Vite development
- **Backend Development**: Firebase CLI tools for Firebase backend development and emulation
- **CMS**: WordPress with PHP 8.1 and SQLite database (no MySQL required!)
- **Persistent WordPress**: Create multiple isolated WordPress instances with persistent data
- **Synchronization**: `sync-fire-wp` plugin to synchronize WordPress Custom Post Types to Firestore
- **Custom Content Management**: Advanced Custom Fields (ACF) plugin pre-installed for creating and managing custom post types and custom fields
- **AI Tools**: Claude Code and CoSpec AI Markdown Editor
- **Terminal**: WebTTY support with tmux for shared terminal sessions
- **Version Control**: Git and GitHub CLI

## Included Tools

- Node.js (LTS version)
- npm and npx
- Python 3 with pip
- Git and GitHub CLI (gh)
- Claude Code CLI
- Firebase CLI (firebase-tools)
- WP-CLI (WordPress command-line interface)
- PHP 8.1 with SQLite3 extension
- SQLite Database Integration plugin for WordPress
- Advanced Custom Fields (ACF) plugin for creating and managing custom post types and custom fields
- ttyd and tmux for WebTTY functionality
- CoSpec AI Markdown Editor (available on ports 9280/9281)

## How to Use

### Building the Image

```bash
./host-scripts/build-docker.sh
```

Or manually:
```bash
docker build -t ignistack-dev-sandbox -f docker/Dockerfile .
```

## WordPress with SQLite

This sandbox uses **SQLite instead of MySQL** for WordPress, making it perfect for development:

- ✅ No separate database server required
- ✅ Portable single-file database
- ✅ Easy backup and restore
- ✅ Multiple isolated WordPress instances

### Quick Start: Persistent WordPress Instance

Create a WordPress instance that persists data between container restarts:

```bash
# Create a development instance
./host-scripts/create-wp-instance.sh create dev --port 8080

# Create a testing instance
./host-scripts/create-wp-instance.sh create testing --port 8081

# List all instances
./host-scripts/create-wp-instance.sh list

# Stop/start instances
./host-scripts/create-wp-instance.sh stop dev
./host-scripts/create-wp-instance.sh start dev
```

Access WordPress at `http://localhost:8080` and complete the installation.

**For detailed WordPress instance management**, see [docs/WORDPRESS-INSTANCES.md](docs/WORDPRESS-INSTANCES.md)

**For SQLite integration details**, see [docs/SQLITE-INTEGRATION.md](docs/SQLITE-INTEGRATION.md)

### Creating a Container

#### Using the Creation Script

Run the script with interactive setup:
```bash
./host-scripts/create-ignis-sandbox.sh
```

Or with command-line options:
```bash
# Create with persistent WordPress
./host-scripts/create-ignis-sandbox.sh \
  --name my-ignistack-env \
  --wp-instance my-project \
  --port 8080 \
  --mount /path/to/your/project \
  --anthropic-token your-token

# Create without persistent WordPress (ephemeral)
./host-scripts/create-ignis-sandbox.sh \
  --name temp-env \
  --port 8080
```

#### Manual Docker Command (Ephemeral WordPress)

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

#### Manual Docker Command (Persistent WordPress)

```bash
# Create instance directory first
mkdir -p wordpress-instances/my-project

docker run -d --name ignistack-sandbox \
  -p 8080:80 \
  -p 9681:9681 \
  -p 9280:9280 \
  -v $(pwd)/wordpress-instances/my-project:/home/flexy/wordpress-persistent \
  -v /path/to/your/project:/home/flexy/workspace \
  -e WP_INSTANCE_NAME=my-project \
  -e ANTHROPIC_AUTH_TOKEN=your-anthropic-token \
  -e ENABLE_WEBTTY=true \
  ignistack-dev-sandbox
```

### Setting Up WordPress

WordPress is **pre-configured with SQLite** and starts automatically when the container launches.

1. Open your browser and go to `http://localhost:8080`

2. Complete the WordPress installation:
   - Choose your language
   - Set site title, username, and password
   - Click "Install WordPress"

3. Log in to WordPress admin panel

4. Activate the `sync-fire-wp` plugin for Firebase synchronization

**Note**: No database configuration needed! SQLite is automatically configured.

### Setting Up Firebase

1. If you haven't already, log in to Firebase:
   ```bash
   firebase login
   ```
   
   Or use the token if you specified one when creating the container.

2. Initialize your Firebase project:
   ```bash
   firebase init
   ```

3. Start the Firebase emulators:
   ```bash
   firebase emulators:start
   ```

### Working with React + Vite

1. Create your React + Vite project in the mounted directory or navigate to an existing one:
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

### Using CoSpec AI

The CoSpec AI Markdown editor is available at `http://localhost:[COSPEC_PORT]` when you expose its port. This is useful for taking notes, documenting your development process, and maintaining a record of your work.

### Using WebTTY

If you enabled WebTTY mode, you can access a shared terminal session at `http://localhost:[TTYD_PORT]`. Multiple users can connect to the same tmux session, making it ideal for collaborative work.

## Environment Variables

- `ANTHROPIC_AUTH_TOKEN`: Token for Claude Code API access
- `FIREBASE_TOKEN`: Token for Firebase CLI (optional if you log in manually)
- `WP_INSTANCE_NAME`: WordPress instance name (for persistent storage)
- `ENABLE_WEBTTY`: Set to `true` to enable WebTTY mode
- `MARKDOWN_DIR`: Directory for CoSpec AI markdown files (default: `/home/flexy/workspace`)

**Note**: WordPress database environment variables (`WORDPRESS_DB_*`) are no longer needed as SQLite is used instead of MySQL.

## Plugin: sync-fire-wp

The `sync-fire-wp` plugin is pre-installed in the WordPress installation. This plugin synchronizes WordPress Custom Post Types to Firestore. To use it:

1. Activate the plugin in the WordPress admin panel
2. Configure the plugin with your Firebase project settings
3. Set up your Custom Post Types for synchronization
4. The plugin will handle synchronization of posts to Firestore

## Ports

- `80`: WordPress HTTP server (mapped to host port, e.g., 8080)
- `9681`: ttyd WebTTY service
- `9280`: CoSpec AI frontend
- `5000`: Firebase Emulator UI
- `5001`: Firebase Emulator API

## Notes

- Ensure your host system meets the requirements for Docker
- WordPress uses SQLite database - no separate database server required
- For production use, ensure all tokens and credentials are properly secured
- Persistent WordPress instances are stored in `wordpress-instances/` directory
- Ephemeral WordPress (default) is located at `/home/flexy/wordpress` inside the container
- The CoSpec AI editor's default directory is `/home/flexy/workspace`, which is also the default mount point for your projects

## Documentation

- **[docs/WORDPRESS-INSTANCES.md](docs/WORDPRESS-INSTANCES.md)** - Complete guide to managing WordPress instances
- **[docs/SQLITE-INTEGRATION.md](docs/SQLITE-INTEGRATION.md)** - Technical details about SQLite integration

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
├── wordpress-instances/       # Persistent WordPress data (gitignored)
├── docs/                      # Documentation
│   ├── WORDPRESS-INSTANCES.md # WordPress instance guide
│   └── SQLITE-INTEGRATION.md  # SQLite technical guide
└── README.md                  # This file
```

## Quick Command Reference

### Build and Setup
```bash
./host-scripts/build-docker.sh                      # Build image
```

### WordPress Instance Management
```bash
./host-scripts/create-wp-instance.sh create <name>  # Create instance
./host-scripts/create-wp-instance.sh list           # List instances
./host-scripts/create-wp-instance.sh start <name>   # Start instance
./host-scripts/create-wp-instance.sh stop <name>    # Stop instance
./host-scripts/create-wp-instance.sh info <name>    # Show instance info
./host-scripts/create-wp-instance.sh remove <name>  # Remove instance
```

### Container Management
```bash
docker ps                                            # List running containers
docker exec -it <container-name> bash                # Access container shell
docker logs <container-name>                         # View container logs
docker stop <container-name>                         # Stop container
```