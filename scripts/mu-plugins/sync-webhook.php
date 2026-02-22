<?php
/**
 * Plugin Name: Sync Webhook
 * Description: Sends webhook notifications when posts/pages change
 */

$webhook_url = getenv('SYNC_WEBHOOK_URL');
$webhook_secret = getenv('SYNC_WEBHOOK_SECRET');

add_action('save_post', function($post_id, $post, $update) {
    if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) return;
    if (!in_array($post->post_type, ['post', 'page'])) return;

    $action = $update ? 'update' : 'create';
    sync_webhook_send($post_id, $post, $action);
}, 10, 3);

add_action('transition_post_status', function($new_status, $old_status, $post) {
    if (!in_array($post->post_type, ['post', 'page'])) return;
    if ($new_status === $old_status) return;

    if ($new_status === 'trash') {
        sync_webhook_send($post->ID, $post, 'delete');
    }
}, 10, 3);

function sync_webhook_send($post_id, $post, $action) {
    global $webhook_url, $webhook_secret;

    if (empty($webhook_url)) return;

    $payload = json_encode([
        'post_id' => $post_id,
        'slug' => $post->post_name,
        'post_type' => $post->post_type,
        'action' => $action,
        'status' => $post->post_status,
        'title' => $post->post_title,
        'modified' => $post->post_modified,
    ]);

    $args = [
        'body' => $payload,
        'headers' => ['Content-Type' => 'application/json'],
        'timeout' => 30,
    ];

    if (!empty($webhook_secret)) {
        $args['headers']['X-Webhook-Secret'] = $webhook_secret;
    }

    wp_remote_post($webhook_url, $args);
}
