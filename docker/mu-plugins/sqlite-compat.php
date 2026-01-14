<?php
/**
 * Plugin Name: SQLite Compatibility Constants
 * Description: Define missing database constants for SQLite integration compatibility
 * Version: 1.0.0
 * Author: IgniStack
 *
 * This mu-plugin defines standard WordPress database constants that are
 * required by WordPress core even when using SQLite as the database engine.
 *
 * Without these constants, WordPress may throw "Undefined constant DB_NAME"
 * errors in certain core functions (e.g., wp-includes/update.php).
 *
 * Mu-plugins (must-use plugins) are loaded automatically before all other
 * plugins and cannot be disabled from the WordPress admin interface.
 *
 * @package IgniStack
 */

// Define standard WordPress database constants for compatibility
// These are required by WordPress core even when using SQLite
if (!defined('DB_NAME')) {
    define('DB_NAME', 'sqlite');
}
if (!defined('DB_USER')) {
    define('DB_USER', 'sqlite');
}
if (!defined('DB_PASSWORD')) {
    define('DB_PASSWORD', 'sqlite');
}
if (!defined('DB_HOST')) {
    define('DB_HOST', 'localhost');
}
