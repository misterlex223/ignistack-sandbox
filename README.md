# IgniStack Sandbox

A complete Docker-based development environment for building modern web applications with the **IgniStack**: React + Vite frontend, Firebase backend, and WordPress CMS powered by SQLite.

## What is IgniStack?

IgniStack is a modern, AI-powered development stack that combines:

- **Frontend**: React + Vite for fast, modern web applications
- **Backend**: Firebase (Firestore, Auth, Functions) for scalable serverless infrastructure
- **CMS**: WordPress with SQLite for content management without database servers
- **Synchronization**: Automatic sync between WordPress and Firebase
- **AI Integration**: Built-in AI capabilities for content generation and schema management
- **Schema System**: Code-first approach to WordPress custom post types with TypeScript generation

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    IgniStack Sandbox                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐  │
│  │   React +    │   │   Firebase   │   │  WordPress   │  │
│  │     Vite     │◄──┤   Backend    │◄──┤  + SQLite    │  │
│  │   Frontend   │   │  (Firestore) │   │     CMS      │  │
│  └──────────────┘   └──────────────┘   └──────────────┘  │
│         ▲                                      │           │
│         │                                      │           │
│         └──────────────────────────────────────┘           │
│              TypeScript Types & REST API                   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │           WordPress Plugin Ecosystem                │  │
│  ├─────────────────────────────────────────────────────┤  │
│  │  • ignis-schema-wp: Schema-based custom post types │  │
│  │  • ignis-ai: AI content generation (Claude)        │  │
│  │  • sync-fire-wp: WordPress ↔ Firebase sync         │  │
│  │  • ACF: Advanced Custom Fields engine              │  │
│  │  • SQLite Integration: Database layer              │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Key Features

### Development Environment
- **Persistent WordPress Instances**: Multiple isolated WordPress installations with persistent data
- **SQLite Database**: No MySQL required - portable, single-file database
- **Hot Reload**: React + Vite with instant HMR (Hot Module Replacement)
- **Firebase Emulators**: Local Firebase development with Firestore, Auth, and Functions
- **WebTTY**: Browser-based terminal with tmux for collaborative sessions
- **CoSpec AI**: Markdown editor for documentation and notes

### WordPress Plugin Stack
- **ignis-schema-wp**: Define custom post types using YAML/JSON schemas, generate TypeScript types
- **ignis-ai**: AI-powered content generation, alt text, and SEO optimization using Claude
- **sync-fire-wp**: Real-time synchronization of WordPress content to Firebase Firestore
- **ACF (Advanced Custom Fields)**: Flexible custom field management (required by schema system)
- **SQLite Integration**: WordPress database layer using SQLite instead of MySQL

### AI-Powered Workflow
- **Schema-First Development**: Define schemas in YAML, auto-generate WordPress CPTs and TypeScript types
- **AI Content Generation**: Claude-powered content creation for text fields and images
- **Automated SEO**: AI-driven SEO analysis and meta description generation
- **Image Analysis**: Automatic alt text generation using Claude's vision API

### Developer Tools
- Node.js (LTS), npm, npx, Python 3
- Git, GitHub CLI (gh)
- Claude Code CLI
- Firebase CLI (firebase-tools)
- WP-CLI (WordPress command-line interface)
- PHP 8.4 with SQLite3 extension

## Quick Start

### 1. Build the Docker Image

```bash
./host-scripts/build-docker.sh
```

### 2. Create a WordPress Instance

```bash
# Create a persistent development instance
./host-scripts/create-wp-instance.sh create my-project --port 8080

# Access WordPress at http://localhost:8080
# Default credentials: admin / password123
```

### 3. Set Up Your Project

```bash
# Create sandbox with workspace mount
./host-scripts/create-ignis-sandbox.sh \
  --name my-project \
  --wp-instance my-project \
  --port 8080 \
  --mount /path/to/your/project
```

### 4. Start Developing

Your IgniStack environment is now ready with:
- WordPress CMS at `http://localhost:8080`
- WebTTY terminal at `http://localhost:9681`
- CoSpec AI editor at `http://localhost:9280`
- React dev server (start with `npm run dev`)
- Firebase emulators (start with `firebase emulators:start`)

