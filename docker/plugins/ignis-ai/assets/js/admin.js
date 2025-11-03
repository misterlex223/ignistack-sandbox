/**
 * Admin JavaScript for IgnisAI
 * Handles form generator and admin UI
 */

(function($) {
    'use strict';

    var currentFieldGroup = null;

    $(document).ready(function() {

        // Form generator submission
        $('#ignis-ai-form-generator-form').on('submit', function(e) {
            e.preventDefault();

            var $form = $(this);
            var formData = {
                action: 'ignis_ai_generate_form',
                nonce: ignisAIAdmin.nonce,
                description: $('#field-description').val(),
                title: $('#field-group-title').val(),
                post_type: $('#post-type').val()
            };

            // Show loading
            $('.ignis-ai-input-section').hide();
            $('.ignis-ai-preview-section').hide();
            $('.ignis-ai-loading').show();

            $.ajax({
                url: ignisAIAdmin.ajaxUrl,
                type: 'POST',
                data: formData,
                success: function(response) {
                    if (response.success) {
                        currentFieldGroup = response.data.field_group;
                        $('#field-group-preview').html(response.data.preview_html);

                        $('.ignis-ai-loading').hide();
                        $('.ignis-ai-preview-section').show();
                    } else {
                        alert(response.data.message || 'Error generating field group.');
                        $('.ignis-ai-loading').hide();
                        $('.ignis-ai-input-section').show();
                    }
                },
                error: function() {
                    alert('An error occurred. Please try again.');
                    $('.ignis-ai-loading').hide();
                    $('.ignis-ai-input-section').show();
                }
            });
        });

        // Import field group
        $('#import-field-group').on('click', function() {
            if (!currentFieldGroup) {
                alert('No field group to import.');
                return;
            }

            var $btn = $(this);
            $btn.prop('disabled', true).html('<span class="spinner is-active"></span> Importing...');

            $.ajax({
                url: ignisAIAdmin.ajaxUrl,
                type: 'POST',
                data: {
                    action: 'ignis_ai_import_form',
                    nonce: ignisAIAdmin.nonce,
                    field_group: JSON.stringify(currentFieldGroup)
                },
                success: function(response) {
                    if (response.success) {
                        // Show success message
                        var $success = $('<div class="notice notice-success"><p>' + response.data.message + '</p></div>');
                        $('.ignis-ai-preview-section').prepend($success);

                        // Optionally redirect to edit page after a delay
                        setTimeout(function() {
                            if (response.data.edit_url) {
                                window.location.href = response.data.edit_url;
                            }
                        }, 2000);
                    } else {
                        alert(response.data.message || 'Error importing field group.');
                    }
                },
                error: function() {
                    alert('An error occurred during import.');
                },
                complete: function() {
                    $btn.prop('disabled', false).html('<span class="dashicons dashicons-download"></span> Import into ACF');
                }
            });
        });

        // Regenerate fields
        $('#regenerate-fields').on('click', function() {
            $('.ignis-ai-preview-section').hide();
            $('.ignis-ai-input-section').show();
            currentFieldGroup = null;
        });
    });

})(jQuery);
