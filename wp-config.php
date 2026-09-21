<?php
if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && 'https' == $_SERVER['HTTP_X_FORWARDED_PROTO']) {
    $_SERVER['HTTPS'] = 'on';
}

define('WP_CONTENT_DIR', '/var/www/wp-content');
define('WP_AUTO_UPDATE_CORE', false );

$table_prefix  = getenv('TABLE_PREFIX') ?: 'wp_';

$boolean_constants = [
    'DISABLE_WP_CRON',
    'WP_CACHE',
    'WP_DEBUG',
    'WP_DEBUG_DISPLAY',
];

foreach ($_ENV as $key => $value) {
    $capitalized = strtoupper($key);
    if (!defined($capitalized)) {
        if (in_array($capitalized, $boolean_constants, true)) {
            $parsed = filter_var($value, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
            define($capitalized, null === $parsed ? false : $parsed);
        } else {
            define($capitalized, $value);
        }
    }
}

if (!defined('WP_CACHE')) {
    define('WP_CACHE', false);
}

if (!defined('ABSPATH')) {
    define('ABSPATH', dirname(__FILE__) . '/');
}

require_once(ABSPATH . 'wp-secrets.php');
require_once(ABSPATH . 'wp-settings.php');
@ini_set('display_errors', 0);