## Complete Development Workflow

### Step 1: Define Your Schema

Create a schema file for your custom post type:

```yaml
# workspace/schemas/product.yaml
post_type: product
label: Products
description: E-commerce products
fields:
  product_name:
    type: text
    label: Product Name
    required: true
  price:
    type: number
    label: Price (USD)
    min: 0
    prepend: "$"
  description:
    type: wysiwyg
    label: Description
  featured_image:
    type: image
    label: Product Image
```

### Step 2: Register Schema in WordPress

```bash
# Copy schema to WordPress
docker exec ignistack-wp-my-project cp \
  /home/flexy/workspace/schemas/product.yaml \
  /home/flexy/wordpress-persistent/wp-content/schemas/post-types/

# Validate and register
docker exec ignistack-wp-my-project wp schema validate product --allow-root
docker exec ignistack-wp-my-project wp schema register --post_type=product --allow-root
```

### Step 3: Generate TypeScript Types

```bash
# Generate TypeScript types for your frontend
docker exec ignistack-wp-my-project wp schema export product \
  --output=/home/flexy/workspace/frontend/src/types \
  --allow-root
```

### Step 4: Create Content with AI

In WordPress admin:
1. Go to Products → Add New
2. Enter product name
3. Click "Generate with AI" on the description field
4. Upload product image (alt text generated automatically)
5. Click "Analyze SEO" for optimization suggestions
6. Publish

### Step 5: Sync to Firebase

Content automatically syncs to Firestore via `sync-fire-wp` plugin.

### Step 6: Use in React Frontend

```typescript
// frontend/src/components/ProductList.tsx
import { Product } from '../types/product';

const ProductList: React.FC = () => {
  const [products, setProducts] = useState<Product[]>([]);

  useEffect(() => {
    // Fetch from WordPress REST API
    fetch('http://localhost:8080/wp-json/wp/v2/products')
      .then(res => res.json())
      .then(setProducts);

    // Or fetch from Firebase (already synced)
    // const unsubscribe = onSnapshot(
    //   collection(db, 'products'),
    //   snapshot => setProducts(snapshot.docs.map(doc => doc.data()))
    // );
  }, []);

  return (
    <div>
      {products.map(product => (
        <div key={product.id}>
          <h2>{product.acf.product_name}</h2>
          <p>${product.acf.price}</p>
          <img src={product.acf.featured_image.url}
               alt={product.acf.featured_image.alt} />
        </div>
      ))}
    </div>
  );
};
```

## WordPress Plugins Deep Dive

### ignis-schema-wp: Schema System

**GitHub**: https://github.com/misterlex223/ignis-schema-wp

Define WordPress custom post types using YAML/JSON schemas instead of UI clicks.

**Key Features**:
- Schema-based CPT definition (YAML/JSON)
- TypeScript type generation for React
- WP-CLI commands for validation and registration
- Automatic REST API exposure
- Built on top of ACF

**Common Commands**:
```bash
wp schema list                          # List all schemas
wp schema validate <post-type>          # Validate schema syntax
wp schema register --post_type=<type>   # Register schema in WordPress
wp schema export <post-type>            # Export TypeScript types
wp schema export-all --output=./types   # Export all types
wp schema import <file-path>            # Import a schema file from any location
```

**Import Command**:
The import command allows you to import schema files from any location directly into the appropriate schema directories:

```bash
# Import a YAML file from any location (no need to remember the exact schema path)
wp schema import /path/to/product.yaml

# Import as a specific type
wp schema import ~/Downloads/event.yaml --type=post-type
wp schema import ./category.yaml --type=taxonomy

# Import with custom slug
wp schema import ./my-schema.yaml --slug=custom-name

# Overwrite existing schema
wp schema import product.yaml --overwrite
```

The import command will validate the schema file, copy it to the correct directory (either `wp-content/schemas/post-types` or `wp-content/schemas/taxonomies`), and provide next steps for registration.

