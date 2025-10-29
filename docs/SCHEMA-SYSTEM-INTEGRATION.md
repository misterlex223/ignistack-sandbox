# IgnisStack Schema System Integration Guide

This guide explains how to integrate the IgnisStack Schema System into the IgniStack Sandbox environment.

## ⚠️ CRITICAL: ACF Dependency

**The IgnisStack Schema System requires ACF (Advanced Custom Fields) to be installed and active.**

The schema system is built **on top of** ACF, not as a replacement. It provides a schema-based interface to ACF, but ACF does the actual field rendering, validation, and data storage.

```
IgnisStack Schema System (YAML/JSON schemas)
           ↓
      ACF Plugin (field engine)
           ↓
   WordPress (storage)
```

## 📍 Location

The IgnisStack Schema System is located at:
```
/docker/ignis-schema-wp/
```

## 🔧 Integration with Docker Container

### Automatic Installation

Add to `docker/Dockerfile` after WordPress installation:

```dockerfile
# STEP 1: Install ACF (REQUIRED DEPENDENCY)
RUN wp plugin install advanced-custom-fields --activate --allow-root --path=/home/flexy/wordpress

# STEP 2: Install IgnisStack Schema System
COPY ignis-schema-wp /home/flexy/wordpress/wp-content/plugins/ignis-schema-wp

# STEP 3: Activate Schema System
RUN wp plugin activate ignis-schema-wp --allow-root --path=/home/flexy/wordpress

# STEP 4: Create schemas directory
RUN mkdir -p /home/flexy/wordpress/wp-content/schemas/post-types && \
    chown -R flexy:flexy /home/flexy/wordpress/wp-content/schemas

# STEP 5: Install YAML parser (optional but recommended)
RUN pecl install yaml && \
    echo "extension=yaml.so" > /usr/local/etc/php/conf.d/yaml.ini
```

### Activation in init.sh

Add to `docker/init.sh` after WordPress is ready:

```bash
# Ensure ACF is active (REQUIRED)
echo "Checking ACF plugin..."
if ! wp plugin is-active advanced-custom-fields --allow-root --path="$WORDPRESS_DIR"; then
    echo "Activating ACF plugin..."
    wp plugin activate advanced-custom-fields --allow-root --path="$WORDPRESS_DIR"
fi

# Activate IgnisStack Schema System plugin
if [ -d "$WORDPRESS_DIR/wp-content/plugins/ignis-schema-wp" ]; then
    echo "Activating Ignis Schema System..."
    wp plugin activate ignis-schema-wp --allow-root --path="$WORDPRESS_DIR"
fi
```

## 📁 Persistent Schemas

### For Persistent WordPress Instances

When creating a persistent WordPress instance, schemas should be included:

```bash
# In host-scripts/create-wp-instance.sh
INSTANCE_DIR="wordpress-instances/$INSTANCE_NAME"

# Create schemas directory in instance
mkdir -p "$INSTANCE_DIR/wp-content/schemas/post-types"

# Copy example schemas
cp docker/ignis-schema-wp/schemas/post-types/*.yaml \
   "$INSTANCE_DIR/wp-content/schemas/post-types/"
```

### Volume Mounting

Mount schemas directory to make it editable from host:

```bash
docker run \
  -v $(pwd)/wordpress-instances/$NAME/wp-content/schemas:/home/flexy/wordpress-persistent/wp-content/schemas \
  # ... other options
```

## 🚀 Usage in IgniStack Workflow

### Scenario 1: Developer with Custom Schemas

Developer has project with custom schemas:

```
my-project/
├── schemas/
│   ├── product.yaml
│   ├── customer.yaml
│   └── order.yaml
└── frontend/
    └── src/
```

**Integration:**

```bash
# Create sandbox with workspace mount
./host-scripts/create-ignis-sandbox.sh \
  --name my-project \
  --mount $(pwd)/my-project \
  --wp-instance my-project-wp \
  --port 8080

# Inside container, link schemas
docker exec ignistack-wp-my-project bash -c "
  ln -sf /home/flexy/workspace/schemas/* \
         /home/flexy/wordpress-persistent/wp-content/schemas/post-types/
  wp schema register --allow-root
"
```

