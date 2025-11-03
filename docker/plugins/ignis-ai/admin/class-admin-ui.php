<?php
/**
 * Admin UI Class
 *
 * @package IgnisAI
 */

// Exit if accessed directly
if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

/**
 * Admin UI class
 */
class IgnisAI_Admin_UI {

    /**
     * Form Generator instance
     *
     * @var IgnisAI_Form_Generator
     */
    private $form_generator;

    /**
     * Constructor
     */
    public function __construct() {
        $this->form_generator = new IgnisAI_Form_Generator();

        // Add admin menu page for form generator
        add_action( 'admin_menu', array( $this, 'add_form_generator_page' ) );

        // AJAX handlers
        add_action( 'wp_ajax_ignis_ai_generate_form', array( $this, 'ajax_generate_form' ) );
        add_action( 'wp_ajax_ignis_ai_import_form', array( $this, 'ajax_import_form' ) );

        // Enqueue admin scripts
        add_action( 'admin_enqueue_scripts', array( $this, 'enqueue_admin_scripts' ) );
    }

    /**
     * Add form generator page to admin menu
     */
    public function add_form_generator_page() {
        add_submenu_page(
            'edit.php?post_type=acf-field-group',
            __( 'AI Form Generator', 'ignis-ai' ),
            __( 'AI Generator', 'ignis-ai' ),
            'manage_options',
            'ignis-ai-form-generator',
            array( $this, 'render_form_generator_page' )
        );
    }

    /**
     * Enqueue admin scripts and styles
     *
     * @param string $hook Current admin page hook
     */
    public function enqueue_admin_scripts( $hook ) {
        // Only load on our admin pages
        $our_pages = array(
            'acf-field-group_page_ignis-ai-form-generator',
            'settings_page_ignis-ai-settings',
        );

        if ( ! in_array( $hook, $our_pages, true ) ) {
            return;
        }

        wp_enqueue_style(
            'ignis-ai-admin',
            IGNIS_AI_PLUGIN_URL . 'assets/css/admin.css',
            array(),
            IGNIS_AI_VERSION
        );

        wp_enqueue_script(
            'ignis-ai-admin',
            IGNIS_AI_PLUGIN_URL . 'assets/js/admin.js',
            array( 'jquery' ),
            IGNIS_AI_VERSION,
            true
        );

        wp_localize_script(
            'ignis-ai-admin',
            'ignisAIAdmin',
            array(
                'ajaxUrl' => admin_url( 'admin-ajax.php' ),
                'nonce' => wp_create_nonce( 'ignis_ai_admin' ),
            )
        );
    }

    /**
     * Render form generator page
     */
    public function render_form_generator_page() {
        if ( ! current_user_can( 'manage_options' ) ) {
            return;
        }

        ?>
        <div class="wrap ignis-ai-form-generator">
            <h1><?php _e( 'AI Form Generator', 'ignis-ai' ); ?></h1>
            <p class="description">
                <?php _e( 'Describe the fields you need, and AI will generate an ACF field group for you.', 'ignis-ai' ); ?>
            </p>

            <div class="ignis-ai-generator-container">
                <div class="ignis-ai-input-section">
                    <h2><?php _e( 'Describe Your Fields', 'ignis-ai' ); ?></h2>

                    <form id="ignis-ai-form-generator-form">
                        <table class="form-table">
                            <tr>
                                <th scope="row">
                                    <label for="field-description">
                                        <?php _e( 'Description', 'ignis-ai' ); ?>
                                        <span class="required">*</span>
                                    </label>
                                </th>
                                <td>
                                    <textarea
                                        id="field-description"
                                        name="description"
                                        rows="5"
                                        class="large-text"
                                        required
                                        placeholder="<?php esc_attr_e( 'Example: Product fields including name, price in USD, SKU number, detailed description, and a featured image', 'ignis-ai' ); ?>"></textarea>
                                    <p class="description">
                                        <?php _e( 'Describe the fields you need in natural language. Be specific about field types, requirements, and purpose.', 'ignis-ai' ); ?>
                                    </p>
                                </td>
                            </tr>
                            <tr>
                                <th scope="row">
                                    <label for="field-group-title">
                                        <?php _e( 'Field Group Title', 'ignis-ai' ); ?>
                                        <span class="required">*</span>
                                    </label>
                                </th>
                                <td>
                                    <input
                                        type="text"
                                        id="field-group-title"
                                        name="title"
                                        class="regular-text"
                                        required
                                        placeholder="<?php esc_attr_e( 'Product Information', 'ignis-ai' ); ?>">
                                </td>
                            </tr>
                            <tr>
                                <th scope="row">
                                    <label for="post-type">
                                        <?php _e( 'Post Type', 'ignis-ai' ); ?>
                                        <span class="required">*</span>
                                    </label>
                                </th>
                                <td>
                                    <select id="post-type" name="post_type" class="regular-text">
                                        <?php
                                        $post_types = get_post_types( array( 'public' => true ), 'objects' );
                                        foreach ( $post_types as $post_type ) {
                                            printf(
                                                '<option value="%s">%s</option>',
                                                esc_attr( $post_type->name ),
                                                esc_html( $post_type->label )
                                            );
                                        }
                                        ?>
                                    </select>
                                    <p class="description">
                                        <?php _e( 'The post type to attach these fields to.', 'ignis-ai' ); ?>
                                    </p>
                                </td>
                            </tr>
                        </table>

                        <p class="submit">
                            <button type="submit" class="button button-primary button-hero">
                                <span class="dashicons dashicons-admin-generic"></span>
                                <?php _e( 'Generate Field Group', 'ignis-ai' ); ?>
                            </button>
                        </p>
                    </form>
                </div>

                <div class="ignis-ai-preview-section" style="display: none;">
                    <h2><?php _e( 'Preview & Import', 'ignis-ai' ); ?></h2>

                    <div id="field-group-preview"></div>

                    <p class="submit">
                        <button type="button" id="import-field-group" class="button button-primary button-hero">
                            <span class="dashicons dashicons-download"></span>
                            <?php _e( 'Import into ACF', 'ignis-ai' ); ?>
                        </button>
                        <button type="button" id="regenerate-fields" class="button button-secondary">
                            <span class="dashicons dashicons-update"></span>
                            <?php _e( 'Regenerate', 'ignis-ai' ); ?>
                        </button>
                    </p>
                </div>

                <div class="ignis-ai-loading" style="display: none;">
                    <div class="spinner is-active"></div>
                    <p><?php _e( 'Generating field group... This may take a moment.', 'ignis-ai' ); ?></p>
                </div>
            </div>
        </div>
        <?php
    }

