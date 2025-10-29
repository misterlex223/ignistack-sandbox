# ACF WordPress REST API Integration Guide for IgniStack

## Overview
The Advanced Custom Fields (ACF) plugin integrates seamlessly with the WordPress REST API, allowing custom field data to be exposed in API responses. This integration is essential for headless WordPress implementations like IgniStack, where custom user data structures need to be accessible via REST endpoints.

## How ACF REST API Integration Works

### 1. Field Groups & REST API
- ACF field groups can be configured with a "Show in REST API" setting
- When enabled, all fields within that group are exposed in API responses
- The setting is available in the field group edit screen under the "Advanced Settings" tab

### 2. Data Structure in API Responses
- Custom field data is available in the `acf` property of REST API responses
- Example response structure:
```json
{
  "id": 1,
  "title": {
    "rendered": "Example Post"
  },
  "acf": {
    "field_1": "Custom value",
    "field_2": ["Array value"],
    "field_3": 123
  }
}
```

### 3. Supported Endpoints
ACF data is available for:
- `/wp-json/wp/v2/posts`
- `/wp-json/wp/v2/pages` 
- `/wp-json/wp/v2/users`
- `/wp-json/wp/v2/media`
- Custom post types
- Terms/taxonomies (with ACF Pro)

### 4. User Data Customization
For custom user data in IgniStack:
- Create field groups targeting "User" in the location rules
- Enable "Show in REST API" for the field group
- User custom fields will appear in `/wp-json/wp/v2/users` endpoints
- Access via `response.acf` property in API responses

### 5. Field Types Supported
All ACF field types are supported including:
- Text, Textarea, Number
- WYSIWYG, Editor
- Image, File uploads
- Repeater, Flexible Content
- Relationship, Post Object
- User, Taxonomy fields
- True/False, Select, Radio

### 6. Best Practices for IgniStack Implementation
- Create field groups with descriptive names and keys
- Use the "Show in REST API" toggle strategically to avoid data bloat
- Consider performance implications when exposing large datasets
- Validate and sanitize custom field data
- Use ACF's built-in field validation for data integrity

### 7. Authentication & Permissions
- ACF data respects standard WordPress REST API permissions
- Private/protected content remains protected
- Custom field data for draft posts is not publicly accessible
- Admin-only fields remain restricted to authorized users

### 8. Example Implementation for User Data
To customize user data in IgniStack:
1. Create a field group with location rules set to "User"
2. Add custom fields (e.g., profile_image, department, skills)
3. Enable "Show in REST API" 
4. Access via `/wp-json/wp/v2/users/{id}` → `response.acf`
5. Custom user fields will be available in the `acf` property

This integration enables IgniStack to leverage WordPress as a fully customizable headless CMS with rich user data structures that can be synchronized with Firebase via the custom sync-fire-wp plugin.

## Implementation Example: Contact Data Structure

### ACF Field Group Definition for Contact Data
To create a contact data structure in WordPress using ACF for the IgniStack demo:

1. Create a new ACF field group called "Contact Information"
2. Set location rules to show on "Post Type" = "contacts" (or "User" for user contacts)
3. Enable "Show in REST API" in Advanced Settings
4. Add the following fields:

#### Field Structure:
- Field 1: contact_name (Text field)
  - Label: "Full Name"
  - Name: "contact_name"
  - Required: Yes

- Field 2: contact_email (Email field)
  - Label: "Email Address"
  - Name: "contact_email"
  - Required: Yes

- Field 3: contact_phone (Text field)
  - Label: "Phone Number"
  - Name: "contact_phone"
  - Placeholder: "+1 (555) 123-4567"

- Field 4: contact_position (Text field)
  - Label: "Position/Title"
  - Name: "contact_position"

- Field 5: contact_department (Select field)
  - Label: "Department"
  - Name: "contact_department"
  - Choices: 
    * engineering: Engineering
    * marketing: Marketing
    * sales: Sales
    * support: Support
    * management: Management

- Field 6: contact_photo (Image field)
  - Label: "Profile Photo"
  - Name: "contact_photo"
  - Return Format: "Array"

- Field 7: contact_social_links (Repeater field)
  - Label: "Social Media Links"
  - Name: "contact_social_links"
  - Sub-fields:
    * social_platform (Select): facebook, twitter, linkedin, instagram
    * social_url (URL): "Profile URL"

