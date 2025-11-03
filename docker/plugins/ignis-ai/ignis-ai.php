<?php
/**
 * Plugin Name: IgnisAI - AI-Powered Content Assistant
 * Plugin URI: https://github.com/misterlex223/ignistack-sandbox
 * Description: AI-powered content generation, SEO optimization, and automatic alt text generation for WordPress with ACF integration. Uses OpenAI compatible API.
 * Version: 1.0.0
 * Requires at least: 6.0
 * Requires PHP: 8.1
 * Author: IgniStack Team
 * Author URI: https://github.com/misterlex223
 * License: GPL v2 or later
 * License URI: https://www.gnu.org/licenses/gpl-2.0.html
 * Text Domain: ignis-ai
 * Domain Path: /languages
 *
 * @package IgnisAI
 */

// Exit if accessed directly
if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

// Define plugin constants
define( 'IGNIS_AI_VERSION', '1.0.0' );
define( 'IGNIS_AI_PLUGIN_DIR', plugin_dir_path( __FILE__ ) );
define( 'IGNIS_AI_PLUGIN_URL', plugin_dir_url( __FILE__ ) );
define( 'IGNIS_AI_PLUGIN_BASENAME', plugin_basename( __FILE__ ) );

/**
 * Main IgnisAI Plugin Class
 */
class IgnisAI {

    /**
     * Single instance of the class
     *
     * @var IgnisAI
     */
    private static $instance = null;

    /**
     * OpenAI Client instance
     *
     * @var object
     */
    public $ai_client = null;

    /**
     * Get single instance of the class
     *
     * @return IgnisAI
     */
    public static function get_instance() {
        if ( null === self::$instance ) {
            self::$instance = new self();
        }
        return self::$instance;
    }

    /**
     * Constructor
     */
    private function __construct() {
        // Load Composer autoloader
        $this->load_autoloader();

        // Initialize plugin
        add_action( 'plugins_loaded', array( $this, 'init' ) );

        // Activation/Deactivation hooks
        register_activation_hook( __FILE__, array( $this, 'activate' ) );
        register_deactivation_hook( __FILE__, array( $this, 'deactivate' ) );
    }

    /**
     * Load Composer autoloader
     */
    private function load_autoloader() {
        $autoload_file = IGNIS_AI_PLUGIN_DIR . 'vendor/autoload.php';

        if ( file_exists( $autoload_file ) ) {
            require_once $autoload_file;
        } else {
            add_action( 'admin_notices', function() {
                ?>
                <div class="notice notice-error">
                    <p>
                        <strong>IgnisAI Error:</strong>
                        Composer dependencies not found. Please run <code>composer install</code> in the plugin directory.
                    </p>
                </div>
                <?php
            });
        }
    }

    /**
     * Initialize plugin
     */
    public function init() {
        // Load text domain for translations
        load_plugin_textdomain( 'ignis-ai', false, dirname( IGNIS_AI_PLUGIN_BASENAME ) . '/languages' );

        // Initialize AI client
        $this->init_ai_client();

        // Load plugin classes
        $this->load_classes();

        // Initialize features
        $this->init_features();
    }

    /**
     * Initialize OpenAI client with Claude API compatibility
     */
    private function init_ai_client() {
        // Check if OpenAI client class exists
        if ( ! class_exists( 'OpenAI' ) ) {
            return;
        }

        // Get API key from environment or settings
        $api_key = $this->get_api_key();

        if ( empty( $api_key ) ) {
            add_action( 'admin_notices', function() {
                ?>
                <div class="notice notice-warning">
                    <p>
                        <strong>IgnisAI Warning:</strong>
                        No API key configured. Please set OPENAI_API_KEY environment variable or configure in plugin settings.
                    </p>
                </div>
                <?php
            });
            return;
        }

        try {
            // Initialize OpenAI client with Anthropic base URL for Claude compatibility
            $this->ai_client = \OpenAI::factory()
                ->withApiKey( $api_key )
                ->withBaseUri( 'https://api.anthropic.com/v1' )
                ->withHttpHeader( 'anthropic-version', '2023-06-01' )
                ->make();

        } catch ( Exception $e ) {
            error_log( 'IgnisAI: Failed to initialize AI client - ' . $e->getMessage() );
        }
    }