    /**
     * AJAX handler for generating form
     */
    public function ajax_generate_form() {
        check_ajax_referer( 'ignis_ai_admin', 'nonce' );

        if ( ! current_user_can( 'manage_options' ) ) {
            wp_send_json_error( array( 'message' => __( 'Permission denied.', 'ignis-ai' ) ) );
        }

        $description = isset( $_POST['description'] ) ? sanitize_textarea_field( $_POST['description'] ) : '';
        $title = isset( $_POST['title'] ) ? sanitize_text_field( $_POST['title'] ) : '';
        $post_type = isset( $_POST['post_type'] ) ? sanitize_text_field( $_POST['post_type'] ) : 'post';

        if ( empty( $description ) || empty( $title ) ) {
            wp_send_json_error( array( 'message' => __( 'Description and title are required.', 'ignis-ai' ) ) );
        }

        // Generate field group
        $field_group = $this->form_generator->generate_field_group( $description, $post_type, $title );

        if ( is_wp_error( $field_group ) ) {
            wp_send_json_error( array( 'message' => $field_group->get_error_message() ) );
        }

        wp_send_json_success( array(
            'field_group' => $field_group,
            'preview_html' => $this->build_preview_html( $field_group ),
        ));
    }

    /**
     * AJAX handler for importing form
     */
    public function ajax_import_form() {
        check_ajax_referer( 'ignis_ai_admin', 'nonce' );

        if ( ! current_user_can( 'manage_options' ) ) {
            wp_send_json_error( array( 'message' => __( 'Permission denied.', 'ignis-ai' ) ) );
        }

        $field_group = isset( $_POST['field_group'] ) ? json_decode( stripslashes( $_POST['field_group'] ), true ) : array();

        if ( empty( $field_group ) ) {
            wp_send_json_error( array( 'message' => __( 'Invalid field group data.', 'ignis-ai' ) ) );
        }

        // Import field group
        $result = $this->form_generator->import_field_group( $field_group );

        if ( is_wp_error( $result ) ) {
            wp_send_json_error( array( 'message' => $result->get_error_message() ) );
        }

        $edit_url = admin_url( 'post.php?post=' . $result . '&action=edit' );

        wp_send_json_success( array(
            'message' => sprintf(
                /* translators: %s: Edit URL */
                __( 'Field group imported successfully! <a href="%s">Edit field group</a>', 'ignis-ai' ),
                esc_url( $edit_url )
            ),
            'edit_url' => $edit_url,
        ));
    }

    /**
     * Build preview HTML for field group
     *
     * @param array $field_group Field group array
     * @return string HTML
     */
    private function build_preview_html( $field_group ) {
        ob_start();
        ?>
        <div class="ignis-ai-field-group-preview">
            <h3><?php echo esc_html( $field_group['title'] ); ?></h3>
            <table class="wp-list-table widefat striped">
                <thead>
                    <tr>
                        <th><?php _e( 'Field Label', 'ignis-ai' ); ?></th>
                        <th><?php _e( 'Field Name', 'ignis-ai' ); ?></th>
                        <th><?php _e( 'Type', 'ignis-ai' ); ?></th>
                        <th><?php _e( 'Required', 'ignis-ai' ); ?></th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ( $field_group['fields'] as $field ) : ?>
                    <tr>
                        <td>
                            <strong><?php echo esc_html( $field['label'] ); ?></strong>
                            <?php if ( ! empty( $field['instructions'] ) ) : ?>
                                <br><small class="description"><?php echo esc_html( $field['instructions'] ); ?></small>
                            <?php endif; ?>
                        </td>
                        <td><code><?php echo esc_html( $field['name'] ); ?></code></td>
                        <td><span class="badge"><?php echo esc_html( $field['type'] ); ?></span></td>
                        <td><?php echo ! empty( $field['required'] ) ? '✓' : '—'; ?></td>
                    </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
        <?php
        return ob_get_clean();
    }
}
