<?php
/**
 * AutoTagLLM Extension for FreshRSS
 * Adds tags to new entries using OpenAI
 * Author: Thiago
 * License: MIT
 */

class AutoTagLLMExtension extends Minz_Extension {
    // Configuration properties
    public $model = 'gpt-4o-mini';
    public $prompt = '';
    public $baseUrl = '';
    public $apiKey = '';
    
    // No client needed
    public $feeds = [];
    public $categories = [];
    public $enabledFeeds = [];

    public function init() {
        try {
            $this->registerHook('entry_before_insert', array($this, 'onEntryBeforeInsert'));
            $this->registerController('AutoTagLLM');
            $this->loadConfigValues();
        } catch (Exception $e) {
            Minz_Log::error('AutoTagLLM: Failed to initialize extension: ' . $e->getMessage());
        }
    }

    public function loadConfigValues() {
        try {
            // Ensure context is available like Readable extension does
            if (!class_exists('FreshRSS_Context', false) || null === FreshRSS_Context::$user_conf) {
                Minz_Log::warning('AutoTagLLM: FreshRSS context not available');
                return;
            }
            
            // Load configuration values from user settings with validation
            $this->model = FreshRSS_Context::$user_conf->autotagllm_model ?? 'gpt-4o-mini';
            if (empty(trim($this->model))) {
                $this->model = 'gpt-4o-mini';
                Minz_Log::warning('AutoTagLLM: Empty model name, using default: gpt-4o-mini');
            }
            
            $this->prompt = FreshRSS_Context::$user_conf->autotagllm_prompt ?? '';
            $this->baseUrl = FreshRSS_Context::$user_conf->autotagllm_base_url ?? '';
            $this->apiKey = FreshRSS_Context::$user_conf->autotagllm_api_key ?? '';
            
            // Load enabled feeds from config - follow Readable extension pattern
            $feedsConfig = FreshRSS_Context::$user_conf->autotagllm_feeds ?? '';
            if (!empty($feedsConfig)) {
                $decoded = json_decode($feedsConfig, true);
                if (json_last_error() === JSON_ERROR_NONE && is_array($decoded)) {
                    $this->enabledFeeds = $decoded;
                } else {
                    Minz_Log::warning('AutoTagLLM: Invalid JSON in feeds configuration, resetting to empty array');
                    $this->enabledFeeds = [];
                }
            } else {
                $this->enabledFeeds = [];
            }
            
            // Ensure it's an array
            if (!is_array($this->enabledFeeds)) {
                Minz_Log::warning('AutoTagLLM: Enabled feeds is not an array, resetting to empty array');
                $this->enabledFeeds = [];
            }
            
            // Debug: Log what we loaded
            Minz_Log::debug('AutoTagLLM: Loaded enabled feeds: ' . json_encode($this->enabledFeeds));
        } catch (Exception $e) {
            Minz_Log::error('AutoTagLLM: Error loading configuration: ' . $e->getMessage());
            // Set safe defaults
            $this->model = 'gpt-4o-mini';
            $this->prompt = '';
            $this->baseUrl = '';
            $this->apiKey = '';
            $this->enabledFeeds = [];
        }
    }

