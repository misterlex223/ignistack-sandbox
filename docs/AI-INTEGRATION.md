# AI Integration in IgniStack Sandbox

Complete guide to using AI features in the IgniStack WordPress environment.

## Overview

The IgniStack sandbox includes **IgnisAI**, a comprehensive WordPress plugin that integrates Claude AI capabilities into your WordPress workflow. Built specifically for the IgniStack environment, it provides:

- Automatic alt text generation for images
- AI-powered content generation for ACF fields
- ACF field group generator (describe fields, AI creates them)
- SEO optimization and analysis
- Full WP-CLI support

## Quick Start

### 1. Build the Image

```bash
./host-scripts/build-docker.sh
```

The IgnisAI plugin is automatically included and will be activated on first run.

### 2. Create WordPress Instance with AI

```bash
./host-scripts/create-wp-instance.sh create my-ai-project --port 8080
```

The plugin auto-activates and configures itself using the `OPENAI_API_KEY` environment variable.

### 3. Verify Installation

Access WordPress admin at `http://localhost:8080/wp-admin`:
- Username: `admin`
- Password: `password123`

Check that IgnisAI is active:
```bash
docker exec ignistack-wp-my-ai-project wp plugin list
```

You should see `ignis-ai` as "active".

## Features

### Automatic Image Alt Text

**How it works:**
When you upload an image to WordPress (or add one to an ACF image field), Claude's vision API analyzes the image and generates descriptive alt text automatically.

**Try it:**
1. Go to Media → Add New
2. Upload an image
3. Check the attachment details - alt text is generated automatically
4. The alt text appears in the "Alternative Text" field

**Bulk Processing:**
```bash
# Generate alt text for all images
docker exec ignistack-wp-my-ai-project wp ignis-ai generate-alt-text

# Process first 20 images
docker exec ignistack-wp-my-ai-project wp ignis-ai generate-alt-text --limit=20
```

### ACF Content Generation

**How it works:**
When editing posts with ACF fields, you'll see "Generate with AI" buttons below text fields. Click to generate content based on your post context.

**Try it:**
1. Edit any post with ACF fields
2. Look for the "Generate with AI" button below ACF text/textarea fields
3. Click the button
4. AI-generated content appears in the field

**What it considers:**
- Post title and content
- Other ACF field values
- Field type and instructions
- Post type context

### AI Form Generator

**How it works:**
Describe the fields you need in natural language, and AI generates a complete ACF field group with appropriate field types, labels, and settings.

**Try it:**
1. Go to Custom Fields → AI Generator
2. Describe your fields:
   ```
   Product catalog fields: product name (required), price in USD,
   SKU number, product category (select: electronics, clothing, books),
   detailed description, and featured product image
   ```
3. Enter a title: "Product Information"
4. Select post type: "Post" (or create custom post type first)
5. Click "Generate Field Group"
6. Review the generated fields
7. Click "Import into ACF"

**WP-CLI:**
```bash
docker exec ignistack-wp-my-ai-project wp ignis-ai generate-form \
  "Event fields: event name, date and time, location, organizer contact email" \
  --post-type=event \
  --title="Event Details"
```

### SEO Optimization

**How it works:**
AI analyzes your content and provides SEO scoring, suggestions, and can generate optimized meta descriptions and keywords.

**Try it:**
1. Edit any post
2. Look for "IgnisAI SEO Optimizer" meta box (sidebar)
3. Click "Analyze SEO" for AI-powered analysis
4. Click "Generate Meta" to create meta description and keywords
5. Review and edit as needed
6. Save post

## Integration with IgniStack Components

### ACF + Schema System + AI

The IgnisAI plugin works seamlessly with the ignis-schema-wp plugin:

1. **Define Schema** (ignis-schema-wp):
   ```yaml
   # wp-content/schemas/post-types/product.yaml
   post_type: product
   label: Products
   fields:
     - name: product_name
       type: text
       label: Product Name
     - name: description
       type: wysiwyg
       label: Description
   ```

