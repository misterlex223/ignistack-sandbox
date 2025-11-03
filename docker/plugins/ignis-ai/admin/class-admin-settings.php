<?php
/**
 * Admin Settings Class
 *
 * @package IgnisAI
 */

// Exit if accessed directly
if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

/**
 * Admin Settings class
 */
class IgnisAI_Admin_Settings {

    /**
     * Constructor
     */
    public function __construct() {
        add_action( 'admin_menu', array( $this, 'add_settings_page' ) );
        add_action( 'admin_init', array( $this, 'register_settings' ) );
    }

    /**
     * Add settings page to admin menu
     */
    public function add_settings_page() {
        add_options_page(
            __( 'IgnisAI Settings', 'ignis-ai' ),
            __( 'IgnisAI', 'ignis-ai' ),
            'manage_options',
            'ignis-ai-settings',
            array( $this, 'render_settings_page' )
        );
    }

    /**
     * Register plugin settings
     */
    public function register_settings() {
        // General Settings
        register_setting( 'ignis_ai_settings', 'ignis_ai_api_key' );
        register_setting( 'ignis_ai_settings', 'ignis_ai_enabled' );
        register_setting( 'ignis_ai_settings', 'ignis_ai_auto_alt_text' );
        register_setting( 'ignis_ai_settings', 'ignis_ai_model' );
        register_setting( 'ignis_ai_settings', 'ignis_ai_max_tokens' );
        register_setting( 'ignis_ai_settings', 'ignis_ai_temperature' );

        // General section
        add_settings_section(
            'ignis_ai_general',
            __( 'General Settings', 'ignis-ai' ),
            array( $this, 'render_general_section' ),
            'ignis-ai-settings'
        );

        // API Key field
        add_settings_field(
            'ignis_ai_api_key',
            __( 'API Key', 'ignis-ai' ),
            array( $this, 'render_api_key_field' ),
            'ignis-ai-settings',
            'ignis_ai_general'
        );

        // Enable field
        add_settings_field(
            'ignis_ai_enabled',
            __( 'Enable AI Features', 'ignis-ai' ),
            array( $this, 'render_enabled_field' ),
            'ignis-ai-settings',
            'ignis_ai_general'
        );

        // Auto alt text field
        add_settings_field(
            'ignis_ai_auto_alt_text',
            __( 'Auto Generate Alt Text', 'ignis-ai' ),
            array( $this, 'render_auto_alt_text_field' ),
            'ignis-ai-settings',
            'ignis_ai_general'
        );

        // Model section
        add_settings_section(
            'ignis_ai_model',
            __( 'AI Model Settings', 'ignis-ai' ),
            array( $this, 'render_model_section' ),
            'ignis-ai-settings'
        );

        // Model field
        add_settings_field(
            'ignis_ai_model',
            __( 'Model', 'ignis-ai' ),
            array( $this, 'render_model_field' ),
            'ignis-ai-settings',
            'ignis_ai_model'
        );

        // Max tokens field
        add_settings_field(
            'ignis_ai_max_tokens',
            __( 'Max Tokens', 'ignis-ai' ),
            array( $this, 'render_max_tokens_field' ),
            'ignis-ai-settings',
            'ignis_ai_model'
        );

        // Temperature field
        add_settings_field(
            'ignis_ai_temperature',
            __( 'Temperature', 'ignis-ai' ),
            array( $this, 'render_temperature_field' ),
            'ignis-ai-settings',
            'ignis_ai_model'
        );
    }

    /**
     * Render settings page
     */
    public function render_settings_page() {
        if ( ! current_user_can( 'manage_options' ) ) {
            return;
        }

        ?>
        <div class="wrap">
            <h1><?php echo esc_html( get_admin_page_title() ); ?></h1>

            <?php settings_errors( 'ignis_ai_messages' ); ?>

            <form method="post" action="options.php">
                <?php
                settings_fields( 'ignis_ai_settings' );
                do_settings_sections( 'ignis-ai-settings' );
                submit_button( __( 'Save Settings', 'ignis-ai' ) );
                ?>
            </form>

            <hr>

            <h2><?php _e( 'System Status', 'ignis-ai' ); ?></h2>
            <?php $this->render_system_status(); ?>
        </div>
        <?php
    }

    /**
     * Render general section
     */
    public function render_general_section() {
        echo '<p>' . __( 'Configure general IgnisAI settings.', 'ignis-ai' ) . '</p>';
    }

    /**
     * Render model section
     */
    public function render_model_section() {
        echo '<p>' . __( 'Configure AI model parameters.', 'ignis-ai' ) . '</p>';
    }

    /**
     * Render API key field
     */
    public function render_api_key_field() {
        $value = get_option( 'ignis_ai_api_key', '' );
        $from_env = ! empty( getenv( 'OPENAI_API_KEY' ) );

        if ( $from_env ) {
            echo '<p><strong>' . __( 'API key loaded from OPENAI_API_KEY environment variable.', 'ignis-ai' ) . '</strong></p>';
        } else {
            ?>
            <input type="password"
                   name="ignis_ai_api_key"
                   id="ignis_ai_api_key"
                   value="<?php echo esc_attr( $value ); ?>"
                   class="regular-text"
                   placeholder="sk-xxxxx">
            <p class="description">
                <?php _e( 'Your OpenAI API key for OpenAI compatibility. Alternatively, set OPENAI_API_KEY environment variable.', 'ignis-ai' ); ?>
            </p>
            <?php
        }
    }

