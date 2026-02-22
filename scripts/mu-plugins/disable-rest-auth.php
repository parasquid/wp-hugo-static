<?php
/**
 * Plugin Name: Disable REST API Auth for Testing
 * Description: Disables authentication for REST API requests - for test environment only
 */
add_filter('rest_authentication_errors', function($result) {
    return true;
});
