<?php

if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && 'https' == $_SERVER['HTTP_X_FORWARDED_PROTO']) {
    $_SERVER['HTTPS'] = 'on';
}

define('WP_CONTENT_DIR', '/var/www/wp-content');

$table_prefix  = getenv('TABLE_PREFIX') ?: 'wp_';

foreach ($_ENV as $key => $value) {
    $capitalized = strtoupper($key);
    if (!defined($capitalized)) {
        define($capitalized, $value);
    }
}

if (!defined('ABSPATH')) {
    define('ABSPATH', dirname(__FILE__) . '/');
}

require_once(ABSPATH . 'wp-secrets.php');
require_once(ABSPATH . 'wp-settings.php');
error_reporting(0);
@ini_set('display_errors', 0);

