<?php
/**
 * ACF Integration Class
 *
 * Integrates AI content generation with Advanced Custom Fields
 *
 * @package IgnisAI
 */

// Exit if accessed directly
if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

/**
 * ACF Integration class
 */
class IgnisAI_ACF_Integration {

    /**
     * Content Generator instance
     *
     * @var IgnisAI_Content_Generator
     */
    private $content_generator;

    /**
     * Constructor
     */
    public function __construct() {
        // Only initialize if ACF is active
        if ( ! function_exists( 'acf' ) ) {
            return;
        }

        $this->content_generator = new IgnisAI_Content_Generator();

        // Add AI button to ACF fields
        add_action( 'acf/render_field', array( $this, 'add_ai_button_to_field' ), 10, 1 );

        // Enqueue scripts and styles
        add_action( 'acf/input/admin_enqueue_scripts', array( $this, 'enqueue_acf_scripts' ) );

        // AJAX handlers
        add_action( 'wp_ajax_ignis_ai_generate_acf_field', array( $this, 'ajax_generate_acf_field' ) );
    }

    /**
     * Add AI generation button to ACF fields
     *
     * @param array $field Field array
     */
    public function add_ai_button_to_field( $field ) {
        // Only add button to text-based fields
        $supported_types = array( 'text', 'textarea', 'wysiwyg', 'number', 'email', 'url' );

        if ( ! in_array( $field['type'], $supported_types, true ) ) {
            return;
        }

        // Get current post ID
        $post_id = 0;
        if ( isset( $_GET['post'] ) ) {
            $post_id = (int) $_GET['post'];
        } elseif ( isset( $_POST['post_ID'] ) ) {
            $post_id = (int) $_POST['post_ID'];
        }

        if ( $post_id === 0 ) {
            return; // Don't show button when creating new post
        }

        ?>
        <div class="ignis-ai-field-wrapper">
            <button type="button"
                    class="button button-secondary ignis-ai-generate-btn"
                    data-field-key="<?php echo esc_attr( $field['key'] ); ?>"
                    data-field-name="<?php echo esc_attr( $field['name'] ); ?>"
                    data-field-type="<?php echo esc_attr( $field['type'] ); ?>"
                    data-post-id="<?php echo esc_attr( $post_id ); ?>">
                <span class="dashicons dashicons-admin-generic"></span>
                <?php _e( 'Generate with AI', 'ignis-ai' ); ?>
            </button>
            <span class="ignis-ai-loading" style="display:none;">
                <span class="spinner is-active"></span>
                <?php _e( 'Generating...', 'ignis-ai' ); ?>
            </span>
        </div>
        <?php
    }

    /**
     * Enqueue scripts and styles for ACF integration
     */
    public function enqueue_acf_scripts() {
        // Enqueue CSS
        wp_enqueue_style(
            'ignis-ai-acf',
            IGNIS_AI_PLUGIN_URL . 'assets/css/acf-integration.css',
            array(),
            IGNIS_AI_VERSION
        );

        // Enqueue JavaScript
        wp_enqueue_script(
            'ignis-ai-acf',
            IGNIS_AI_PLUGIN_URL . 'assets/js/acf-integration.js',
            array( 'jquery', 'acf-input' ),
            IGNIS_AI_VERSION,
            true
        );

        // Localize script
        wp_localize_script(
            'ignis-ai-acf',
            'ignisAI',
            array(
                'ajaxUrl' => admin_url( 'admin-ajax.php' ),
                'nonce' => wp_create_nonce( 'ignis_ai_generate' ),
                'strings' => array(
                    'generating' => __( 'Generating...', 'ignis-ai' ),
                    'generate' => __( 'Generate with AI', 'ignis-ai' ),
                    'error' => __( 'Error generating content. Please try again.', 'ignis-ai' ),
                    'success' => __( 'Content generated successfully!', 'ignis-ai' ),
                ),
            )
        );
    }

    /**
     * AJAX handler for generating ACF field content
     */
    public function ajax_generate_acf_field() {
        // Verify nonce
        check_ajax_referer( 'ignis_ai_generate', 'nonce' );

        // Check user permissions
        if ( ! current_user_can( 'edit_posts' ) ) {
            wp_send_json_error( array(
                'message' => __( 'You do not have permission to perform this action.', 'ignis-ai' ),
            ));
        }

        // Get parameters
        $post_id = isset( $_POST['post_id'] ) ? (int) $_POST['post_id'] : 0;
        $field_key = isset( $_POST['field_key'] ) ? sanitize_text_field( $_POST['field_key'] ) : '';
        $field_name = isset( $_POST['field_name'] ) ? sanitize_text_field( $_POST['field_name'] ) : '';
        $custom_prompt = isset( $_POST['custom_prompt'] ) ? sanitize_textarea_field( $_POST['custom_prompt'] ) : '';

        if ( $post_id === 0 || empty( $field_name ) ) {
            wp_send_json_error( array(
                'message' => __( 'Invalid parameters.', 'ignis-ai' ),
            ));
        }

        // Generate content
        $content = $this->content_generator->generate_field_content( $post_id, $field_name, $custom_prompt );

        if ( is_wp_error( $content ) ) {
            wp_send_json_error( array(
                'message' => $content->get_error_message(),
            ));
        }

        // Return generated content
        wp_send_json_success( array(
            'content' => $content,
            'field_key' => $field_key,
            'field_name' => $field_name,
        ));
    }
}
