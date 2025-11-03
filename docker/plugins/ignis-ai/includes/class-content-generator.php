<?php
/**
 * Content Generator Class
 *
 * Generates content for posts, pages, and ACF fields using AI
 *
 * @package IgnisAI
 */

// Exit if accessed directly
if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

/**
 * Content Generator class
 */
class IgnisAI_Content_Generator {

    /**
     * AI Client instance
     *
     * @var IgnisAI_Client
     */
    private $ai_client;

    /**
     * Constructor
     */
    public function __construct() {
        $this->ai_client = new IgnisAI_Client();
    }

    /**
     * Generate content for a specific field
     *
     * @param int    $post_id Post ID
     * @param string $field_name Field name or key
     * @param string $custom_prompt Optional custom prompt
     * @return string|WP_Error Generated content or error
     */
    public function generate_field_content( $post_id, $field_name, $custom_prompt = '' ) {
        // Get post data for context
        $post = get_post( $post_id );
        if ( ! $post ) {
            return new WP_Error( 'invalid_post', __( 'Invalid post ID.', 'ignis-ai' ) );
        }

        // Build context from post
        $context = $this->build_post_context( $post );

        // Get field type and label if it's an ACF field
        $field_info = $this->get_field_info( $field_name, $post_id );

        // Build prompt
        if ( empty( $custom_prompt ) ) {
            $prompt = $this->build_field_prompt( $field_info, $context );
        } else {
            $prompt = $custom_prompt . "\n\n" . $context;
        }

        // Generate content
        return $this->ai_client->generate_text( $prompt );
    }

    /**
     * Build context from post data
     *
     * @param WP_Post $post Post object
     * @return string Context string
     */
    private function build_post_context( $post ) {
        $context = "Context:\n";
        $context .= "Post Type: " . $post->post_type . "\n";
        $context .= "Title: " . $post->post_title . "\n";

        if ( ! empty( $post->post_excerpt ) ) {
            $context .= "Excerpt: " . $post->post_excerpt . "\n";
        }

        if ( ! empty( $post->post_content ) ) {
            $content = wp_strip_all_tags( $post->post_content );
            $content = substr( $content, 0, 500 ); // Limit context length
            $context .= "Content: " . $content . "\n";
        }

        // Include ACF fields for context
        if ( function_exists( 'get_fields' ) ) {
            $acf_fields = get_fields( $post->ID );
            if ( is_array( $acf_fields ) && ! empty( $acf_fields ) ) {
                $context .= "Custom Fields:\n";
                foreach ( $acf_fields as $key => $value ) {
                    if ( is_string( $value ) || is_numeric( $value ) ) {
                        $context .= "- {$key}: {$value}\n";
                    }
                }
            }
        }

        return $context;
    }

    /**
     * Get field information
     *
     * @param string $field_name Field name or key
     * @param int    $post_id Post ID
     * @return array Field information
     */
    private function get_field_info( $field_name, $post_id ) {
        $field_info = array(
            'name' => $field_name,
            'label' => ucfirst( str_replace( array( '_', '-' ), ' ', $field_name ) ),
            'type' => 'text',
            'instructions' => '',
        );

        // Get ACF field object if available
        if ( function_exists( 'get_field_object' ) ) {
            $field_object = get_field_object( $field_name, $post_id );
            if ( $field_object ) {
                $field_info['name'] = $field_object['name'];
                $field_info['label'] = $field_object['label'];
                $field_info['type'] = $field_object['type'];
                $field_info['instructions'] = $field_object['instructions'] ?? '';
            }
        }

        return $field_info;
    }

    /**
     * Build prompt for field generation
     *
     * @param array  $field_info Field information
     * @param string $context Post context
     * @return string Prompt
     */
    private function build_field_prompt( $field_info, $context ) {
        $prompt = "Generate content for the following field:\n";
        $prompt .= "Field: {$field_info['label']}\n";
        $prompt .= "Type: {$field_info['type']}\n";

        if ( ! empty( $field_info['instructions'] ) ) {
            $prompt .= "Instructions: {$field_info['instructions']}\n";
        }

        $prompt .= "\n{$context}\n";

        // Add type-specific instructions
        switch ( $field_info['type'] ) {
            case 'textarea':
            case 'wysiwyg':
                $prompt .= "\nGenerate 2-3 paragraphs of well-written content that fits this context.";
                break;

            case 'text':
                $prompt .= "\nGenerate a concise, descriptive text (1-2 sentences).";
                break;

            case 'number':
                $prompt .= "\nGenerate an appropriate number value.";
                break;

            default:
                $prompt .= "\nGenerate appropriate content for this field type.";
        }

        $prompt .= "\n\nReturn only the generated content without any explanations or formatting.";

        return $prompt;
    }

    /**
     * Generate meta description for SEO
     *
     * @param int $post_id Post ID
     * @return string|WP_Error Meta description or error
     */
    public function generate_meta_description( $post_id ) {
        $post = get_post( $post_id );
        if ( ! $post ) {
            return new WP_Error( 'invalid_post', __( 'Invalid post ID.', 'ignis-ai' ) );
        }

        $content = wp_strip_all_tags( $post->post_content );

        $prompt = "Generate a compelling SEO meta description (maximum 155 characters) for this content:\n\n";
        $prompt .= "Title: {$post->post_title}\n";
        $prompt .= "Content: " . substr( $content, 0, 1000 ) . "\n\n";
        $prompt .= "The meta description should be engaging, include keywords, and encourage clicks. ";
        $prompt .= "Return only the meta description text, no quotes or extra formatting.";

        $description = $this->ai_client->generate_text( $prompt, array(
            'max_tokens' => 100,
            'temperature' => 0.7,
        ));

        if ( ! is_wp_error( $description ) ) {
            // Ensure it's within 155 characters
            $description = trim( $description );
            if ( strlen( $description ) > 155 ) {
                $description = substr( $description, 0, 152 ) . '...';
            }
        }

        return $description;
    }

    /**
     * Generate content title/headline
     *
     * @param string $topic Topic or brief description
     * @param string $post_type Post type (optional)
     * @return string|WP_Error Generated title or error
     */
    public function generate_title( $topic, $post_type = 'post' ) {
        $prompt = "Generate a compelling, SEO-friendly title for a {$post_type} about: {$topic}\n\n";
        $prompt .= "The title should be:\n";
        $prompt .= "- Engaging and clickable\n";
        $prompt .= "- 50-60 characters long\n";
        $prompt .= "- Include relevant keywords\n";
        $prompt .= "- Clear and descriptive\n\n";
        $prompt .= "Return only the title text, no quotes or formatting.";

        return $this->ai_client->generate_text( $prompt, array(
            'max_tokens' => 50,
            'temperature' => 0.8,
        ));
    }
}
