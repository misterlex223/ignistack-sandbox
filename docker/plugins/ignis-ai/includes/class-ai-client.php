<?php
/**
 * AI Client Wrapper Class
 *
 * Provides a unified interface for interacting with Claude API via OpenAI client compatibility
 *
 * @package IgnisAI
 */

// Exit if accessed directly
if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

/**
 * AI Client class
 */
class IgnisAI_Client {

    /**
     * OpenAI client instance
     *
     * @var object
     */
    private $client;

    /**
     * Model to use for completions
     *
     * @var string
     */
    private $model;

    /**
     * Maximum tokens for completions
     *
     * @var int
     */
    private $max_tokens;

    /**
     * Temperature for completions
     *
     * @var float
     */
    private $temperature;

    /**
     * Constructor
     */
    public function __construct() {
        $this->client = ignis_ai()->get_ai_client();
        $this->model = get_option( 'ignis_ai_model', 'claude-sonnet-4-5-20250929' );
        $this->max_tokens = (int) get_option( 'ignis_ai_max_tokens', 4096 );
        $this->temperature = (float) get_option( 'ignis_ai_temperature', 0.7 );
    }

    /**
     * Generate text completion
     *
     * @param string $prompt The prompt to send to AI
     * @param array  $options Optional settings to override defaults
     * @return string|WP_Error Generated text or error
     */
    public function generate_text( $prompt, $options = array() ) {
        if ( null === $this->client ) {
            return new WP_Error(
                'no_ai_client',
                __( 'AI client not initialized. Please check API key configuration.', 'ignis-ai' )
            );
        }

        // Merge options with defaults
        $settings = wp_parse_args( $options, array(
            'model' => $this->model,
            'max_tokens' => $this->max_tokens,
            'temperature' => $this->temperature,
        ));

        try {
            $response = $this->client->chat()->create([
                'model' => $settings['model'],
                'messages' => [
                    [
                        'role' => 'user',
                        'content' => $prompt,
                    ],
                ],
                'max_tokens' => $settings['max_tokens'],
                'temperature' => $settings['temperature'],
            ]);

            if ( isset( $response->choices[0]->message->content ) ) {
                return $response->choices[0]->message->content;
            }

            return new WP_Error(
                'invalid_response',
                __( 'Invalid response from AI service.', 'ignis-ai' )
            );

        } catch ( Exception $e ) {
            error_log( 'IgnisAI Error: ' . $e->getMessage() );
            return new WP_Error(
                'api_error',
                sprintf(
                    /* translators: %s: Error message */
                    __( 'AI API error: %s', 'ignis-ai' ),
                    $e->getMessage()
                )
            );
        }
    }

    /**
     * Generate text with conversation context
     *
     * @param array $messages Array of messages with role and content
     * @param array $options Optional settings to override defaults
     * @return string|WP_Error Generated text or error
     */
    public function chat( $messages, $options = array() ) {
        if ( null === $this->client ) {
            return new WP_Error(
                'no_ai_client',
                __( 'AI client not initialized. Please check API key configuration.', 'ignis-ai' )
            );
        }

        // Merge options with defaults
        $settings = wp_parse_args( $options, array(
            'model' => $this->model,
            'max_tokens' => $this->max_tokens,
            'temperature' => $this->temperature,
        ));

        try {
            $response = $this->client->chat()->create([
                'model' => $settings['model'],
                'messages' => $messages,
                'max_tokens' => $settings['max_tokens'],
                'temperature' => $settings['temperature'],
            ]);

            if ( isset( $response->choices[0]->message->content ) ) {
                return $response->choices[0]->message->content;
            }

            return new WP_Error(
                'invalid_response',
                __( 'Invalid response from AI service.', 'ignis-ai' )
            );

        } catch ( Exception $e ) {
            error_log( 'IgnisAI Error: ' . $e->getMessage() );
            return new WP_Error(
                'api_error',
                sprintf(
                    /* translators: %s: Error message */
                    __( 'AI API error: %s', 'ignis-ai' ),
                    $e->getMessage()
                )
            );
        }
    }

    /**
     * Analyze image and generate description
     *
     * Note: This requires Claude's vision capabilities
     *
     * @param string $image_url URL of the image to analyze
     * @param string $prompt Optional custom prompt
     * @return string|WP_Error Image description or error
     */
    public function analyze_image( $image_url, $prompt = '' ) {
        if ( empty( $prompt ) ) {
            $prompt = __( 'Describe this image concisely for accessibility (alt text). Be descriptive but concise, focusing on the main subject and important details.', 'ignis-ai' );
        }

        // For Claude via OpenAI compatibility, we need to use vision models
        // This may require adjusting based on the actual API compatibility
        $messages = [
            [
                'role' => 'user',
                'content' => [
                    [
                        'type' => 'text',
                        'text' => $prompt,
                    ],
                    [
                        'type' => 'image_url',
                        'image_url' => [
                            'url' => $image_url,
                        ],
                    ],
                ],
            ],
        ];

        return $this->chat( $messages, [
            'model' => 'claude-sonnet-4-5-20250929', // Claude has vision capabilities
            'max_tokens' => 300, // Alt text should be concise
        ]);
    }

    /**
     * Get current model name
     *
     * @return string
     */
    public function get_model() {
        return $this->model;
    }

    /**
     * Set model name
     *
     * @param string $model Model name
     */
    public function set_model( $model ) {
        $this->model = $model;
    }
}
