<?php
/**
 * Image Analyzer Class
 *
 * Automatically generates alt text for images using AI
 *
 * @package IgnisAI
 */

// Exit if accessed directly
if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

/**
 * Image Analyzer class
 */
class IgnisAI_Image_Analyzer {

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

        // Hook into media upload
        add_action( 'add_attachment', array( $this, 'generate_alt_text_on_upload' ), 10, 1 );

        // Hook into ACF image field updates
        add_filter( 'acf/update_value/type=image', array( $this, 'generate_alt_text_for_acf_image' ), 10, 3 );

        // Add bulk generate button to media library
        add_filter( 'bulk_actions-upload', array( $this, 'add_bulk_generate_action' ) );
        add_filter( 'handle_bulk_actions-upload', array( $this, 'handle_bulk_generate_action' ), 10, 3 );

        // Add admin notice for bulk generation
        add_action( 'admin_notices', array( $this, 'bulk_generate_admin_notice' ) );
    }

    /**
     * Generate alt text when image is uploaded
     *
     * @param int $attachment_id Attachment ID
     */
    public function generate_alt_text_on_upload( $attachment_id ) {
        // Check if auto alt text is enabled
        if ( ! get_option( 'ignis_ai_auto_alt_text', true ) ) {
            return;
        }

        // Only process images
        if ( ! wp_attachment_is_image( $attachment_id ) ) {
            return;
        }

        // Check if alt text already exists
        $existing_alt = get_post_meta( $attachment_id, '_wp_attachment_image_alt', true );
        if ( ! empty( $existing_alt ) ) {
            return; // Don't override existing alt text
        }

        // Generate alt text
        $this->generate_and_save_alt_text( $attachment_id );
    }

    /**
     * Generate alt text for ACF image field
     *
     * @param mixed $value The value to be saved
     * @param int   $post_id The post ID
     * @param array $field The field array
     * @return mixed
     */
    public function generate_alt_text_for_acf_image( $value, $post_id, $field ) {
        // Check if auto alt text is enabled
        if ( ! get_option( 'ignis_ai_auto_alt_text', true ) ) {
            return $value;
        }

        // $value is the attachment ID when using ACF image field
        if ( is_numeric( $value ) && $value > 0 ) {
            $attachment_id = (int) $value;

            // Only process images
            if ( ! wp_attachment_is_image( $attachment_id ) ) {
                return $value;
            }

            // Check if alt text already exists
            $existing_alt = get_post_meta( $attachment_id, '_wp_attachment_image_alt', true );
            if ( empty( $existing_alt ) ) {
                // Generate alt text in background to avoid slowing down the save
                wp_schedule_single_event( time(), 'ignis_ai_generate_alt_text', array( $attachment_id ) );
            }
        }

        return $value;
    }

    /**
     * Generate and save alt text for an image
     *
     * @param int $attachment_id Attachment ID
     * @return bool True on success, false on failure
     */
    public function generate_and_save_alt_text( $attachment_id ) {
        // Get image URL
        $image_url = wp_get_attachment_url( $attachment_id );
        if ( ! $image_url ) {
            error_log( "IgnisAI: Could not get URL for attachment {$attachment_id}" );
            return false;
        }

        // Get image filename for context
        $filename = basename( $image_url );
        $image_title = get_the_title( $attachment_id );

        // Build context-aware prompt
        $prompt = sprintf(
            __( 'Generate a concise, descriptive alt text for this image (maximum 125 characters). The image filename is "%s". Focus on the main subject and important visual details for accessibility. Return only the alt text without quotes or extra formatting.', 'ignis-ai' ),
            ! empty( $image_title ) ? $image_title : $filename
        );

        // Generate alt text using AI
        $alt_text = $this->ai_client->analyze_image( $image_url, $prompt );

        if ( is_wp_error( $alt_text ) ) {
            error_log( 'IgnisAI: Failed to generate alt text - ' . $alt_text->get_error_message() );
            return false;
        }

        // Clean up the alt text
        $alt_text = trim( $alt_text );
        $alt_text = str_replace( array( '"', "'", "\n", "\r" ), '', $alt_text );

        // Limit to 125 characters (recommended max for alt text)
        if ( strlen( $alt_text ) > 125 ) {
            $alt_text = substr( $alt_text, 0, 122 ) . '...';
        }

        // Save alt text
        update_post_meta( $attachment_id, '_wp_attachment_image_alt', $alt_text );

        // Also update the attachment description if empty
        $attachment = get_post( $attachment_id );
        if ( empty( $attachment->post_content ) ) {
            wp_update_post( array(
                'ID' => $attachment_id,
                'post_content' => $alt_text,
            ));
        }

        return true;
    }

    /**
     * Add bulk action to media library
     *
     * @param array $bulk_actions Existing bulk actions
     * @return array Modified bulk actions
     */
    public function add_bulk_generate_action( $bulk_actions ) {
        $bulk_actions['ignis_ai_generate_alt'] = __( 'Generate AI Alt Text', 'ignis-ai' );
        return $bulk_actions;
    }

    /**
     * Handle bulk generate action
     *
     * @param string $redirect_to Redirect URL
     * @param string $doaction Action name
     * @param array  $post_ids Post IDs
     * @return string Modified redirect URL
     */
    public function handle_bulk_generate_action( $redirect_to, $doaction, $post_ids ) {
        if ( 'ignis_ai_generate_alt' !== $doaction ) {
            return $redirect_to;
        }

        $generated = 0;
        $skipped = 0;

        foreach ( $post_ids as $post_id ) {
            // Only process images
            if ( ! wp_attachment_is_image( $post_id ) ) {
                $skipped++;
                continue;
            }

            // Generate alt text (will override existing)
            if ( $this->generate_and_save_alt_text( $post_id ) ) {
                $generated++;
            } else {
                $skipped++;
            }
        }

        // Add query args to show notice
        $redirect_to = add_query_arg( array(
            'ignis_ai_bulk_generated' => $generated,
            'ignis_ai_bulk_skipped' => $skipped,
        ), $redirect_to );

        return $redirect_to;
    }

    /**
     * Display admin notice after bulk generation
     */
    public function bulk_generate_admin_notice() {
        if ( ! isset( $_REQUEST['ignis_ai_bulk_generated'] ) ) {
            return;
        }

        $generated = (int) $_REQUEST['ignis_ai_bulk_generated'];
        $skipped = isset( $_REQUEST['ignis_ai_bulk_skipped'] ) ? (int) $_REQUEST['ignis_ai_bulk_skipped'] : 0;

        ?>
        <div class="notice notice-success is-dismissible">
            <p>
                <?php
                printf(
                    /* translators: 1: Number of images processed, 2: Number of images skipped */
                    __( 'IgnisAI: Generated alt text for %1$d image(s). %2$d skipped.', 'ignis-ai' ),
                    $generated,
                    $skipped
                );
                ?>
            </p>
        </div>
        <?php
    }
}

// Register scheduled event hook
add_action( 'ignis_ai_generate_alt_text', function( $attachment_id ) {
    $analyzer = new IgnisAI_Image_Analyzer();
    $analyzer->generate_and_save_alt_text( $attachment_id );
});