- Field 8: contact_bio (Textarea field)
  - Label: "Biography"
  - Name: "contact_bio"
  - New Lines: "Convert to <br> tag"

### REST API Response Structure
When querying contacts via REST API, you'll receive:
```json
{
  "id": 123,
  "title": {
    "rendered": "John Doe"
  },
  "content": {
    "rendered": "<p>Sample content</p>"
  },
  "acf": {
    "contact_name": "John Doe",
    "contact_email": "john.doe@example.com",
    "contact_phone": "+1 (555) 123-4567",
    "contact_position": "Senior Developer",
    "contact_department": "engineering",
    "contact_photo": {
      "ID": 124,
      "alt": "John Doe",
      "caption": "",
      "description": "",
      "filename": "john-doe.jpg",
      "title": "John Doe",
      "url": "http://localhost:8080/wp-content/uploads/john-doe.jpg"
    },
    "contact_social_links": [
      {
        "social_platform": "linkedin",
        "social_url": "https://linkedin.com/in/johndoe"
      },
      {
        "social_platform": "twitter",
        "social_url": "https://twitter.com/johndoe"
      }
    ],
    "contact_bio": "John is a senior developer with 10+ years of experience..."
  }
}
```

### Creating the Field Group Programmatically
You can also register this field group via PHP code in a custom plugin or theme's functions.php:

```php
function register_contact_field_group() {
    if (function_exists('acf_add_local_field_group')) {
        acf_add_local_field_group(array(
            'key' => 'group_contact_info',
            'title' => 'Contact Information',
            'fields' => array(
                array(
                    'key' => 'field_contact_name',
                    'label' => 'Full Name',
                    'name' => 'contact_name',
                    'type' => 'text',
                    'required' => 1,
                ),
                array(
                    'key' => 'field_contact_email',
                    'label' => 'Email Address',
                    'name' => 'contact_email',
                    'type' => 'email',
                    'required' => 1,
                ),
                array(
                    'key' => 'field_contact_phone',
                    'label' => 'Phone Number',
                    'name' => 'contact_phone',
                    'type' => 'text',
                    'placeholder' => '+1 (555) 123-4567',
                ),
                array(
                    'key' => 'field_contact_department',
                    'label' => 'Department',
                    'name' => 'contact_department',
                    'type' => 'select',
                    'choices' => array(
                        'engineering' => 'Engineering',
                        'marketing' => 'Marketing',
                        'sales' => 'Sales',
                        'support' => 'Support',
                        'management' => 'Management',
                    ),
                ),
                array(
                    'key' => 'field_contact_photo',
                    'label' => 'Profile Photo',
                    'name' => 'contact_photo',
                    'type' => 'image',
                    'return_format' => 'array',
                ),
                array(
                    'key' => 'field_contact_social_links',
                    'label' => 'Social Media Links',
                    'name' => 'contact_social_links',
                    'type' => 'repeater',
                    'sub_fields' => array(
                        array(
                            'key' => 'field_social_platform',
                            'label' => 'Platform',
                            'name' => 'social_platform',
                            'type' => 'select',
                            'choices' => array(
                                'facebook' => 'Facebook',
                                'twitter' => 'Twitter',
                                'linkedin' => 'LinkedIn',
                                'instagram' => 'Instagram',
                            ),
                        ),
                        array(
                            'key' => 'field_social_url',
                            'label' => 'Profile URL',
                            'name' => 'social_url',
                            'type' => 'url',
                        ),
                    ),
                ),
                array(
                    'key' => 'field_contact_bio',
                    'label' => 'Biography',
                    'name' => 'contact_bio',
                    'type' => 'textarea',
                    'new_lines' => 'br',
                ),
            ),
            'location' => array(
                array(
                    array(
                        'param' => 'post_type',
                        'operator' => '==',
                        'value' => 'contacts',
                    ),
                ),
            ),
            'show_in_rest' => true,  // This enables REST API support
        ));
    }
}
add_action('acf/init', 'register_contact_field_group');
```

This contact data structure can be used in the IgniStack demo to showcase how ACF enables complex, structured data that is accessible through the WordPress REST API and can be synchronized with Firebase.