2. **AI Enhances Fields** (ignis-ai):
   - Generate descriptions automatically
   - Analyze and optimize content
   - Generate alt text for product images

3. **Sync to Firebase** (sync-fire-wp):
   - AI-generated content syncs to Firestore
   - Available in React frontend via generated TypeScript types

### React Frontend Integration

While IgnisAI focuses on WordPress admin, the generated content is available to your React app:

```typescript
// React component using AI-generated content
import { Product } from './types/product';

const ProductCard: React.FC<{ product: Product }> = ({ product }) => {
  return (
    <div>
      <h2>{product.acf.product_name}</h2>
      {/* AI-generated description */}
      <div dangerouslySetInnerHTML={{ __html: product.acf.description }} />
      {/* AI-generated alt text */}
      <img
        src={product.acf.product_image.url}
        alt={product.acf.product_image.alt}
      />
    </div>
  );
};
```

## Configuration

### API Key

The plugin automatically uses `OPENAI_API_KEY` from the environment. To change it:

**Option 1: Environment Variable** (recommended)
```bash
docker run -e OPENAI_API_KEY="sk-your-api-key" ...
```

**Option 2: WordPress Admin**
1. Go to Settings → IgnisAI
2. Enter your API key
3. Save changes

### Plugin Settings

**Settings → IgnisAI:**

- **Enable AI Features**: Master on/off switch
- **Auto Generate Alt Text**: Enable/disable automatic alt text on upload
- **Model**: Choose Claude model:
  - GPT-5 mini (recommended, balanced cost/quality)
  - GPT-5 (highest quality, higher cost)
  - GPT-5 nano (fast, lower cost)
- **Max Tokens**: 100-8192 (controls length)
- **Temperature**: 0.0-1.0 (0 = conservative, 1 = creative)

## Advanced Usage

### Custom Prompts (WP-CLI)

```bash
# Generate content with custom prompt
docker exec ignistack-wp-my-ai-project wp ignis-ai generate-content 123 summary \
  --prompt="Write a compelling 2-sentence summary that emphasizes benefits" \
  --save
```

### Batch Operations

```bash
# Generate alt text for all images
docker exec ignistack-wp-my-ai-project wp ignis-ai generate-alt-text --force

# Create multiple field groups
docker exec ignistack-wp-my-ai-project wp ignis-ai generate-form \
  "User profile: bio, avatar, social links" --post-type=user

docker exec ignistack-wp-my-ai-project wp ignis-ai generate-form \
  "Recipe: ingredients list, cooking time, difficulty level" --post-type=recipe
```

### Programmatic Access

```php
// In your theme or plugin
$content_generator = new IgnisAI_Content_Generator();

// Generate product description
$post_id = 123;
$description = $content_generator->generate_field_content(
    $post_id,
    'product_description',
    'Create a compelling product description highlighting key features'
);

if ( ! is_wp_error( $description ) ) {
    update_field( 'product_description', $description, $post_id );
}
```

## Workflow Examples

### E-Commerce Product Entry

1. **Create Product Post** (manual):
   - Add product name
   - Add price

2. **AI Generates** (automatic):
   - Product description (click "Generate with AI")
   - Alt text for product images (on upload)
   - SEO meta description (click "Generate Meta")
   - Keywords for SEO

3. **Sync to Firebase** (automatic):
   - All AI-generated content syncs via sync-fire-wp
   - Available in React storefront

### Blog Post Workflow

1. **Write Main Content** (manual)
2. **AI Enhances**:
   - Generate excerpt
   - Create meta description
   - Analyze SEO and get suggestions
   - Generate alt text for images
3. **Publish**: All optimized for search engines

### Event Management

1. **Generate Event Fields** (one-time):
   ```bash
   wp ignis-ai generate-form "Event fields: name, date, location, capacity" \
     --post-type=event --title="Event Information"
   ```

