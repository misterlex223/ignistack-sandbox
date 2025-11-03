# IgnisAI - AI-Powered WordPress Content Assistant

AI-powered content generation, SEO optimization, and automatic alt text generation for WordPress with Advanced Custom Fields (ACF) integration. Uses Claude API via OpenAI-compatible client.

## Features

### 🖼️ Automatic Image Alt Text Generation
- Automatically generates descriptive alt text when images are uploaded
- Uses Claude's vision capabilities for accurate image analysis
- Bulk generation tool in Media Library
- ACF image field integration
- WP-CLI command for batch processing

### ✍️ ACF Content Generation
- "Generate with AI" buttons on ACF text fields
- Context-aware content generation using post data and other fields
- Supports: text, textarea, wysiwyg, number, email, URL fields
- Real-time AJAX generation in WordPress admin

### 📋 AI Form Generator
- Describe desired fields in natural language
- AI generates complete ACF field group JSON
- Preview before importing
- Supports all major ACF field types
- Automatic field validation and structure

### 📊 SEO Optimization
- AI-powered SEO analysis and scoring
- Automatic meta description generation
- Keyword extraction
- Content improvement suggestions
- Integration with Yoast/Rank Math

## Installation

### Requirements
- WordPress 6.0+
- PHP 8.1+
- Advanced Custom Fields (ACF) plugin (recommended)
- Anthropic Claude API key
- Composer (for development)

### Automatic Installation (via Docker)

The plugin is automatically installed and activated when building the IgniStack sandbox:

```bash
./host-scripts/build-docker.sh
```

### Manual Installation

1. Copy the plugin to WordPress plugins directory:
```bash
cp -r docker/plugins/ignis-ai /path/to/wordpress/wp-content/plugins/
```

2. Install Composer dependencies:
```bash
cd /path/to/wordpress/wp-content/plugins/ignis-ai
composer install --no-dev --optimize-autoloader
```

3. Activate the plugin:
```bash
wp plugin activate ignis-ai
```

## Configuration

### API Key Setup

#### Option 1: Environment Variable (Recommended)
Set `OPENAI_API_KEY` environment variable:

```bash
export OPENAI_API_KEY="sk-xxxxx"
```

In Docker:
```bash
docker run -e OPENAI_API_KEY="sk-xxxxx" ...
```

**Note**: While we use OpenAI's client library, you'll need to configure it to use Claude's API endpoint. The plugin handles this automatically.

#### Option 2: WordPress Admin
Go to **Settings → IgnisAI** and enter your API key.

### Plugin Settings

Navigate to **Settings → IgnisAI** to configure:

- **Enable AI Features**: Master toggle for all AI functionality
- **Auto Generate Alt Text**: Automatically generate alt text on image upload
- **Model**: Choose Claude model (Sonnet 4.5, Opus 4, etc.)
- **Max Tokens**: Maximum length of generated content (100-8192)
- **Temperature**: Creativity level (0.0-1.0)

## Usage

### Automatic Alt Text for Images

**On Upload:**
When enabled, alt text is automatically generated for all uploaded images.

**Bulk Generation:**
1. Go to Media Library
2. Select images
3. Choose "Generate AI Alt Text" from Bulk Actions
4. Click Apply

**WP-CLI:**
```bash
# Generate alt text for all images without it
wp ignis-ai generate-alt-text

# Process maximum 50 images
wp ignis-ai generate-alt-text --limit=50

# Regenerate alt text for all images (override existing)
wp ignis-ai generate-alt-text --force
```

### ACF Content Generation

**In Post Editor:**
1. Edit any post with ACF fields
2. Look for "Generate with AI" button below text fields
3. Click to generate context-aware content
4. Content appears in the field automatically

The AI uses:
- Post title
- Existing content
- Other ACF field values
- Field type and instructions

### AI Form Generator

**Create ACF Field Groups with AI:**

1. Navigate to **Custom Fields → AI Generator**
2. Describe your fields in natural language:
   ```
   Product fields including name (required text),
   price in USD (number), SKU (text),
   detailed description (WYSIWYG editor),
   and a featured image
   ```
3. Enter field group title (e.g., "Product Information")
4. Select post type
5. Click "Generate Field Group"
6. Review the preview
7. Click "Import into ACF"

**WP-CLI:**
```bash
# Generate and preview
wp ignis-ai generate-form "Event fields with date, location, organizer" --preview

# Generate and import
wp ignis-ai generate-form "Book fields: title, author, ISBN, cover image" \
  --post-type=book \
  --title="Book Information"
```

### SEO Optimization

**In Post Editor:**
Look for the "IgnisAI SEO Optimizer" meta box (usually in sidebar):

- **Analyze SEO**: Get AI-powered SEO analysis and score
- **Generate Meta**: Automatically create meta description and keywords
- Edit and save meta description (155 char limit)
- Add relevant keywords

### Content Generation (WP-CLI)

```bash
# Generate content for a field
wp ignis-ai generate-content 123 product_description

# Save generated content
wp ignis-ai generate-content 123 excerpt --save

# Custom prompt
wp ignis-ai generate-content 123 summary \
  --prompt="Write a brief, engaging summary for social media"
```

## Features in Detail

### Content Generation Engine

**Context-Aware Generation:**
- Analyzes post title, content, and custom fields
- Field-type specific prompts (text, textarea, wysiwyg, etc.)
- Uses ACF field instructions for guidance

**Supported Field Types:**
- Text
- Textarea
- WYSIWYG
- Number
- Email
- URL

### Image Analysis

