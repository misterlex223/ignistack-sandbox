<?php
/**
 * WP-CLI Commands for IgnisAI
 *
 * @package IgnisAI
 */

// Exit if accessed directly
if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

/**
 * IgnisAI WP-CLI commands
 */
class IgnisAI_CLI_Commands extends WP_CLI_Command {

    /**
     * Image Analyzer instance
     *
     * @var IgnisAI_Image_Analyzer
     */
    private $image_analyzer;

    /**
     * Content Generator instance
     *
     * @var IgnisAI_Content_Generator
     */
    private $content_generator;

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
        $this->image_analyzer = new IgnisAI_Image_Analyzer();
        $this->content_generator = new IgnisAI_Content_Generator();
        $this->form_generator = new IgnisAI_Form_Generator();
    }

    /**
     * Generate alt text for all images
     *
     * ## OPTIONS
     *
     * [--limit=<number>]
     * : Maximum number of images to process
     *
     * [--force]
     * : Regenerate alt text even if it already exists
     *
     * ## EXAMPLES
     *
     *     wp ignis-ai generate-alt-text
     *     wp ignis-ai generate-alt-text --limit=50
     *     wp ignis-ai generate-alt-text --force
     *
     * @param array $args Command arguments
     * @param array $assoc_args Command associative arguments
     */
    public function generate_alt_text( $args, $assoc_args ) {
        $limit = isset( $assoc_args['limit'] ) ? (int) $assoc_args['limit'] : -1;
        $force = isset( $assoc_args['force'] );

        // Get all image attachments
        $query_args = array(
            'post_type' => 'attachment',
            'post_mime_type' => 'image',
            'post_status' => 'inherit',
            'posts_per_page' => $limit,
            'fields' => 'ids',
        );

        if ( ! $force ) {
            // Only get images without alt text
            $query_args['meta_query'] = array(
                'relation' => 'OR',
                array(
                    'key' => '_wp_attachment_image_alt',
                    'compare' => 'NOT EXISTS',
                ),
                array(
                    'key' => '_wp_attachment_image_alt',
                    'value' => '',
                    'compare' => '=',
                ),
            );
        }

        $images = get_posts( $query_args );

        if ( empty( $images ) ) {
            WP_CLI::success( 'No images found to process.' );
            return;
        }

        $total = count( $images );
        WP_CLI::log( sprintf( 'Processing %d image(s)...', $total ) );

        $progress = \WP_CLI\Utils\make_progress_bar( 'Generating alt text', $total );

        $success_count = 0;
        $error_count = 0;

        foreach ( $images as $image_id ) {
            $result = $this->image_analyzer->generate_and_save_alt_text( $image_id );

            if ( $result ) {
                $success_count++;
            } else {
                $error_count++;
            }

            $progress->tick();
        }

        $progress->finish();

        WP_CLI::success( sprintf(
            'Completed! Success: %d, Errors: %d',
            $success_count,
            $error_count
        ));
    }

    /**
     * Generate ACF field group from description
     *
     * ## OPTIONS
     *
     * <description>
     * : Description of the fields to generate
     *
     * [--post-type=<post_type>]
     * : Post type to attach fields to
     * ---
     * default: post
     * ---
     *
     * [--title=<title>]
     * : Field group title
     * ---
     * default: AI Generated Fields
     * ---
     *
     * [--preview]
     * : Preview the generated field group without importing
     *
     * ## EXAMPLES
     *
     *     wp ignis-ai generate-form "Product fields: name, price, SKU, description, featured image"
     *     wp ignis-ai generate-form "Event fields with date, location, organizer" --post-type=event
     *     wp ignis-ai generate-form "Book fields" --title="Book Information" --preview
     *
     * @param array $args Command arguments
     * @param array $assoc_args Command associative arguments
     */
    public function generate_form( $args, $assoc_args ) {
        $description = $args[0];
        $post_type = isset( $assoc_args['post-type'] ) ? $assoc_args['post-type'] : 'post';
        $title = isset( $assoc_args['title'] ) ? $assoc_args['title'] : 'AI Generated Fields';
        $preview = isset( $assoc_args['preview'] );

        WP_CLI::log( 'Generating field group...' );

        $field_group = $this->form_generator->generate_field_group( $description, $post_type, $title );

        if ( is_wp_error( $field_group ) ) {
            WP_CLI::error( $field_group->get_error_message() );
            return;
        }

        if ( $preview ) {
            WP_CLI::log( "\nGenerated Field Group:" );
            WP_CLI::log( json_encode( $field_group, JSON_PRETTY_PRINT ) );
            WP_CLI::success( 'Preview complete. Use without --preview to import.' );
            return;
        }

        // Import field group
        WP_CLI::log( 'Importing field group into ACF...' );

        $result = $this->form_generator->import_field_group( $field_group );

        if ( is_wp_error( $result ) ) {
            WP_CLI::error( $result->get_error_message() );
            return;
        }

        WP_CLI::success( sprintf(
            'Field group "%s" created successfully! %d field(s) added.',
            $title,
            count( $field_group['fields'] )
        ));
    }

    /**
     * Generate content for a post field
     *
     * ## OPTIONS
     *
     * <post_id>
     * : Post ID
     *
     * <field_name>
     * : Field name
     *
     * [--prompt=<prompt>]
     * : Custom prompt for generation
     *
     * [--save]
     * : Save the generated content to the field
     *
     * ## EXAMPLES
     *
     *     wp ignis-ai generate-content 123 product_description
     *     wp ignis-ai generate-content 123 excerpt --save
     *     wp ignis-ai generate-content 123 summary --prompt="Write a brief summary"
     *
     * @param array $args Command arguments
     * @param array $assoc_args Command associative arguments
     */
    public function generate_content( $args, $assoc_args ) {
        $post_id = (int) $args[0];
        $field_name = $args[1];
        $custom_prompt = isset( $assoc_args['prompt'] ) ? $assoc_args['prompt'] : '';
        $save = isset( $assoc_args['save'] );

        WP_CLI::log( sprintf( 'Generating content for field "%s" on post %d...', $field_name, $post_id ) );

        $content = $this->content_generator->generate_field_content( $post_id, $field_name, $custom_prompt );

        if ( is_wp_error( $content ) ) {
            WP_CLI::error( $content->get_error_message() );
            return;
        }

        WP_CLI::log( "\nGenerated Content:" );
        WP_CLI::log( $content );

        if ( $save ) {
            if ( function_exists( 'update_field' ) ) {
                update_field( $field_name, $content, $post_id );
                WP_CLI::success( 'Content saved to field.' );
            } else {
                update_post_meta( $post_id, $field_name, $content );
                WP_CLI::success( 'Content saved as post meta.' );
            }
        } else {
            WP_CLI::log( "\nUse --save to save the content." );
        }
    }
}

// Register commands
if ( defined( 'WP_CLI' ) && WP_CLI ) {
    WP_CLI::add_command( 'ignis-ai', 'IgnisAI_CLI_Commands' );
}