2. **Create Events**:
   - Fill basic info (name, date, location)
   - AI generates detailed description
   - AI creates alt text for event banner

3. **Frontend**:
   - Events display with AI-generated descriptions
   - Optimized for search

## Troubleshooting

### Plugin Not Activating

Check logs:
```bash
docker logs ignistack-wp-my-ai-project
```

Look for:
```
Activating ignis-ai plugin...
ignis-ai plugin activated successfully.
```

If not found, manually activate:
```bash
docker exec ignistack-wp-my-ai-project wp plugin activate ignis-ai
```

### API Key Not Working

**Check environment variable:**
```bash
docker exec ignistack-wp-my-ai-project printenv | grep OPENAI
```

**Check WordPress options:**
```bash
docker exec ignistack-wp-my-ai-project wp option get ignis_ai_api_key
```

**Test API connection:**
```bash
docker exec ignistack-wp-my-ai-project wp ignis-ai generate-content 1 test_field \
  --prompt="Say hello"
```

### Composer Dependencies Missing

If you see "Composer dependencies not found" error:
```bash
docker exec ignistack-wp-my-ai-project bash -c \
  "cd /home/flexy/wordpress/wp-content/plugins/ignis-ai && composer install"
```

### Generate Buttons Not Showing

**Verify ACF is active:**
```bash
docker exec ignistack-wp-my-ai-project wp plugin list | grep advanced-custom-fields
```

**Clear cache:**
```bash
docker exec ignistack-wp-my-ai-project wp cache flush
```

**Check browser console** for JavaScript errors

## Performance & Costs

### API Usage

Typical costs (approximate):
- **Alt text**: $0.002 per image
- **Field content**: $0.01-0.05 per field
- **Form generation**: $0.05-0.10 per field group
- **SEO analysis**: $0.02-0.05 per post

### Optimization Tips

1. **Use auto-alt-text selectively**: Enable only for production sites
2. **Batch operations**: Process multiple items at once
3. **Lower max_tokens**: Reduce for shorter content needs
4. **Choose right model**: Use Sonnet for most tasks, Opus only when needed
5. **Cache results**: Don't regenerate unnecessarily

### Rate Limiting

The plugin includes basic rate limiting:
- 100 requests per user per hour (adjustable)
- Prevents accidental mass usage
- Logs all API calls for monitoring

## SQLite Compatibility

IgnisAI is fully compatible with WordPress + SQLite:

✅ **Tested and Working:**
- All database operations use WordPress APIs
- No MySQL-specific queries
- Full functionality with SQLite Database Integration plugin
- Persistent data across container restarts

## Security Best Practices

1. **Never commit API keys**: Always use environment variables
2. **Restrict settings**: Only administrators can change IgnisAI settings
3. **Monitor usage**: Check API usage regularly in Anthropic dashboard
4. **Rotate keys**: Change API keys periodically
5. **Review generated content**: Always review AI-generated content before publishing

## Future Enhancements

Planned features:
- Custom post type generation via AI
- Multi-language content generation
- Content variation testing (A/B)
- Automated content updates/improvements
- Integration with more SEO plugins
- Custom AI training on your content style

## Resources

- **Plugin README**: `/wp-content/plugins/ignis-ai/README.md`
- **IgniStack Docs**: `docs/WORDPRESS-INSTANCES.md`
- **ACF Documentation**: https://www.advancedcustomfields.com/
- **Claude API Docs**: https://docs.anthropic.com/
- **GitHub Issues**: https://github.com/misterlex223/ignistack-sandbox/issues

## Getting Help

**Check Status:**
```bash
docker exec ignistack-wp-my-ai-project wp plugin list
docker logs ignistack-wp-my-ai-project | grep ignis
```

**System Status** in WordPress:
Go to Settings → IgnisAI and check the "System Status" section.

**Report Issues:**
https://github.com/misterlex223/ignistack-sandbox/issues

---

**Happy AI-powered content creation! 🚀**
