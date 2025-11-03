<?php
/**
 * SEO Optimizer Class
 *
 * AI-powered SEO analysis and optimization
 *
 * @package IgnisAI
 */

// Exit if accessed directly
if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

/**
 * SEO Optimizer class
 */
class IgnisAI_SEO_Optimizer {

    /**
     * AI Client instance
     *
     * @var IgnisAI_Client
     */
    private $ai_client;

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
        $this->ai_client = new IgnisAI_Client();
        $this->content_generator = new IgnisAI_Content_Generator();

        // Add SEO meta box to post editor
        add_action( 'add_meta_boxes', array( $this, 'add_seo_meta_box' ) );

        // Save SEO data
        add_action( 'save_post', array( $this, 'save_seo_data' ), 10, 2 );

        // AJAX handlers
        add_action( 'wp_ajax_ignis_ai_analyze_seo', array( $this, 'ajax_analyze_seo' ) );
        add_action( 'wp_ajax_ignis_ai_generate_meta', array( $this, 'ajax_generate_meta' ) );
    }

    /**
     * Add SEO meta box to post editor
     */
    public function add_seo_meta_box() {
        $post_types = get_post_types( array( 'public' => true ), 'names' );

        foreach ( $post_types as $post_type ) {
            add_meta_box(
                'ignis_ai_seo',
                __( 'IgnisAI SEO Optimizer', 'ignis-ai' ),
                array( $this, 'render_seo_meta_box' ),
                $post_type,
                'side',
                'default'
            );
        }
    }

    /**
     * Render SEO meta box
     *
     * @param WP_Post $post Post object
     */
    public function render_seo_meta_box( $post ) {
        wp_nonce_field( 'ignis_ai_seo_meta_box', 'ignis_ai_seo_nonce' );

        // Get saved SEO data
        $meta_description = get_post_meta( $post->ID, '_ignis_ai_meta_description', true );
        $keywords = get_post_meta( $post->ID, '_ignis_ai_keywords', true );
        $seo_score = get_post_meta( $post->ID, '_ignis_ai_seo_score', true );

        ?>
        <div class="ignis-ai-seo-wrapper">
            <div class="ignis-ai-seo-actions">
                <button type="button" class="button button-primary ignis-ai-analyze-seo" data-post-id="<?php echo esc_attr( $post->ID ); ?>">
                    <span class="dashicons dashicons-chart-line"></span>
                    <?php _e( 'Analyze SEO', 'ignis-ai' ); ?>
                </button>
                <button type="button" class="button button-secondary ignis-ai-generate-meta" data-post-id="<?php echo esc_attr( $post->ID ); ?>">
                    <span class="dashicons dashicons-admin-generic"></span>
                    <?php _e( 'Generate Meta', 'ignis-ai' ); ?>
                </button>
            </div>

            <?php if ( $seo_score ) : ?>
            <div class="ignis-ai-seo-score">
                <strong><?php _e( 'SEO Score:', 'ignis-ai' ); ?></strong>
                <span class="score"><?php echo esc_html( $seo_score ); ?>/100</span>
            </div>
            <?php endif; ?>

            <div class="ignis-ai-seo-field">
                <label for="ignis-ai-meta-description">
                    <strong><?php _e( 'Meta Description:', 'ignis-ai' ); ?></strong>
                    <span class="char-count"><?php echo strlen( $meta_description ); ?>/155</span>
                </label>
                <textarea
                    id="ignis-ai-meta-description"
                    name="ignis_ai_meta_description"
                    rows="3"
                    maxlength="155"
                    class="widefat"><?php echo esc_textarea( $meta_description ); ?></textarea>
            </div>

            <div class="ignis-ai-seo-field">
                <label for="ignis-ai-keywords">
                    <strong><?php _e( 'Keywords (comma-separated):', 'ignis-ai' ); ?></strong>
                </label>
                <input
                    type="text"
                    id="ignis-ai-keywords"
                    name="ignis_ai_keywords"
                    value="<?php echo esc_attr( $keywords ); ?>"
                    class="widefat" />
            </div>

            <div id="ignis-ai-seo-suggestions"></div>

            <style>
                .ignis-ai-seo-wrapper { margin-top: 10px; }
                .ignis-ai-seo-actions { margin-bottom: 15px; }
                .ignis-ai-seo-actions .button { width: 100%; margin-bottom: 5px; }
                .ignis-ai-seo-score { padding: 10px; background: #f0f0f1; border-radius: 4px; margin-bottom: 15px; }
                .ignis-ai-seo-score .score { float: right; font-weight: bold; color: #2271b1; }
                .ignis-ai-seo-field { margin-bottom: 15px; }
                .ignis-ai-seo-field label { display: block; margin-bottom: 5px; }
                .ignis-ai-seo-field .char-count { float: right; font-size: 11px; color: #666; }
                #ignis-ai-seo-suggestions { margin-top: 15px; }
                #ignis-ai-seo-suggestions h4 { margin: 10px 0 5px; }
                #ignis-ai-seo-suggestions ul { margin: 5px 0; padding-left: 20px; }
            </style>

            <script>
            jQuery(document).ready(function($) {
                // Character counter for meta description
                $('#ignis-ai-meta-description').on('input', function() {
                    var length = $(this).val().length;
                    $(this).siblings('label').find('.char-count').text(length + '/155');
                });

                // Analyze SEO
                $('.ignis-ai-analyze-seo').on('click', function() {
                    var $btn = $(this);
                    var postId = $btn.data('post-id');

                    $btn.prop('disabled', true).html('<span class="spinner is-active"></span> <?php _e( 'Analyzing...', 'ignis-ai' ); ?>');

                    $.ajax({
                        url: ajaxurl,
                        type: 'POST',
                        data: {
                            action: 'ignis_ai_analyze_seo',
                            post_id: postId,
                            nonce: '<?php echo wp_create_nonce( 'ignis_ai_seo' ); ?>'
                        },
                        success: function(response) {
                            if (response.success) {
                                $('#ignis-ai-seo-suggestions').html(response.data.suggestions_html);
                                if (response.data.score) {
                                    $('.ignis-ai-seo-score .score').text(response.data.score + '/100');
                                }
                            } else {
                                alert(response.data.message || '<?php _e( 'Error analyzing SEO.', 'ignis-ai' ); ?>');
                            }
                        },
                        complete: function() {
                            $btn.prop('disabled', false).html('<span class="dashicons dashicons-chart-line"></span> <?php _e( 'Analyze SEO', 'ignis-ai' ); ?>');
                        }
                    });
                });

                // Generate meta description
                $('.ignis-ai-generate-meta').on('click', function() {
                    var $btn = $(this);
                    var postId = $btn.data('post-id');

                    $btn.prop('disabled', true).html('<span class="spinner is-active"></span> <?php _e( 'Generating...', 'ignis-ai' ); ?>');

                    $.ajax({
                        url: ajaxurl,
                        type: 'POST',
                        data: {
                            action: 'ignis_ai_generate_meta',
                            post_id: postId,
                            nonce: '<?php echo wp_create_nonce( 'ignis_ai_seo' ); ?>'
                        },
                        success: function(response) {
                            if (response.success) {
                                $('#ignis-ai-meta-description').val(response.data.meta_description);
                                $('#ignis-ai-keywords').val(response.data.keywords);
                                // Trigger char count update
                                $('#ignis-ai-meta-description').trigger('input');
                            } else {
                                alert(response.data.message || '<?php _e( 'Error generating meta data.', 'ignis-ai' ); ?>');
                            }
                        },
                        complete: function() {
                            $btn.prop('disabled', false).html('<span class="dashicons dashicons-admin-generic"></span> <?php _e( 'Generate Meta', 'ignis-ai' ); ?>');
                        }
                    });
                });
            });
            </script>
        </div>
        <?php
    }

    /**
     * Save SEO data
     *
     * @param int     $post_id Post ID
     * @param WP_Post $post Post object
     */
    public function save_seo_data( $post_id, $post ) {
        // Verify nonce
        if ( ! isset( $_POST['ignis_ai_seo_nonce'] ) || ! wp_verify_nonce( $_POST['ignis_ai_seo_nonce'], 'ignis_ai_seo_meta_box' ) ) {
            return;
        }

        // Check autosave
        if ( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) {
            return;
        }

        // Check permissions
        if ( ! current_user_can( 'edit_post', $post_id ) ) {
            return;
        }

        // Save meta description
        if ( isset( $_POST['ignis_ai_meta_description'] ) ) {
            update_post_meta( $post_id, '_ignis_ai_meta_description', sanitize_textarea_field( $_POST['ignis_ai_meta_description'] ) );
        }

        // Save keywords
        if ( isset( $_POST['ignis_ai_keywords'] ) ) {
            update_post_meta( $post_id, '_ignis_ai_keywords', sanitize_text_field( $_POST['ignis_ai_keywords'] ) );
        }
    }

    /**
     * AJAX handler for SEO analysis
     */
    public function ajax_analyze_seo() {
        check_ajax_referer( 'ignis_ai_seo', 'nonce' );

        if ( ! current_user_can( 'edit_posts' ) ) {
            wp_send_json_error( array( 'message' => __( 'Permission denied.', 'ignis-ai' ) ) );
        }

        $post_id = isset( $_POST['post_id'] ) ? (int) $_POST['post_id'] : 0;
        $post = get_post( $post_id );

        if ( ! $post ) {
            wp_send_json_error( array( 'message' => __( 'Invalid post.', 'ignis-ai' ) ) );
        }

        // Analyze SEO
        $analysis = $this->analyze_content_seo( $post );

        if ( is_wp_error( $analysis ) ) {
            wp_send_json_error( array( 'message' => $analysis->get_error_message() ) );
        }

        // Save score
        update_post_meta( $post_id, '_ignis_ai_seo_score', $analysis['score'] );

        // Build suggestions HTML
        $html = '<h4>' . __( 'SEO Suggestions:', 'ignis-ai' ) . '</h4>';
        $html .= '<ul>';
        foreach ( $analysis['suggestions'] as $suggestion ) {
            $html .= '<li>' . esc_html( $suggestion ) . '</li>';
        }
        $html .= '</ul>';

        wp_send_json_success( array(
            'score' => $analysis['score'],
            'suggestions_html' => $html,
        ));
    }

    /**
     * AJAX handler for generating meta data
     */
    public function ajax_generate_meta() {
        check_ajax_referer( 'ignis_ai_seo', 'nonce' );

        if ( ! current_user_can( 'edit_posts' ) ) {
            wp_send_json_error( array( 'message' => __( 'Permission denied.', 'ignis-ai' ) ) );
        }

        $post_id = isset( $_POST['post_id'] ) ? (int) $_POST['post_id'] : 0;

        // Generate meta description
        $meta_description = $this->content_generator->generate_meta_description( $post_id );

        if ( is_wp_error( $meta_description ) ) {
            wp_send_json_error( array( 'message' => $meta_description->get_error_message() ) );
        }

        // Generate keywords
        $keywords = $this->generate_keywords( $post_id );

        wp_send_json_success( array(
            'meta_description' => $meta_description,
            'keywords' => is_wp_error( $keywords ) ? '' : $keywords,
        ));
    }

    /**
     * Analyze content for SEO
     *
     * @param WP_Post $post Post object
     * @return array|WP_Error Analysis results or error
     */
    private function analyze_content_seo( $post ) {
        $content = wp_strip_all_tags( $post->post_content );

        $prompt = "Analyze this content for SEO and provide:\n";
        $prompt .= "1. An SEO score from 0-100\n";
        $prompt .= "2. 3-5 specific, actionable improvement suggestions\n\n";
        $prompt .= "Title: {$post->post_title}\n";
        $prompt .= "Content: " . substr( $content, 0, 1500 ) . "\n\n";
        $prompt .= "Return as JSON: {\"score\": 85, \"suggestions\": [\"suggestion 1\", \"suggestion 2\", ...]}";

        $response = $this->ai_client->generate_text( $prompt );

        if ( is_wp_error( $response ) ) {
            return $response;
        }

        // Parse JSON response
        $data = json_decode( $response, true );
        if ( ! $data || ! isset( $data['score'] ) || ! isset( $data['suggestions'] ) ) {
            return new WP_Error( 'invalid_response', __( 'Invalid AI response format.', 'ignis-ai' ) );
        }

        return $data;
    }

    /**
     * Generate keywords for content
     *
     * @param int $post_id Post ID
     * @return string|WP_Error Keywords or error
     */
    private function generate_keywords( $post_id ) {
        $post = get_post( $post_id );
        $content = wp_strip_all_tags( $post->post_content );

        $prompt = "Extract 5-7 relevant SEO keywords from this content:\n\n";
        $prompt .= "Title: {$post->post_title}\n";
        $prompt .= "Content: " . substr( $content, 0, 1000 ) . "\n\n";
        $prompt .= "Return only the keywords, comma-separated, no formatting.";

        return $this->ai_client->generate_text( $prompt, array( 'max_tokens' => 100 ) );
    }
}