**Learn More**: See [docs/SCHEMA-SYSTEM-INTEGRATION.md](docs/SCHEMA-SYSTEM-INTEGRATION.md)

### ignis-ai: AI Content Generation

AI-powered WordPress plugin using Claude for content creation.

**Key Features**:
- Automatic image alt text generation (Claude vision API)
- AI content generation for ACF fields
- ACF field group generator from natural language
- SEO analysis and optimization
- WP-CLI support for bulk operations

**Usage**:
```bash
# Generate alt text for all images
wp ignis-ai generate-alt-text --allow-root

# Generate content for specific field
wp ignis-ai generate-content <post-id> <field-name> --prompt="..." --allow-root

# Create field group from description
wp ignis-ai generate-form "Product fields: name, price, SKU" \
  --post-type=product --title="Product Info" --allow-root
```

**Configuration**: Set `OPENAI_API_KEY` environment variable (uses Claude via OpenAI compatibility)

**Learn More**: See [docs/AI-INTEGRATION.md](docs/AI-INTEGRATION.md)

### sync-fire-wp: WordPress ↔ Firebase Sync

Synchronizes WordPress Custom Post Types to Firebase Firestore in real-time.

**Key Features**:
- Automatic sync on post save/update/delete
- Configurable post type selection
- Field mapping and transformation
- Real-time updates

**Setup**:
1. Activate plugin in WordPress admin
2. Go to Settings → Sync Fire WP
3. Configure Firebase credentials
4. Select post types to sync
5. Map fields as needed

### Advanced Custom Fields (ACF)

**Required dependency** for `ignis-schema-wp`. ACF provides the field rendering engine while the schema system provides a code-first interface.

**Pre-installed and activated** in all WordPress instances.

### SQLite Integration

Enables WordPress to use SQLite instead of MySQL.

**Benefits**:
- No database server required
- Portable single-file database (`.ht.sqlite`)
- Perfect for development and testing
- Multiple isolated instances

**Location**: `wp-content/database/.ht.sqlite`

**Learn More**: See [docs/SQLITE-INTEGRATION.md](docs/SQLITE-INTEGRATION.md)

## WordPress Instance Management

### Creating Instances

```bash
# Create a development instance
./host-scripts/create-wp-instance.sh create dev --port 8080

# Create a testing instance with custom ports
./host-scripts/create-wp-instance.sh create staging \
  --port 8081 \
  --ttyd-port 9691 \
  --cospec-port 9281

# Create with workspace mount
./host-scripts/create-wp-instance.sh create my-project \
  --port 8080 \
  --mount /path/to/project
```

### Managing Instances

```bash
./host-scripts/create-wp-instance.sh list           # List all instances
./host-scripts/create-wp-instance.sh info dev       # Show instance details
./host-scripts/create-wp-instance.sh start dev      # Start instance
./host-scripts/create-wp-instance.sh stop dev       # Stop instance
./host-scripts/create-wp-instance.sh remove dev     # Delete instance (permanent!)
```

### Instance Data

Persistent WordPress instances are stored in `wordpress-instances/<name>/`:
- `wp-config.php`: WordPress configuration
- `wp-content/`: Themes, plugins, uploads
- `wp-content/database/.ht.sqlite`: SQLite database
- `.instance-info`: Instance metadata

**Backup**: Simply copy the entire instance directory
**Restore**: Copy directory back and start instance

**For detailed management**, see [docs/WORDPRESS-INSTANCES.md](docs/WORDPRESS-INSTANCES.md)

## Advanced Configuration

### Using the Creation Script

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
```

### Manual Docker Commands

For advanced users who want full control:

```bash
# With persistent WordPress instance
docker run -d --name my-sandbox \
  -p 8080:80 \
  -p 9681:9681 \
  -v $(pwd)/wordpress-instances/my-project:/home/flexy/wordpress-persistent \
  -v /path/to/your/project:/home/flexy/workspace \
  -e WP_INSTANCE_NAME=my-project \
  -e OPENAI_API_KEY=your-api-key \
  -e ANTHROPIC_AUTH_TOKEN=your-token \
  -e ENABLE_WEBTTY=true \
  ignistack-dev-sandbox