### Scenario 2: AI-Generated Schemas

Developer uses AI (Claude) to generate schemas on-the-fly:

```bash
# Connect to container
docker exec -it ignistack-wp-dev bash

# Use AI to create schema
cat > /home/flexy/workspace/event.yaml << 'EOF'
[AI-generated schema content]
EOF

# Link to WordPress
cp /home/flexy/workspace/event.yaml \
   /home/flexy/wordpress-persistent/wp-content/schemas/post-types/

# Validate and register
wp schema validate event
wp schema register --post_type=event
wp schema flush
```

### Scenario 3: TypeScript Development

Generate types for React/Vite frontend:

```bash
# Inside container
cd /home/flexy/wordpress-persistent
wp schema export-all --output=/home/flexy/workspace/frontend/src/types

# In your React app (frontend/src/api/products.ts)
import { Product, ProductACF } from '../types/product';

const fetchProducts = async (): Promise<Product[]> => {
  const response = await fetch('http://localhost:8080/wp-json/wp/v2/products');
  return response.json();
};
```

## 🔄 Development Workflow

### Step 1: Define Schema

Create schema file (can use AI):

```yaml
# workspace/schemas/book.yaml
post_type: book
label: Books
fields:
  isbn:
    type: text
    label: "ISBN"
    required: true
  author:
    type: text
    label: "Author"
  price:
    type: number
    label: "Price"
    min: 0
    prepend: "$"
```

### Step 2: Install Schema

```bash
# From host
docker exec ignistack-wp-dev cp \
  /home/flexy/workspace/schemas/book.yaml \
  /home/flexy/wordpress-persistent/wp-content/schemas/post-types/

# Or from inside container
cp /home/flexy/workspace/schemas/book.yaml \
   /home/flexy/wordpress-persistent/wp-content/schemas/post-types/
```

### Step 3: Validate & Register

```bash
docker exec ignistack-wp-dev wp schema validate book --allow-root
docker exec ignistack-wp-dev wp schema register --post_type=book --allow-root
docker exec ignistack-wp-dev wp schema flush --allow-root
```

### Step 4: Generate Types

```bash
docker exec ignistack-wp-dev wp schema export book \
  --output=/home/flexy/workspace/frontend/src/types \
  --allow-root
```

### Step 5: Use in Code

```typescript
// frontend/src/components/BookList.tsx
import { Book } from '../types/book';

const BookList: React.FC = () => {
  const [books, setBooks] = useState<Book[]>([]);

  useEffect(() => {
    fetch('http://localhost:8080/wp-json/wp/v2/books')
      .then(res => res.json())
      .then(setBooks);
  }, []);

  return (
    <ul>
      {books.map(book => (
        <li key={book.id}>
          {book.title.rendered} - ${book.acf.price}
        </li>
      ))}
    </ul>
  );
};
```

## 🎨 Directory Structure in Container

```
/home/flexy/
├── wordpress-persistent/              # Persistent WordPress instance
│   └── wp-content/
│       ├── plugins/
│       │   └── ignis-schema-wp/       # Plugin installed here
│       └── schemas/
│           └── post-types/            # Schemas location
│               ├── contact.yaml
│               ├── product.yaml
│               └── book.yaml
└── workspace/                         # Your project workspace
    ├── schemas/                       # Schema source files
    │   └── book.yaml
    └── frontend/
        └── src/
            └── types/                 # Generated TypeScript types
                ├── book.ts
                └── index.ts
```

## 🔌 REST API Access

All schemas are automatically exposed via REST API:

```bash
# From host machine
curl http://localhost:8080/wp-json/wp/v2/books

# Get schema information
curl http://localhost:8080/wp-json/schema-system/v1/schemas

# Get specific schema
curl http://localhost:8080/wp-json/schema-system/v1/schemas/book
```