    public function onEntryBeforeInsert($entry) {
        try {
            // Validate entry object
            if (!$entry instanceof FreshRSS_Entry) {
                Minz_Log::warning('AutoTagLLM: Invalid entry object passed to onEntryBeforeInsert');
                return $entry;
            }

            // Only run for enabled feeds - use same logic as Readable extension
            $feedId = null;
            try {
                $entryArray = $entry->toArray();
                if (empty($entryArray['id_feed'])) {
                    $feedId = $entry->feed(false);
                } else { 
                    $feedId = $entryArray['id_feed'];
                }
            } catch (Exception $e) {
                Minz_Log::warning('AutoTagLLM: Error getting feed ID: ' . $e->getMessage());
                return $entry;
            }
            
            // Ensure feedId is a valid array key type
            if (!is_string($feedId) && !is_int($feedId)) {
                Minz_Log::warning('AutoTagLLM: Invalid feed ID type: ' . gettype($feedId));
                return $entry;
            }
            
            // Skip if feed is not enabled (but allow entries with existing tags to be processed)
            if (!array_key_exists($feedId, $this->enabledFeeds)) {
                Minz_Log::debug('AutoTagLLM: Feed ' . $feedId . ' is not enabled, skipping');
                return $entry;
            }
            
            $candidateTags = $this->suggestTags($entry);
            if ($candidateTags === []) {
                return $entry; // No tags suggested
            }
            
            // Get existing tags on the entry (may be empty)
            $existingTags = $entry->tags() ?: [];
            
            // Filter candidate tags to only include valid strings
            $validCandidateTags = [];
            foreach ($candidateTags as $tag) {
                if (is_string($tag) && !empty(trim($tag))) {
                    $validCandidateTags[] = trim($tag);
                }
            }
            
            // Merge existing tags with new candidate tags and remove duplicates
            $allTags = array_unique(array_merge($existingTags, $validCandidateTags));
            
            // Set the combined tag list back on the entry
            try {
                $entry->_tags($allTags);
                Minz_Log::debug('AutoTagLLM: Added tags to entry: ' . json_encode($validCandidateTags));
            } catch (Exception $e) {
                Minz_Log::warning('AutoTagLLM: Error setting tags on entry: ' . $e->getMessage());
            }
            
            return $entry;
        } catch (Exception $e) {
            Minz_Log::error('AutoTagLLM: Unexpected error in onEntryBeforeInsert: ' . $e->getMessage());
            return $entry; // Always return the entry, even on error
        }
    }
    public function handleConfigureAction() {
        try {
            $feedDAO = FreshRSS_Factory::createFeedDao();
            $catDAO = FreshRSS_Factory::createCategoryDao();
            
            if (!$feedDAO || !$catDAO) {
                Minz_Log::error('AutoTagLLM: Failed to create DAO objects');
                return;
            }
            
            $this->feeds = $feedDAO->listFeeds();
            $this->categories = $catDAO->listCategories(true, false);
            
            if (Minz_Request::isPost()) {
                $enabled = [];
                
                try {
                    // Save configuration settings with validation
                    $model = (string)Minz_Request::param('autotagllm_model', 'gpt-4o-mini');
                    $prompt = (string)Minz_Request::param('autotagllm_prompt', '');
                    $baseUrl = (string)Minz_Request::param('autotagllm_base_url', '');
                    $apiKey = (string)Minz_Request::param('autotagllm_api_key', '');
                    
                    // Validate model name
                    if (empty(trim($model))) {
                        $model = 'gpt-4o-mini';
                        Minz_Log::warning('AutoTagLLM: Empty model name provided, using default');
                    }
                    
                    // Validate base URL format if provided
                    if (!empty($baseUrl) && !filter_var($baseUrl, FILTER_VALIDATE_URL)) {
                        Minz_Log::warning('AutoTagLLM: Invalid base URL format provided: ' . $baseUrl);
                        $baseUrl = ''; // Reset to default
                    }
                    
                    FreshRSS_Context::$user_conf->autotagllm_model = $model;
                    FreshRSS_Context::$user_conf->autotagllm_prompt = $prompt;
                    FreshRSS_Context::$user_conf->autotagllm_base_url = $baseUrl;
                    FreshRSS_Context::$user_conf->autotagllm_api_key = $apiKey;
                    
                    // Process feed selections like Readable extension does
                    // Only store entries with value=1, not all feeds
                    if (is_array($this->feeds)) {
                        foreach ($this->feeds as $feed) {
                            if ($feed && method_exists($feed, 'id')) {
                                $feedId = $feed->id();
                                if ((bool)Minz_Request::param('autotagllm_feed_' . $feedId, 0)) {
                                    $enabled[$feedId] = true;
                                }
                            }
                        }
                    }
                    
                    // Debug: Log what we're about to save
                    Minz_Log::debug('AutoTagLLM: Saving enabled feeds: ' . json_encode($enabled));
                    
                    // JSON encode and save - follows Readable extension pattern
                    $jsonEncoded = json_encode($enabled);
                    if (json_last_error() === JSON_ERROR_NONE) {
                        FreshRSS_Context::$user_conf->autotagllm_feeds = $jsonEncoded;
                        FreshRSS_Context::$user_conf->save();
                    } else {
                        Minz_Log::error('AutoTagLLM: Failed to JSON encode enabled feeds: ' . json_last_error_msg());
                    }
                } catch (Exception $e) {
                    Minz_Log::error('AutoTagLLM: Error saving configuration: ' . $e->getMessage());
                }
            }
            
            // Load config values after potential saving (like Readable extension)
            $this->loadConfigValues();
        } catch (Exception $e) {
            Minz_Log::error('AutoTagLLM: Error in handleConfigureAction: ' . $e->getMessage());
        }
    }