**Vision Capabilities:**
- Analyzes image content using Claude vision
- Generates concise, descriptive alt text (max 125 chars)
- Considers image filename and title for context
- Optimized for accessibility

**Processing:**
- On upload (if enabled)
- Via ACF image field updates
- Bulk processing in Media Library
- WP-CLI batch commands

### Form Generator

**AI Understanding:**
The AI can interpret:
- Field purposes and types
- Required vs optional fields
- Data formats and validation needs
- Relationships between fields

**Generated Field Types:**
- Text, Textarea, WYSIWYG
- Number, Email, URL
- Select, Checkbox, Radio (with choices)
- True/False
- Date Picker, Date Time Picker
- Image, File, Gallery
- Relationship, Post Object

### SEO Optimizer

**Analysis Includes:**
- SEO score (0-100)
- Content quality assessment
- Keyword optimization suggestions
- Meta description quality
- Internal linking opportunities
- Specific, actionable improvements

**Meta Generation:**
- SEO-optimized meta descriptions (155 chars)
- Relevant keyword extraction
- Focus on click-through rate optimization

## API Reference

### PHP Functions

```php
// Get plugin instance
$ignis_ai = ignis_ai();

// Generate text
$content_generator = new IgnisAI_Content_Generator();
$content = $content_generator->generate_field_content( $post_id, $field_name );

// Analyze image
$image_analyzer = new IgnisAI_Image_Analyzer();
$alt_text = $image_analyzer->generate_and_save_alt_text( $attachment_id );

// Generate form
$form_generator = new IgnisAI_Form_Generator();
$field_group = $form_generator->generate_field_group( $description, $post_type );

// SEO optimization
$seo_optimizer = new IgnisAI_SEO_Optimizer();
$meta = $content_generator->generate_meta_description( $post_id );
```

### WP-CLI Commands

```bash
wp ignis-ai generate-alt-text [--limit=<n>] [--force]
wp ignis-ai generate-form <description> [--post-type=<type>] [--title=<title>] [--preview]
wp ignis-ai generate-content <post_id> <field_name> [--prompt=<text>] [--save]
```

## Troubleshooting

### API Key Issues

**Error: "No API key configured"**
- Check `OPENAI_API_KEY` environment variable
- OR set API key in Settings → IgnisAI

### Composer Dependencies

**Error: "Composer dependencies not found"**
```bash
cd /path/to/plugins/ignis-ai
composer install --no-dev --optimize-autoloader
```

### ACF Integration

**"Generate with AI" buttons not showing:**
- Ensure ACF plugin is active
- Check that you're editing an existing post (not creating new)
- Verify AI features are enabled in settings

### Image Alt Text

**Alt text not generating:**
- Check API key is valid
- Verify Claude vision model is available
- Ensure images are accessible via URL
- Check WordPress error logs

**Tips to reduce costs:**
1. Enable auto-alt-text only when needed
2. Use bulk operations instead of individual requests
3. Lower max_tokens for shorter content
4. Use GPT-5 mini instead of GPT-5 for most tasks
5. Cache frequently generated content

## Security

**Best Practices:**
- Never commit API keys to version control
- Use environment variables for API keys
- Restrict plugin settings to administrators only
- Implement rate limiting for public-facing features
- Regularly rotate API keys

## Compatibility

**Tested with:**
- WordPress 6.4+
- PHP 8.1, 8.2, 8.3
- SQLite (via WordPress SQLite Integration plugin)
- MySQL/MariaDB
- ACF 6.0+

**Known Compatible Plugins:**
- Advanced Custom Fields (ACF) - Full integration
- Yoast SEO - Meta field integration
- Rank Math - Meta field integration
- WP-CLI - Full command support

**Known Incompatibilities:**
- None reported

## Development

### Directory Structure
```
ignis-ai/
├── ignis-ai.php              # Main plugin file
├── composer.json             # Composer dependencies
├── includes/                 # Core classes
│   ├── class-ai-client.php
│   ├── class-content-generator.php
│   ├── class-image-analyzer.php
│   ├── class-seo-optimizer.php
│   ├── class-acf-integration.php
│   ├── class-form-generator.php
│   └── class-cli-commands.php
├── admin/                    # Admin UI classes
│   ├── class-admin-settings.php
│   └── class-admin-ui.php
└── assets/                   # Frontend assets
    ├── js/
    │   ├── acf-integration.js
    │   └── admin.js
    └── css/
        ├── acf-integration.css
        └── admin.css
```

### Adding New Features

**Extend Content Generator:**
```php
add_filter( 'ignis_ai_field_prompt', function( $prompt, $field_info, $context ) {
    // Customize prompt for specific field types
    if ( $field_info['type'] === 'my_custom_type' ) {
        $prompt .= "\nAdditional instructions for my_custom_type...";
    }
    return $prompt;
}, 10, 3 );
```

**Custom AI Model:**
```php
add_filter( 'ignis_ai_model', function( $model ) {
    return 'claude-opus-4-20250514'; // Use Opus instead of Sonnet
});
```

## Support

**Issues:**
Report bugs at: https://github.com/misterlex223/ignistack-sandbox/issues

**Documentation:**
Full IgniStack docs: https://github.com/misterlex223/ignistack-sandbox

## License

GPL v2 or later

## Credits

- Built for IgniStack Sandbox
- Powered by Anthropic Claude API
- Uses openai-php/client for API communication
- Integrates with Advanced Custom Fields (ACF)

## Changelog

### 1.0.0 (2025-01-XX)
- Initial release
- Automatic alt text generation
- ACF field content generation
- AI-powered form generator
- SEO optimization tools
- WP-CLI commands
- Full SQLite compatibility