    /**
     * Get API key from environment or settings
     *
     * @return string
     */
    private function get_api_key() {
        // First check environment variable (OpenAI API key for OpenAI compatibility)
        $api_key = getenv( 'OPENAI_API_KEY' );

        // If not in environment, check WordPress options
        if ( empty( $api_key ) ) {
            $api_key = get_option( 'ignis_ai_api_key', '' );
        }

        return $api_key;
    }

    /**
     * Load plugin classes
     */
    private function load_classes() {
        // Core classes
        require_once IGNIS_AI_PLUGIN_DIR . 'includes/class-ai-client.php';
        require_once IGNIS_AI_PLUGIN_DIR . 'includes/class-content-generator.php';
        require_once IGNIS_AI_PLUGIN_DIR . 'includes/class-image-analyzer.php';
        require_once IGNIS_AI_PLUGIN_DIR . 'includes/class-seo-optimizer.php';
        require_once IGNIS_AI_PLUGIN_DIR . 'includes/class-acf-integration.php';
        require_once IGNIS_AI_PLUGIN_DIR . 'includes/class-form-generator.php';

        // Admin classes
        if ( is_admin() ) {
            require_once IGNIS_AI_PLUGIN_DIR . 'admin/class-admin-settings.php';
            require_once IGNIS_AI_PLUGIN_DIR . 'admin/class-admin-ui.php';
        }

        // WP-CLI commands
        if ( defined( 'WP_CLI' ) && WP_CLI ) {
            require_once IGNIS_AI_PLUGIN_DIR . 'includes/class-cli-commands.php';
        }
    }

    /**
     * Initialize plugin features
     */
    private function init_features() {
        // Initialize features only if AI client is available
        if ( null === $this->ai_client ) {
            return;
        }

        // Initialize image analyzer (automatic alt text)
        if ( class_exists( 'IgnisAI_Image_Analyzer' ) ) {
            new IgnisAI_Image_Analyzer();
        }

        // Initialize ACF integration
        if ( class_exists( 'IgnisAI_ACF_Integration' ) ) {
            new IgnisAI_ACF_Integration();
        }

        // Initialize SEO optimizer
        if ( class_exists( 'IgnisAI_SEO_Optimizer' ) ) {
            new IgnisAI_SEO_Optimizer();
        }

        // Initialize admin UI
        if ( is_admin() && class_exists( 'IgnisAI_Admin_Settings' ) ) {
            new IgnisAI_Admin_Settings();
            new IgnisAI_Admin_UI();
        }
    }

    /**
     * Plugin activation
     */
    public function activate() {
        // Set default options
        add_option( 'ignis_ai_version', IGNIS_AI_VERSION );
        add_option( 'ignis_ai_enabled', true );
        add_option( 'ignis_ai_auto_alt_text', true );
        add_option( 'ignis_ai_model', 'claude-sonnet-4-5-20250929' );
        add_option( 'ignis_ai_max_tokens', 4096 );
        add_option( 'ignis_ai_temperature', 0.7 );

        // Flush rewrite rules
        flush_rewrite_rules();
    }

    /**
     * Plugin deactivation
     */
    public function deactivate() {
        // Flush rewrite rules
        flush_rewrite_rules();
    }

    /**
     * Get AI client instance
     *
     * @return object|null
     */
    public function get_ai_client() {
        return $this->ai_client;
    }
}

/**
 * Get main plugin instance
 *
 * @return IgnisAI
 */
function ignis_ai() {
    return IgnisAI::get_instance();
}

// Initialize plugin
ignis_ai();