```

### Accessing Services

Once your container is running:

- **WordPress CMS**: `http://localhost:8080`
- **WordPress Admin**: `http://localhost:8080/wp-admin` (admin/password123)
- **WebTTY Terminal**: `http://localhost:9681`
- **CoSpec AI Editor**: `http://localhost:9280`
- **Firebase Emulator UI**: `http://localhost:5000` (after starting emulators)

### Setting Up Firebase

Inside the container:

```bash
# Login to Firebase
firebase login

# Initialize project
cd /home/flexy/workspace/your-project
firebase init

# Start emulators
firebase emulators:start
```

### Working with React + Vite

```bash
# Inside container
cd /home/flexy/workspace/your-react-app
npm install
npm run dev
```

Your Vite dev server will be available with hot module replacement (HMR).

## Environment Variables Reference

| Variable | Purpose | Required | Default |
|----------|---------|----------|---------|
| `OPENAI_API_KEY` | Claude API key for ignis-ai plugin | For AI features | - |
| `ANTHROPIC_AUTH_TOKEN` | Claude Code CLI authentication | For Claude Code | - |
| `FIREBASE_TOKEN` | Firebase CLI token | Optional | - |
| `WP_INSTANCE_NAME` | WordPress instance identifier | For persistence | - |
| `ENABLE_WEBTTY` | Enable WebTTY terminal | No | `false` |
| `MARKDOWN_DIR` | CoSpec AI workspace directory | No | `/home/flexy/workspace` |

**Note**: WordPress database variables (`WORDPRESS_DB_*`) are **not needed** - SQLite is used automatically.

## Port Reference

| Port | Service | Description |
|------|---------|-------------|
| `80` | WordPress | HTTP server (map to host, e.g., 8080) |
| `9681` | WebTTY | Browser-based terminal with tmux |
| `9280` | CoSpec AI | Markdown editor frontend |
| `5000` | Firebase | Emulator UI |
| `5001` | Firebase | Emulator API |

## Use Cases

### E-Commerce Platform

1. Define product schema (YAML)
2. Register in WordPress
3. Use AI to generate product descriptions and alt text
4. Sync products to Firebase
5. Build React storefront with type-safe API

### Blog with CMS

1. Create blog post schema with custom fields
2. WordPress for content management
3. AI-assisted content creation and SEO
4. React frontend for fast, modern blog
5. Firebase for comments and user engagement

### Portfolio / Agency Site

1. Define project/case study schemas
2. Manage content in WordPress
3. Generate TypeScript types for frontend
4. Build with React + Vite
5. Deploy frontend separately, WordPress as headless CMS

### Multi-Tenant SaaS

1. Multiple WordPress instances per tenant
2. Isolated SQLite databases
3. Shared React frontend
4. Firebase for user data and auth
5. Schema-based content models

## Troubleshooting

### WordPress Installation Loop

**Symptom**: WordPress shows installation screen every time

**Solution**:
```bash
# Check persistent volume is mounted
docker inspect <container-name> | grep wordpress-persistent

# Verify wp-config.php exists
docker exec <container-name> ls /home/flexy/wordpress-persistent/wp-config.php
```

### Port Already in Use

**Symptom**: "port is already allocated" error

**Solution**:
```bash
# Find and stop conflicting container
docker ps | grep 8080
docker stop <container-name>

# Or use different port
./host-scripts/create-wp-instance.sh create dev --port 8081
```

### Schema Not Loading

**Symptom**: `wp schema list` shows no schemas

**Solution**:
```bash
# Check schemas directory
docker exec <container> ls /home/flexy/wordpress-persistent/wp-content/schemas/post-types/

# Ensure proper permissions
docker exec <container> chown -R flexy:flexy /home/flexy/wordpress-persistent/wp-content/schemas

# Check plugin is active
docker exec <container> wp plugin list | grep ignis-schema
```

### AI Features Not Working

**Symptom**: "Generate with AI" buttons not appearing