## 🖥️ WebTTY Integration

Access WordPress CLI via WebTTY:

1. **Open WebTTY:**
   ```
   http://localhost:9681
   ```

2. **Schema Commands:**
   ```bash
   wp schema list
   wp schema info book
   wp schema validate book
   ```

3. **Create Posts:**
   ```bash
   wp post create \
     --post_type=book \
     --post_title="The Great Gatsby" \
     --post_status=publish
   ```

## 🐳 Docker Compose Integration

If using Docker Compose:

```yaml
version: '3.8'

services:
  wordpress:
    build: ./docker
    volumes:
      # Schema system
      - ./docker/ignis-schema-wp:/home/flexy/wordpress/wp-content/plugins/ignis-schema-wp

      # Persistent schemas
      - ./wordpress-instances/${WP_INSTANCE}/wp-content/schemas:/home/flexy/wordpress-persistent/wp-content/schemas

      # Workspace for development
      - ./workspace:/home/flexy/workspace
    environment:
      - WP_INSTANCE_NAME=${WP_INSTANCE}
    ports:
      - "8080:80"
      - "9681:9681"
```

## 🛠️ Helper Scripts

### Auto-Setup Script

Create `host-scripts/setup-schema-system.sh`:

```bash
#!/bin/bash
# Setup IgnisStack Schema System in a running container

CONTAINER_NAME=$1

if [ -z "$CONTAINER_NAME" ]; then
    echo "Usage: $0 <container-name>"
    exit 1
fi

echo "Setting up IgnisStack Schema System in $CONTAINER_NAME..."

# Copy example schemas
docker exec $CONTAINER_NAME bash -c "
    cp /home/flexy/wordpress/wp-content/plugins/ignis-schema-wp/schemas/post-types/*.yaml \
       /home/flexy/wordpress-persistent/wp-content/schemas/post-types/
"

# Register all schemas
docker exec $CONTAINER_NAME wp schema register --allow-root

# Generate TypeScript types
docker exec $CONTAINER_NAME wp schema export-all \
    --output=/home/flexy/workspace/frontend/src/types \
    --allow-root

echo "✓ Schema system setup complete!"
echo ""
echo "Available schemas:"
docker exec $CONTAINER_NAME wp schema list --allow-root
```

### Watch and Auto-Reload

Create `host-scripts/watch-schemas.sh`:

```bash
#!/bin/bash
# Watch schema files and auto-reload on changes

CONTAINER_NAME=$1
WATCH_DIR="./workspace/schemas"

echo "Watching $WATCH_DIR for changes..."

fswatch -o "$WATCH_DIR" | while read change; do
    echo "Schema changed, reloading..."

    docker exec $CONTAINER_NAME bash -c "
        cp /home/flexy/workspace/schemas/*.yaml \
           /home/flexy/wordpress-persistent/wp-content/schemas/post-types/
        wp schema register --allow-root
        wp schema flush --allow-root
    "

    echo "✓ Schemas reloaded"
done
```

## 📊 Monitoring and Debugging

### Check Plugin Status

```bash
docker exec ignistack-wp-dev wp plugin list --allow-root | grep schema
```

### Check Schema Loading

```bash
docker exec ignistack-wp-dev wp schema list --allow-root
```

### View Plugin Logs

```bash
docker logs ignistack-wp-dev | grep -i schema
```

### Debug Mode

Enable WordPress debug mode for schema system:

```bash
# In wp-config.php
define('WP_DEBUG', true);
define('WP_DEBUG_LOG', true);

# View logs
docker exec ignistack-wp-dev tail -f /home/flexy/wordpress-persistent/wp-content/debug.log
```

## 🔐 Security Considerations

### File Permissions

```bash
# Ensure schemas directory is writable
docker exec ignistack-wp-dev bash -c "
    chown -R flexy:flexy /home/flexy/wordpress-persistent/wp-content/schemas
    chmod -R 755 /home/flexy/wordpress-persistent/wp-content/schemas
"
```

