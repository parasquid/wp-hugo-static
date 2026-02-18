<?php
// WordPress Webhook Configuration
// Add this to your theme's functions.php or as a must-use plugin

function trigger_github_action_on_publish($post_id, $post) {
    // Only trigger on publish (not drafts, updates, etc.)
    if ($post->post_status !== 'publish') {
        return;
    }
    
    // Don't trigger for revisions or auto-saves
    if (wp_is_post_revision($post_id) || wp_is_post_autosave($post_id)) {
        return;
    }
    
    // Get environment variables
    $github_token = getenv('GITHUB_TOKEN');
    $github_repo = getenv('GITHUB_REPO'); // format: owner/repo
    
    if (!$github_token || !$github_repo) {
        error_log('GitHub webhook: Missing GITHUB_TOKEN or GITHUB_REPO');
        return;
    }
    
    $url = "https://api.github.com/repos/{$github_repo}/dispatches";
    
    $data = [
        'event_type' => 'wordpress-publish',
        'client_payload' => [
            'post_id' => $post_id,
            'post_title' => $post->post_title,
            'post_type' => $post->post_type,
            'timestamp' => current_time('mysql')
        ]
    ];
    
    $args = [
        'method' => 'POST',
        'headers' => [
            'Accept' => 'application/vnd.github+json',
            'Authorization' => 'Bearer ' . $github_token,
            'X-GitHub-Api-Version' => '2022-11-28',
            'Content-Type' => 'application/json'
        ],
        'body' => json_encode($data),
        'timeout' => 30
    ];
    
    $response = wp_remote_post($url, $args);
    
    if (is_wp_error($response)) {
        error_log('GitHub webhook error: ' . $response->get_error_message());
    } elseif (wp_remote_retrieve_response_code($response) !== 204) {
        error_log('GitHub webhook failed: ' . wp_remote_retrieve_body($response));
    } else {
        error_log('GitHub webhook triggered successfully for post: ' . $post_id);
    }
}

// Hook into post status transitions
add_action('publish_post', 'trigger_github_action_on_publish', 10, 2);
add_action('publish_page', 'trigger_github_action_on_publish', 10, 2);
