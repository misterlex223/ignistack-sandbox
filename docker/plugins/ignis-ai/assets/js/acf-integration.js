/**
 * ACF Integration JavaScript
 * Handles AI generation for ACF fields
 */

(function($) {
    'use strict';

    $(document).ready(function() {

        // Handle AI generate button clicks
        $(document).on('click', '.ignis-ai-generate-btn', function(e) {
            e.preventDefault();

            var $btn = $(this);
            var $wrapper = $btn.closest('.acf-input').length
                ? $btn.closest('.acf-input')
                : $btn.parent();
            var $field = $wrapper.find('input, textarea').first();

            var fieldKey = $btn.data('field-key');
            var fieldName = $btn.data('field-name');
            var fieldType = $btn.data('field-type');
            var postId = $btn.data('post-id');

            // Disable button and show loading
            $btn.prop('disabled', true).hide();
            $wrapper.find('.ignis-ai-loading').show();

            // Make AJAX request
            $.ajax({
                url: ignisAI.ajaxUrl,
                type: 'POST',
                data: {
                    action: 'ignis_ai_generate_acf_field',
                    nonce: ignisAI.nonce,
                    post_id: postId,
                    field_key: fieldKey,
                    field_name: fieldName,
                    field_type: fieldType
                },
                success: function(response) {
                    if (response.success) {
                        // Update field value based on field type
                        updateFieldValue($field, response.data.content, fieldType);

                        // Show success message
                        showNotice('success', ignisAI.strings.success);
                    } else {
                        showNotice('error', response.data.message || ignisAI.strings.error);
                    }
                },
                error: function() {
                    showNotice('error', ignisAI.strings.error);
                },
                complete: function() {
                    // Re-enable button and hide loading
                    $btn.prop('disabled', false).show();
                    $wrapper.find('.ignis-ai-loading').hide();
                }
            });
        });

        /**
         * Update field value based on field type
         */
        function updateFieldValue($field, content, fieldType) {
            if (fieldType === 'wysiwyg') {
                // For WYSIWYG fields, we need to use ACF's API
                var fieldKey = $field.closest('.acf-field').data('key');
                if (fieldKey && typeof acf !== 'undefined') {
                    var field = acf.getField(fieldKey);
                    if (field) {
                        field.val(content);
                        return;
                    }
                }
            }

            // For other field types, just set the value
            $field.val(content).trigger('change');
        }

        /**
         * Show admin notice
         */
        function showNotice(type, message) {
            var $notice = $('<div class="notice notice-' + type + ' is-dismissible"><p>' + message + '</p></div>');

            // Find the best place to insert the notice
            var $container = $('.wrap > h1, .wrap > h2').first();
            if ($container.length) {
                $container.after($notice);
            } else {
                $('.wrap').prepend($notice);
            }

            // Auto-dismiss after 3 seconds
            setTimeout(function() {
                $notice.fadeTo slow(function() {
                    $notice.slideUp('slow', function() {
                        $notice.remove();
                    });
                });
            }, 3000);
        }
    });

})(jQuery);