### REST API Authentication

When creating/updating posts via REST API:

```javascript
// Use WordPress application passwords or JWT
const headers = {
  'Authorization': 'Basic ' + btoa('username:application_password'),
  'Content-Type': 'application/json'
};

fetch('http://localhost:8080/wp-json/wp/v2/books', {
  method: 'POST',
  headers,
  body: JSON.stringify({
    title: 'New Book',
    status: 'publish',
    acf: {
      isbn: '978-1234567890',
      author: 'John Doe',
      price: 29.99
    }
  })
});
```

## 📝 Best Practices

1. **Version Control Schemas:**
   ```bash
   git add workspace/schemas/*.yaml
   git commit -m "Add book schema"
   ```

2. **Validate Before Deploying:**
   ```bash
   wp schema validate book --allow-root
   ```

3. **Keep Types in Sync:**
   ```bash
   # Run after schema changes
   wp schema export-all --output=/home/flexy/workspace/frontend/src/types
   ```

4. **Use Descriptive Names:**
   - Post types: `product`, `event`, `team_member`
   - Fields: `product_sku`, `event_date`, `member_bio`

5. **Document in Schema:**
   ```yaml
   fields:
     price:
       type: number
       label: "Price"
       instructions: "Enter price in USD"
   ```

## 🎯 Common Integration Patterns

### Pattern 1: Multi-Environment Setup

```bash
# schemas/
├── development/
│   ├── test_product.yaml
│   └── test_user.yaml
└── production/
    ├── product.yaml
    └── user.yaml

# Load appropriate schemas based on environment
if [ "$ENV" = "production" ]; then
    cp schemas/production/*.yaml wp-content/schemas/post-types/
else
    cp schemas/development/*.yaml wp-content/schemas/post-types/
fi
```

### Pattern 2: Shared Schemas Library

```bash
# Create shared schemas repo
git clone https://github.com/company/wordpress-schemas.git schemas-lib

# Link to WordPress
ln -s /home/flexy/workspace/schemas-lib/*.yaml \
      /home/flexy/wordpress-persistent/wp-content/schemas/post-types/
```

### Pattern 3: AI-Generated Dynamic Schemas

```typescript
// Use AI to generate schema from user input
const generateSchema = async (prompt: string) => {
  const schema = await askAI(`
    Create a IgnisStack schema for: ${prompt}
    Format: YAML
  `);

  // Save to file
  await fs.writeFile('workspace/schemas/dynamic.yaml', schema);

  // Install in WordPress
  await docker.exec('cp workspace/schemas/dynamic.yaml ...');
  await docker.exec('wp schema register --post_type=dynamic');
};
```

## 🚦 Troubleshooting Integration

### Plugin Not Activated

```bash
docker exec ignistack-wp-dev wp plugin activate ignis-schema-wp --allow-root
```

### Schemas Not Loading

```bash
# Check directory exists
docker exec ignistack-wp-dev ls -la /home/flexy/wordpress-persistent/wp-content/schemas/post-types/

# Check permissions
docker exec ignistack-wp-dev bash -c "
    chown -R flexy:flexy /home/flexy/wordpress-persistent/wp-content/schemas
"
```

### YAML Parser Missing

```bash
# Install in container
docker exec ignistack-wp-dev bash -c "
    pecl install yaml
    echo 'extension=yaml.so' > /usr/local/etc/php/conf.d/yaml.ini
"

# Restart container
docker restart ignistack-wp-dev
```

---

## ✅ Integration Checklist

- [ ] IgnisStack Schema System copied to Docker image
- [ ] Plugin activated in init.sh
- [ ] Schemas directory created and writable
- [ ] Example schemas installed
- [ ] YAML parser installed (optional)
- [ ] Volume mounts configured for schemas
- [ ] WP-CLI commands working
- [ ] REST API accessible
- [ ] TypeScript generation tested
- [ ] Frontend integration verified

---

**Ready to build modern WordPress applications with AI! 🚀**