    public function getCategories() {
        return $this->categories;
    }

    public function getFeeds() {
        return $this->feeds;
    }

    public function isFeedEnabled($feedId) {
        try {
            if (!is_string($feedId) && !is_int($feedId)) {
                Minz_Log::warning('AutoTagLLM: Invalid feed ID type in isFeedEnabled: ' . gettype($feedId));
                return false;
            }
            return array_key_exists($feedId, $this->enabledFeeds);
        } catch (Exception $e) {
            Minz_Log::warning('AutoTagLLM: Error checking if feed is enabled: ' . $e->getMessage());
            return false;
        }
    }

    private function suggestTags(FreshRSS_Entry $entry): array {
        try {
            // Validate API key
            $apiKey = $this->apiKey ?: getenv('OPENAI_API_KEY');
            if (!$apiKey || empty(trim($apiKey))) {
                Minz_Log::warning('AutoTagLLM: API key not configured. Please set it in extension settings or OPENAI_API_KEY environment variable');
                return [];
            }
            
            // Validate and prepare base URL
            $baseUrl = $this->baseUrl ?: 'https://api.openai.com/v1';
            $baseUrl = rtrim($baseUrl, '/');
            if (!filter_var($baseUrl, FILTER_VALIDATE_URL)) {
                Minz_Log::warning('AutoTagLLM: Invalid base URL: ' . $baseUrl);
                return [];
            }
            $url = $baseUrl . '/chat/completions';
            
            // Extract and validate content
            $title = '';
            $content = '';
            try {
                $title = trim($entry->title()) ?: 'No title';
                $content = $this->sanitizeContent($entry->content());
            } catch (Exception $e) {
                Minz_Log::warning('AutoTagLLM: Error extracting content from entry: ' . $e->getMessage());
                return [];
            }
            
            if (empty($content) && $title === 'No title') {
                Minz_Log::debug('AutoTagLLM: Entry has no content and no title, skipping');
                return [];
            }
            
            // Prepare prompt with validation
            $systemPrompt = $this->prompt ?: "Extract 3-5 concise tags for the following article. Return as a JSON array of strings in lowercase with underscores instead of spaces (snake_case). Example: [\"artificial_intelligence\", \"machine_learning\", \"technology\"]";
            $userContent = $title . "\n\n" . $content;
            
            // Validate model name
            $model = trim($this->model);
            if (empty($model)) {
                $model = 'gpt-4o-mini';
                Minz_Log::warning('AutoTagLLM: Empty model name, using default: gpt-4o-mini');
            }
            
            $payload = [
                'model' => $model,
                'temperature' => 0.2,
                'messages' => [
                    ['role' => 'system', 'content' => $systemPrompt],
                    ['role' => 'user', 'content' => $userContent]
                ],
                'max_tokens' => 100,
                'response_format' => ['type' => 'json_object']
            ];
            
            // Initialize cURL with error handling
            $ch = curl_init($url);
            if ($ch === false) {
                Minz_Log::error('AutoTagLLM: Failed to initialize cURL');
                return [];
            }
            
            try {
                curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
                curl_setopt($ch, CURLOPT_POST, true);
                curl_setopt($ch, CURLOPT_HTTPHEADER, [
                    'Content-Type: application/json',
                    'Authorization: Bearer ' . $apiKey
                ]);
                curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
                curl_setopt($ch, CURLOPT_TIMEOUT, 30); // 30 second timeout
                curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 10); // 10 second connection timeout
                curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
                curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
                curl_setopt($ch, CURLOPT_MAXREDIRS, 3);
                
                $result = curl_exec($ch);
                $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
                $curlError = curl_error($ch);
                
                if ($result === false) {
                    Minz_Log::warning('AutoTagLLM: cURL execution failed: ' . $curlError);
                    return [];
                }
                
                if ($httpCode !== 200) {
                    $errorMsg = 'HTTP ' . $httpCode;
                    if (!empty($result)) {
                        $errorResponse = json_decode($result, true);
                        if (isset($errorResponse['error']['message'])) {
                            $errorMsg .= ': ' . $errorResponse['error']['message'];
                        }
                    }
                    Minz_Log::warning('AutoTagLLM: API request failed: ' . $errorMsg . ' | URL: ' . $url);
                    return [];
                }
                
                // Parse response with error handling
                $response = json_decode($result, true);
                if (json_last_error() !== JSON_ERROR_NONE) {
                    Minz_Log::warning('AutoTagLLM: Invalid JSON in API response: ' . json_last_error_msg());
                    return [];
                }
                
                if (!isset($response['choices'][0]['message']['content'])) {
                    Minz_Log::warning('AutoTagLLM: Unexpected API response structure');
                    return [];
                }
                
                $json = $response['choices'][0]['message']['content'];
                $decoded = json_decode($json, true);
                if (json_last_error() !== JSON_ERROR_NONE) {
                    Minz_Log::warning('AutoTagLLM: Invalid JSON in generated content: ' . json_last_error_msg());
                    return [];
                }
                
                // Handle different possible JSON structures
                $tags = [];
                if (isset($decoded['tags']) && is_array($decoded['tags'])) {
                    $tags = $decoded['tags'];
                } elseif (is_array($decoded)) {
                    // If it's a direct array
                    $tags = $decoded;
                }
                
                // Filter and validate tags
                $validTags = [];
                foreach ($tags as $tag) {
                    if (is_string($tag) && !empty(trim($tag))) {
                        $cleanTag = trim($tag);
                        if (strlen($cleanTag) <= 100) { // Reasonable tag length limit
                            $validTags[] = $cleanTag;
                        }
                    }
                }
                
                return $validTags;
                
            } finally {
                curl_close($ch);
            }
        } catch (Exception $e) {
            Minz_Log::error('AutoTagLLM: Unexpected error in suggestTags: ' . $e->getMessage());
            return [];
        }
    }

    private function sanitizeContent(string $content): string {
        try {
            if (empty($content)) {
                return '';
            }
            
            // Remove HTML tags and decode entities
            $text = html_entity_decode(strip_tags($content), ENT_QUOTES | ENT_HTML5, 'UTF-8');
            
            // Handle potential encoding issues
            if (!mb_check_encoding($text, 'UTF-8')) {
                $text = mb_convert_encoding($text, 'UTF-8', 'UTF-8');
                Minz_Log::debug('AutoTagLLM: Fixed encoding issues in content');
            }
            
            // Limit content length to avoid token limits (roughly 1000 words)
            $text = mb_substr($text, 0, 4000, 'UTF-8');
            
            // Clean up whitespace
            $text = preg_replace('/\s+/', ' ', $text);
            
            return trim($text);
        } catch (Exception $e) {
            Minz_Log::warning('AutoTagLLM: Error sanitizing content: ' . $e->getMessage());
            return '';
        }
    }

    private function getExistingTags(): array {
        static $cache = null;
        
        try {
            if ($cache !== null) {
                return $cache;
            }
            
            $tagDao = FreshRSS_Factory::createTagDao();
            if (!$tagDao) {
                Minz_Log::error('AutoTagLLM: Failed to create TagDAO');
                $cache = [];
                return $cache;
            }
            
            $tags = $tagDao->listAll();
            if (!is_array($tags)) {
                Minz_Log::warning('AutoTagLLM: TagDAO->listAll() did not return an array');
                $cache = [];
                return $cache;
            }
            
            $cache = array_map('strval', $tags);
            return $cache;
        } catch (Exception $e) {
            Minz_Log::error('AutoTagLLM: Error getting existing tags: ' . $e->getMessage());
            $cache = [];
            return $cache;
        }
    }
}