    /**
     * Render enabled field
     */
    public function render_enabled_field() {
        $value = get_option( 'ignis_ai_enabled', true );
        ?>
        <label>
            <input type="checkbox"
                   name="ignis_ai_enabled"
                   value="1"
                   <?php checked( $value, true ); ?>>
            <?php _e( 'Enable AI features throughout WordPress', 'ignis-ai' ); ?>
        </label>
        <?php
    }

    /**
     * Render auto alt text field
     */
    public function render_auto_alt_text_field() {
        $value = get_option( 'ignis_ai_auto_alt_text', true );
        ?>
        <label>
            <input type="checkbox"
                   name="ignis_ai_auto_alt_text"
                   value="1"
                   <?php checked( $value, true ); ?>>
            <?php _e( 'Automatically generate alt text when images are uploaded', 'ignis-ai' ); ?>
        </label>
        <?php
    }

    /**
     * Render model field
     */
    public function render_model_field() {
        $value = get_option( 'ignis_ai_model', 'claude-sonnet-4-5-20250929' );
        ?>
        <select name="ignis_ai_model" id="ignis_ai_model">
            <option value="gpt-5-mini-2025-08-07" <?php selected( $value, 'gpt-5-mini-2025-08-07' ); ?>>
                GPT-5 mini
            </option>
            <option value="gpt-5-nano-2025-08-07" <?php selected( $value, 'gpt-5-nano-2025-08-07' ); ?>>
                GPT-5 nano
            </option>
            <option value="gpt-5-2025-08-07" <?php selected( $value, 'gpt-5-2025-08-07' ); ?>>
                GPT-5
            </option>
        </select>
        <p class="description">
            <?php _e( 'The AI model to use for content generation.', 'ignis-ai' ); ?>
        </p>
        <?php
    }

    /**
     * Render max tokens field
     */
    public function render_max_tokens_field() {
        $value = get_option( 'ignis_ai_max_tokens', 4096 );
        ?>
        <input type="number"
               name="ignis_ai_max_tokens"
               id="ignis_ai_max_tokens"
               value="<?php echo esc_attr( $value ); ?>"
               min="100"
               max="8192"
               step="100"
               class="small-text">
        <p class="description">
            <?php _e( 'Maximum number of tokens to generate (100-8192).', 'ignis-ai' ); ?>
        </p>
        <?php
    }

    /**
     * Render temperature field
     */
    public function render_temperature_field() {
        $value = get_option( 'ignis_ai_temperature', 0.7 );
        ?>
        <input type="number"
               name="ignis_ai_temperature"
               id="ignis_ai_temperature"
               value="<?php echo esc_attr( $value ); ?>"
               min="0"
               max="1"
               step="0.1"
               class="small-text">
        <p class="description">
            <?php _e( 'Creativity level (0.0 = conservative, 1.0 = creative).', 'ignis-ai' ); ?>
        </p>
        <?php
    }

    /**
     * Render system status
     */
    private function render_system_status() {
        $status_items = array(
            array(
                'label' => __( 'Plugin Version', 'ignis-ai' ),
                'value' => IGNIS_AI_VERSION,
                'status' => 'ok',
            ),
            array(
                'label' => __( 'API Key', 'ignis-ai' ),
                'value' => ! empty( getenv( 'OPENAI_API_KEY' ) ) || ! empty( get_option( 'ignis_ai_api_key' ) )
                    ? __( 'Configured', 'ignis-ai' )
                    : __( 'Not configured', 'ignis-ai' ),
                'status' => ! empty( getenv( 'OPENAI_API_KEY' ) ) || ! empty( get_option( 'ignis_ai_api_key' ) )
                    ? 'ok'
                    : 'error',
            ),
            array(
                'label' => __( 'Composer Dependencies', 'ignis-ai' ),
                'value' => file_exists( IGNIS_AI_PLUGIN_DIR . 'vendor/autoload.php' )
                    ? __( 'Installed', 'ignis-ai' )
                    : __( 'Not installed', 'ignis-ai' ),
                'status' => file_exists( IGNIS_AI_PLUGIN_DIR . 'vendor/autoload.php' )
                    ? 'ok'
                    : 'error',
            ),
            array(
                'label' => __( 'ACF Plugin', 'ignis-ai' ),
                'value' => function_exists( 'acf' )
                    ? __( 'Active', 'ignis-ai' )
                    : __( 'Not active', 'ignis-ai' ),
                'status' => function_exists( 'acf' )
                    ? 'ok'
                    : 'warning',
            ),
        );

        echo '<table class="wp-list-table widefat striped">';
        echo '<thead><tr><th>' . __( 'Component', 'ignis-ai' ) . '</th><th>' . __( 'Status', 'ignis-ai' ) . '</th></tr></thead>';
        echo '<tbody>';

        foreach ( $status_items as $item ) {
            $icon = $item['status'] === 'ok' ? '✓' : ( $item['status'] === 'error' ? '✗' : '⚠' );
            $color = $item['status'] === 'ok' ? 'green' : ( $item['status'] === 'error' ? 'red' : 'orange' );

            echo '<tr>';
            echo '<td>' . esc_html( $item['label'] ) . '</td>';
            echo '<td><span style="color: ' . $color . '; font-weight: bold;">' . $icon . '</span> ' . esc_html( $item['value'] ) . '</td>';
            echo '</tr>';
        }

        echo '</tbody></table>';
    }
}