**Solution**:
```bash
# Verify API key is set
docker exec <container> printenv | grep OPENAI_API_KEY

# Check ignis-ai plugin is active
docker exec <container> wp plugin list | grep ignis-ai

# Check ACF is installed (required dependency)
docker exec <container> wp plugin list | grep advanced-custom-fields
```

### More Help

Check container logs:
```bash
docker logs <container-name>
```

Access container shell:
```bash
docker exec -it <container-name> bash
```

## Documentation

### Core Documentation
- **[docs/WORDPRESS-INSTANCES.md](docs/WORDPRESS-INSTANCES.md)** - WordPress instance management (770 lines)
- **[docs/SQLITE-INTEGRATION.md](docs/SQLITE-INTEGRATION.md)** - SQLite technical details (442 lines)
- **[docs/SCHEMA-SYSTEM-INTEGRATION.md](docs/SCHEMA-SYSTEM-INTEGRATION.md)** - Schema system guide (613 lines)
- **[docs/AI-INTEGRATION.md](docs/AI-INTEGRATION.md)** - AI features and usage (434 lines)

### Plugin Documentation
- **ignis-schema-wp**: https://github.com/misterlex223/ignis-schema-wp
- **ignis-ai**: `/docker/plugins/ignis-ai/README.md`
- **ACF**: https://www.advancedcustomfields.com/resources/

## Project Structure

```
ignistack-sandbox/
├── host-scripts/                    # Host management scripts
│   ├── build-docker.sh              # Build Docker image
│   ├── create-ignis-sandbox.sh      # Create sandbox container
│   └── create-wp-instance.sh        # Manage WordPress instances
├── docker/                          # Docker configuration
│   ├── Dockerfile                   # Image definition
│   ├── init.sh                      # Container initialization
│   └── plugins/                     # Pre-installed plugins
│       └── ignis-ai/                # AI integration plugin
├── cospec-profile/                  # CoSpec AI configuration
├── wordpress-instances/             # Persistent WordPress data (gitignored)
│   └── <instance-name>/
│       ├── wp-config.php
│       ├── wp-content/
│       │   ├── schemas/             # Schema definitions
│       │   ├── database/            # SQLite database
│       │   ├── plugins/
│       │   ├── themes/
│       │   └── uploads/
│       └── .instance-info
├── docs/                            # Documentation
│   ├── WORDPRESS-INSTANCES.md
│   ├── SQLITE-INTEGRATION.md
│   ├── SCHEMA-SYSTEM-INTEGRATION.md
│   └── AI-INTEGRATION.md
└── README.md                        # This file
```

## Command Reference

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

### Schema Management
```bash
wp schema list                                       # List all schemas
wp schema validate <post-type>                       # Validate schema
wp schema register --post_type=<type>                # Register schema
wp schema export <post-type> --output=./types        # Export TypeScript types
wp schema export-all --output=./types                # Export all types
```

### AI Operations
```bash
wp ignis-ai generate-alt-text                        # Generate alt text for images
wp ignis-ai generate-content <id> <field>            # Generate field content
wp ignis-ai generate-form "<description>"            # Generate ACF field group
```

### Container Management
```bash
docker ps                                            # List running containers
docker exec -it <container-name> bash                # Access container shell
docker logs <container-name>                         # View container logs
docker stop <container-name>                         # Stop container
docker restart <container-name>                      # Restart container
```

## Contributing

Issues and pull requests are welcome! Please see individual plugin repositories for plugin-specific contributions.

## License

This project is open-source. Please check individual plugins for their specific licenses.

## Credits

Built with:
- [WordPress](https://wordpress.org/)
- [SQLite Database Integration](https://wordpress.org/plugins/sqlite-database-integration/)
- [Advanced Custom Fields](https://www.advancedcustomfields.com/)
- [Firebase](https://firebase.google.com/)
- [React](https://react.dev/) + [Vite](https://vitejs.dev/)
- [Claude AI](https://www.anthropic.com/claude) by Anthropic

---

**Ready to build modern, AI-powered web applications with IgniStack!** 🚀