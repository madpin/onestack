<?php
/**
 * tldrplugin for Tiny Tiny RSS
 *
 * Generates TL;DR summaries and automatically tags articles using the OpenAI API.
 * Offers extensive configuration for both summarization and tagging features,
 * including content length limits, API parameters, and text truncation options.
 */
class tldrplugin extends Plugin
{
    // Plugin constants
    const PLUGIN_VERSION = 1.1;
    const PLUGIN_NAME = "TLDR Summarizer & Auto Tag";
    const PLUGIN_DESCRIPTION = "Generates TL;DR summaries and auto-tags articles using OpenAI, with advanced configuration.";
    const PLUGIN_AUTHOR = "your_github_username/tldr_plugin";
    
    // Default settings
    const DEFAULT_API_BASE_URL = "https://api.openai.com/v1";
    const DEFAULT_MODEL = "gpt-4.1-nano";
    const DEFAULT_TLDR_PROMPT = "Please provide a concise TL;DR summary of the following article in 1-2 sentences. Focus on the main points and key takeaways.";
    const DEFAULT_MAX_TOKENS = 150;
    const DEFAULT_CURL_TIMEOUT = 60;
    const DEFAULT_CURL_CONNECT_TIMEOUT = 30;
    const DEFAULT_MIN_ARTICLE_LENGTH = 200;
    const DEFAULT_LABEL_LANGUAGE = "English";
    const DEFAULT_MAX_TAGS = 5;
    const DEFAULT_MIN_TAG_LENGTH = 50;
    const DEFAULT_TLDR_FALLBACK_MAX_CHARS = 15000;
    const DEFAULT_TLDR_TRUNCATE_TRIGGER = 1200;
    const DEFAULT_TLDR_KEEP_START = 1000;
    const DEFAULT_TLDR_KEEP_END = 200;
    const DEFAULT_AUTOTAG_FALLBACK_MAX_CHARS = 10000;
    const DEFAULT_AUTOTAG_TRUNCATE_TRIGGER = 1000;
    const DEFAULT_AUTOTAG_KEEP_START = 800;
    const DEFAULT_AUTOTAG_KEEP_END = 200;
    
    // Class properties
    /** @var PluginHost $host Reference to the PluginHost object */
    private $host;
    
    /** @var bool Flag to track if label color palette is initialized */
    private $label_colors_initialized = false;
    
    /** @var array Palette of hex color codes for labels */
    private $label_palette = [];
    
    // ===========================================
    // Plugin Interface Methods (TT-RSS required)
    // ===========================================
    
    /**
     * Returns information about the plugin.
     * @return array Plugin information
     */
    public function about()
    {
        return array(
            self::PLUGIN_VERSION,
            self::PLUGIN_DESCRIPTION,
            self::PLUGIN_AUTHOR
        );
    }

    /**
     * Declares plugin capabilities.
     * @return array Associative array of flags
     */
    public function flags()
    {
        return array(
            "needs_curl" => true // Requires cURL for API calls
        );
    }

    /**
     * Returns the API version of the plugin.
     * Required by TTRSS.
     * @return int API version.
     */
    public function api_version()
    {
        return 2;
    }

    /**
     * Initializes the plugin, sets up hooks and handlers.
     * @param PluginHost $host The PluginHost object.
     * @return void
     */
    public function init($host)
    {
        $this->host = $host;
        
        if (version_compare(PHP_VERSION, '7.0.0', '<')) {
            _debug("tldrplugin: PHP version too old, requires 7.0+");
            return;
        }

        // Register hooks
        $host->add_hook($host::HOOK_ARTICLE_FILTER, $this);
        $host->add_hook($host::HOOK_ARTICLE_FILTER_ACTION, $this);
        $host->add_hook($host::HOOK_PREFS_TAB, $this);
        $host->add_hook($host::HOOK_PREFS_EDIT_FEED, $this);
        $host->add_hook($host::HOOK_PREFS_SAVE_FEED, $this);
        $host->add_hook($host::HOOK_ARTICLE_BUTTON, $this);
        
        // Register AJAX handlers
        $host->add_handler("summarizeArticle", "*", $this);
        $host->add_handler("autoTagArticle", "*", $this);
        $host->add_handler("testApiConnection", "*", $this);
        
        _debug("tldrplugin: Plugin initialized successfully");
    }

    /**
     * Returns the JavaScript code for the plugin.
     * @return string JavaScript code.
     */
    public function get_js()
    {
        return file_get_contents(__DIR__ . "/tldr_plugin.js");
    }

    
    // ===========================================
    // Settings Management Methods
    // ===========================================
    
    /**
     * Saves plugin settings from the preferences screen.
     * Handles validation and persistence of all configurable options.
     * @return void
     */
    public function save()
    {
        // Extract and validate settings
        $settings = $this->extractSettingsFromPost();
        
        if (!$this->validateSettings($settings)) {
            return; // Error messages already displayed
        }
        
        $this->saveSettings($settings);
        
        echo __(self::PLUGIN_NAME . " settings saved.");
    }
    
    /**
     * Extracts settings from POST data with defaults.
     * @return array Associative array of settings
     */
    private function extractSettingsFromPost()
    {
        return [
            // Core OpenAI settings
            'openai_api_key' => trim($_POST["openai_api_key"] ?? ""),
            'openai_base_url' => trim($_POST["openai_base_url"] ?? ""),
            'openai_model' => trim($_POST["openai_model"] ?? ""),
            'tldr_prompt' => trim($_POST["tldr_prompt"] ?? ""),
            'tldr_max_tokens' => (int)($_POST["tldr_max_tokens"] ?? self::DEFAULT_MAX_TOKENS),
            'curl_timeout' => (int)($_POST["curl_timeout"] ?? self::DEFAULT_CURL_TIMEOUT),
            'curl_connect_timeout' => (int)($_POST["curl_connect_timeout"] ?? self::DEFAULT_CURL_CONNECT_TIMEOUT),
            'tldr_min_article_length' => (int)($_POST["tldr_min_article_length"] ?? self::DEFAULT_MIN_ARTICLE_LENGTH),
            
            // Auto Tag settings
            'autotag_enabled' => checkbox_to_sql_bool($_POST["autotag_enabled"] ?? ""),
            'autotag_label_language' => trim($_POST["autotag_label_language"] ?? self::DEFAULT_LABEL_LANGUAGE),
            'autotag_openai_model' => trim($_POST["autotag_openai_model"] ?? self::DEFAULT_MODEL),
            'autotag_max_tags' => (int)($_POST["autotag_max_tags"] ?? self::DEFAULT_MAX_TAGS),
            'autotag_min_article_length' => (int)($_POST["autotag_min_article_length"] ?? self::DEFAULT_MIN_TAG_LENGTH),
            
            // TLDR Truncation settings
            'tldr_fallback_max_chars' => (int)($_POST["tldr_fallback_max_chars"] ?? self::DEFAULT_TLDR_FALLBACK_MAX_CHARS),
            'tldr_truncate_trigger_length' => (int)($_POST["tldr_truncate_trigger_length"] ?? self::DEFAULT_TLDR_TRUNCATE_TRIGGER),
            'tldr_truncate_keep_start' => (int)($_POST["tldr_truncate_keep_start"] ?? self::DEFAULT_TLDR_KEEP_START),
            'tldr_truncate_keep_end' => (int)($_POST["tldr_truncate_keep_end"] ?? self::DEFAULT_TLDR_KEEP_END),
            
            // AutoTag Truncation settings
            'autotag_fallback_max_chars' => (int)($_POST["autotag_fallback_max_chars"] ?? self::DEFAULT_AUTOTAG_FALLBACK_MAX_CHARS),
            'autotag_truncate_trigger_length' => (int)($_POST["autotag_truncate_trigger_length"] ?? self::DEFAULT_AUTOTAG_TRUNCATE_TRIGGER),
            'autotag_truncate_keep_start' => (int)($_POST["autotag_truncate_keep_start"] ?? self::DEFAULT_AUTOTAG_KEEP_START),
            'autotag_truncate_keep_end' => (int)($_POST["autotag_truncate_keep_end"] ?? self::DEFAULT_AUTOTAG_KEEP_END),
        ];
    }
    
    /**
     * Validates plugin settings.
     * @param array $settings Settings to validate
     * @return bool True if valid, false otherwise
     */
    private function validateSettings($settings)
    {
        // Validate API key
        if (empty($settings['openai_api_key'])) {
            echo __("OpenAI API Key is required.");
            return false;
        }
        
        if (!preg_match('/^sk-[a-zA-Z0-9\-_]+$/', $settings['openai_api_key'])) {
            echo __("Invalid OpenAI API Key format.");
            return false;
        }
        
        // Validate base URL if provided
        if (!empty($settings['openai_base_url']) && !filter_var($settings['openai_base_url'], FILTER_VALIDATE_URL)) {
            echo __("Invalid OpenAI Base URL format.");
            return false;
        }
        
        return true;
    }
    
    /**
     * Saves settings to the host.
     * @param array $settings Settings to save
     * @return void
     */
    private function saveSettings($settings)
    {
        // Apply defaults and save core settings
        $this->host->set($this, "openai_api_key", $settings['openai_api_key']);
        $this->host->set($this, "openai_base_url", $settings['openai_base_url'] ?: self::DEFAULT_API_BASE_URL);
        $this->host->set($this, "openai_model", $settings['openai_model'] ?: self::DEFAULT_MODEL);
        $this->host->set($this, "tldr_prompt", $settings['tldr_prompt'] ?: self::DEFAULT_TLDR_PROMPT);
        $this->host->set($this, "tldr_max_tokens", $settings['tldr_max_tokens'] > 0 ? $settings['tldr_max_tokens'] : self::DEFAULT_MAX_TOKENS);
        $this->host->set($this, "curl_timeout", $settings['curl_timeout'] > 0 ? $settings['curl_timeout'] : self::DEFAULT_CURL_TIMEOUT);
        $this->host->set($this, "curl_connect_timeout", $settings['curl_connect_timeout'] > 0 ? $settings['curl_connect_timeout'] : self::DEFAULT_CURL_CONNECT_TIMEOUT);
        $this->host->set($this, "tldr_min_article_length", $settings['tldr_min_article_length'] >= 0 ? $settings['tldr_min_article_length'] : self::DEFAULT_MIN_ARTICLE_LENGTH);

        // Save Auto Tag settings
        $this->host->set($this, "autotag_enabled", $settings['autotag_enabled']);
        $this->host->set($this, "autotag_label_language", $settings['autotag_label_language'] ?: self::DEFAULT_LABEL_LANGUAGE);
        $this->host->set($this, "autotag_openai_model", $settings['autotag_openai_model'] ?: self::DEFAULT_MODEL);
        $this->host->set($this, "autotag_max_tags", $settings['autotag_max_tags'] > 0 ? $settings['autotag_max_tags'] : self::DEFAULT_MAX_TAGS);
        $this->host->set($this, "autotag_min_article_length", $settings['autotag_min_article_length'] >= 0 ? $settings['autotag_min_article_length'] : self::DEFAULT_MIN_TAG_LENGTH);

        // Save TLDR Truncation settings
        $this->host->set($this, "tldr_fallback_max_chars", $settings['tldr_fallback_max_chars'] > 0 ? $settings['tldr_fallback_max_chars'] : self::DEFAULT_TLDR_FALLBACK_MAX_CHARS);
        $this->host->set($this, "tldr_truncate_trigger_length", $settings['tldr_truncate_trigger_length'] >= 0 ? $settings['tldr_truncate_trigger_length'] : self::DEFAULT_TLDR_TRUNCATE_TRIGGER);
        $this->host->set($this, "tldr_truncate_keep_start", $settings['tldr_truncate_keep_start'] >= 0 ? $settings['tldr_truncate_keep_start'] : self::DEFAULT_TLDR_KEEP_START);
        $this->host->set($this, "tldr_truncate_keep_end", $settings['tldr_truncate_keep_end'] >= 0 ? $settings['tldr_truncate_keep_end'] : self::DEFAULT_TLDR_KEEP_END);

        // Save AutoTag Truncation settings
        $this->host->set($this, "autotag_fallback_max_chars", $settings['autotag_fallback_max_chars'] > 0 ? $settings['autotag_fallback_max_chars'] : self::DEFAULT_AUTOTAG_FALLBACK_MAX_CHARS);
        $this->host->set($this, "autotag_truncate_trigger_length", $settings['autotag_truncate_trigger_length'] >= 0 ? $settings['autotag_truncate_trigger_length'] : self::DEFAULT_AUTOTAG_TRUNCATE_TRIGGER);
        $this->host->set($this, "autotag_truncate_keep_start", $settings['autotag_truncate_keep_start'] >= 0 ? $settings['autotag_truncate_keep_start'] : self::DEFAULT_AUTOTAG_KEEP_START);
        $this->host->set($this, "autotag_truncate_keep_end", $settings['autotag_truncate_keep_end'] >= 0 ? $settings['autotag_truncate_keep_end'] : self::DEFAULT_AUTOTAG_KEEP_END);
    }

    
    // ===========================================
    // TT-RSS Hook Methods
    // ===========================================
    
    /**
     * Adds a button to the article display for manual TL;DR generation.
     * Implements HOOK_ARTICLE_BUTTON.
     * @param array $line Article data.
     * @return string HTML for the button.
     */
    public function hook_article_button($line)
    {
        return "<span class='tldr-plugin-buttons'>" .
               "<i class='material-icons' style='cursor : pointer' onclick='Plugins.tldrplugin.summarizeArticle(".$line["id"].")' title='".__('Generate TL;DR')."'>short_text</i>" .
               "<i class='material-icons' style='cursor : pointer; margin-left: 5px;' onclick='Plugins.tldrplugin.autoTagArticle(".$line["id"].")' title='".__('Generate Auto Tags')."'>label</i>" .
               "</span>";
    }

    /**
     * Filters article data. Main hook for automatic TL;DR and Auto-Tagging.
     * Implements HOOK_ARTICLE_FILTER.
     * @param array $article The article data array.
     * @return array The modified (or original) article data array.
     */
    public function hook_article_filter($article)
    {
        // TLDR processing
        $tldr_enabled_feeds = $this->host->get_array($this, "tldr_enabled_feeds");
        if (isset($article["feed"]["id"]) && in_array($article["feed"]["id"], $tldr_enabled_feeds)) {
            $article = $this->process_article($article);
        }

        // Auto Tag processing
        $autotag_globally_enabled = $this->host->get($this, "autotag_enabled", false);
        if ($autotag_globally_enabled) {
            $article = $this->processAutoTags($article);
        }
        
        return $article;
    }

    /**
     * Potentially handles actions triggered on articles after they are stored.
     * HOOK_ARTICLE_FILTER_ACTION is called after the article is processed and stored.
     * @param array $article The article data.
     * @param string $action The action being performed.
     * @return array The (potentially modified) article data.
     */
    public function hook_article_filter_action($article, $action)
    {
        _debug("tldrplugin: hook_article_filter_action called with action: " . $action);
        
        // Check if we need to process delayed tags
        if ($action == 'store' && isset($article['_delayed_tags'])) {
            $article_id = $article['id'] ?? null;
            $owner_uid = $article['owner_uid'] ?? 0;
            
            if ($article_id && !empty($article['_delayed_tags'])) {
                _debug("tldrplugin: Processing delayed tags for article: " . $article_id);
                $success = $this->create_tags_for_article($article_id, $article['_delayed_tags'], $owner_uid);
                if ($success) {
                    _debug("tldrplugin: Successfully applied delayed tags to article: " . $article_id);
                } else {
                    _debug("tldrplugin: Failed to apply delayed tags to article: " . $article_id);
                }
                unset($article['_delayed_tags']);
            }
        }
        
        return $article;
    }
    
    /**
     * Processes auto-tagging for an article.
     * @param array $article The article data array.
     * @return array The modified (or original) article data array.
     */
    private function processAutoTags($article)
    {
        $autotag_enabled_feeds = $this->host->get_array($this, "autotag_enabled_feeds");
        
        if (!isset($article["feed"]["id"]) || !in_array($article["feed"]["id"], $autotag_enabled_feeds)) {
            return $article;
        }
        
        $autotag_min_article_length = (int)$this->host->get($this, "autotag_min_article_length", self::DEFAULT_MIN_TAG_LENGTH);
        $content_for_tag_length_check = trim(strip_tags($article["content"] ?? ""));
        
        if ($autotag_min_article_length > 0 && mb_strlen($content_for_tag_length_check) < $autotag_min_article_length) {
            $article_identifier = $article["id"] ?? $article["guid"] ?? $article["title"] ?? "unknown";
            _debug("tldrplugin: AutoTag: Article content length " . mb_strlen($content_for_tag_length_check) . " is less than minimum " . $autotag_min_article_length . " for tagging. Skipping for article: " . $article_identifier);
            return $article;
        }
        
        $article_identifier = $article["id"] ?? $article["guid"] ?? $article["title"] ?? "unknown";
        _debug("tldrplugin: AutoTag: Processing article: " . $article_identifier . " for auto-tagging. Article ID: " . ($article["id"] ?? "not set"));
        
        // Check if we have a valid article ID for database operations
        $article_id = $article["id"] ?? null;
        $owner_uid = $article["owner_uid"] ?? 0;
        
        $suggested_data = $this->get_labels_and_tags_from_openai(
            $article["content"] ?? "", 
            $article["title"] ?? "", 
            $owner_uid
        );
        
        $suggested_labels = $suggested_data['labels'] ?? [];
        $suggested_tags = $suggested_data['tags'] ?? [];
        
        // Handle labels
        if (!empty($suggested_labels)) {
            if (!isset($article["labels"]) || !is_array($article["labels"])) {
                $article["labels"] = [];
            }
            
            foreach ($suggested_labels as $label_caption) {
                $label_exists = false;
                foreach ($article["labels"] as $existing_label_arr) {
                    if (is_array($existing_label_arr) && count($existing_label_arr) > 1 && 
                        mb_strtolower($existing_label_arr[1]) === mb_strtolower($label_caption)) {
                        $label_exists = true;
                        break;
                    }
                }
                
                if (!$label_exists) {
                    $label_data = $this->get_or_create_label($label_caption, $owner_uid);
                    if ($label_data) {
                        array_push($article["labels"], $label_data);
                        _debug("tldrplugin: AutoTag: Added label '$label_caption' to article: " . $article_identifier);
                    }
                } else {
                    _debug("tldrplugin: AutoTag: Label '$label_caption' already exists for article: " . $article_identifier);
                }
            }
        }
        
        // Handle tags
        if (!empty($suggested_tags)) {
            // TT-RSS expects tags as a comma-separated string, not an array
            $existing_tags_str = $article["tags"] ?? "";
            $existing_tags = !empty($existing_tags_str) ? explode(",", $existing_tags_str) : [];
            
            // Clean existing tags
            $existing_tags = array_map('trim', $existing_tags);
            $existing_tags = array_filter($existing_tags);
            
            $new_tags = [];
            
            foreach ($suggested_tags as $tag_name) {
                $tag_name = trim($tag_name);
                if (empty($tag_name)) continue;
                
                $tag_exists = false;
                foreach ($existing_tags as $existing_tag) {
                    if (mb_strtolower($existing_tag) === mb_strtolower($tag_name)) {
                        $tag_exists = true;
                        break;
                    }
                }
                
                if (!$tag_exists) {
                    $new_tags[] = $tag_name;
                    _debug("tldrplugin: AutoTag: Added tag '$tag_name' to article: " . $article_identifier);
                } else {
                    _debug("tldrplugin: AutoTag: Tag '$tag_name' already exists for article: " . $article_identifier);
                }
            }
            
            // Combine all tags and store as comma-separated string
            if (!empty($new_tags)) {
                $all_tags = array_merge($existing_tags, $new_tags);
                $article["tags"] = implode(",", $all_tags);
                _debug("tldrplugin: AutoTag: Set article tags to: " . $article["tags"]);
                
                // Also store for delayed processing if needed
                if (!$article_id) {
                    $article["_delayed_tags"] = $new_tags;
                    _debug("tldrplugin: AutoTag: Stored delayed tags for later processing");
                }
            }
        }
        
        return $article;
    }

    /**
     * Renders the plugin's settings tab in preferences.
     * Implements HOOK_PREFS_TAB.
     * @param string $args Name of the active preferences tab.
     * @return void
     */
    public function hook_prefs_tab($args)
    {
        if ($args != "prefFeeds") {
            return;
        }

        print "<div dojoType='dijit.layout.AccordionPane' 
            title=\"<i class='material-icons'>short_text</i> ".__('TLDR Summarizer Settings (tldrplugin)')."\">";

        if (version_compare(PHP_VERSION, '7.0.0', '<')) {
            print_error("This plugin requires PHP 7.0.");
        } else {
            $this->renderSettingsForm();
            $this->renderFeedListings();
        }
        
        print "</div>";
    }

    /**
     * Renders plugin-specific options in the feed editor.
     * Implements HOOK_PREFS_EDIT_FEED.
     * @param int $feed_id The ID of the feed being edited.
     * @return void
     */
    public function hook_prefs_edit_feed($feed_id)
    {
        // TLDR per-feed setting
        print "<header>".__("TLDR Summarizer")."</header>";
        print "<section>";
        
        $tldr_enabled_feeds = $this->host->get_array($this, "tldr_enabled_feeds");
        $tldr_checked = in_array($feed_id, $tldr_enabled_feeds) ? "checked" : "";

        print "<fieldset>";
        print "<label class='checkbox'><input dojoType='dijit.form.CheckBox' type='checkbox' id='tldr_plugin_enabled' name='tldr_plugin_enabled' $tldr_checked>&nbsp;" . __('Generate TL;DR summary for this feed') . "</label>";
        print "</fieldset>";
        print "</section>";

        // Auto Tag per-feed setting
        print "<header>".__("Auto Tagging")."</header>";
        print "<section>";

        $autotag_enabled_feeds = $this->host->get_array($this, "autotag_enabled_feeds");
        $autotag_checked = in_array($feed_id, $autotag_enabled_feeds) ? "checked" : "";

        print "<fieldset>";
        print "<label class='checkbox'><input dojoType='dijit.form.CheckBox' type='checkbox' id='autotag_plugin_enabled' name='autotag_plugin_enabled' $autotag_checked>&nbsp;" . __('Automatically generate tags for this feed') . "</label>";
        print "</fieldset>";
        print "</section>";
    }

    /**
     * Saves plugin-specific options from the feed editor.
     * Implements HOOK_PREFS_SAVE_FEED.
     * @param int $feed_id The ID of the feed being saved.
     * @return void
     */
    public function hook_prefs_save_feed($feed_id)
    {
        // Save TLDR per-feed setting
        $tldr_enabled_feeds = $this->host->get_array($this, "tldr_enabled_feeds");
        $enable_tldr = checkbox_to_sql_bool($_POST["tldr_plugin_enabled"] ?? "");
        $tldr_key = array_search($feed_id, $tldr_enabled_feeds);

        if ($enable_tldr) {
            if ($tldr_key === false) {
                array_push($tldr_enabled_feeds, $feed_id);
            }
        } else {
            if ($tldr_key !== false) {
                unset($tldr_enabled_feeds[$tldr_key]);
            }
        }
        $this->host->set($this, "tldr_enabled_feeds", $tldr_enabled_feeds);

        // Save Auto Tag per-feed setting
        $autotag_enabled_feeds = $this->host->get_array($this, "autotag_enabled_feeds");
        $enable_autotag = checkbox_to_sql_bool($_POST["autotag_plugin_enabled"] ?? "");
        $autotag_key = array_search($feed_id, $autotag_enabled_feeds);

        if ($enable_autotag) {
            if ($autotag_key === false) {
                array_push($autotag_enabled_feeds, $feed_id);
            }
        } else {
            if ($autotag_key !== false) {
                unset($autotag_enabled_feeds[$autotag_key]);
            }
        }
        $this->host->set($this, "autotag_enabled_feeds", $autotag_enabled_feeds);
    }
    
    // ===========================================
    // UI Helper Methods
    // ===========================================
    
    /**
     * Renders the main settings form.
     * @return void
     */
    private function renderSettingsForm()
    {
        print "<h2>" . __("OpenAI Configuration") . "</h2>";
        print "<form dojoType='dijit.form.Form'>";
        print "<script type='dojo/method' event='onSubmit' args='evt'>
            evt.preventDefault();
            if (this.validate()) {
            xhr.post(\"backend.php\", this.getValues(), (reply) => {
                        Notify.info(reply);
                    })
            }
            </script>";
        print \Controls\pluginhandler_tags($this, "save");
        
        $this->renderCoreSettings();
        $this->renderTldrSettings();
        $this->renderConnectionSettings();
        $this->renderAutotagSettings();
        
        print "<button dojoType=\"dijit.form.Button\" type=\"submit\" class=\"alt-primary\">".__('Save Settings')."</button>";
        print "&nbsp;<button dojoType=\"dijit.form.Button\" type=\"button\" onclick=\"
            xhr.json('backend.php', App.getPhArgs('tldrplugin', 'testApiConnection'), (reply) => {
                if (reply.error) {
                    Notify.error('API Test Failed: ' + reply.error);
                } else {
                    Notify.info('API Test Successful: ' + reply.response);
                }
            });
        \">".__('Test API Connection')."</button>";
        print "</form>";
    }
    
    /**
     * Renders core OpenAI settings.
     * @return void
     */
    private function renderCoreSettings()
    {
        $openai_api_key = $this->host->get($this, "openai_api_key");
        $openai_base_url = $this->host->get($this, "openai_base_url", self::DEFAULT_API_BASE_URL);
        $openai_model = $this->host->get($this, "openai_model", self::DEFAULT_MODEL);
        
        print "<fieldset>";
        print "<legend>" . __("Core OpenAI Settings") . "</legend>";
        print "<label for='openai_api_key'>" . __("OpenAI API Key:") . "</label>";
        print "<input dojoType='dijit.form.ValidationTextBox' required='1' type='password' name='openai_api_key' id='openai_api_key' value='" . htmlspecialchars($openai_api_key, ENT_QUOTES) . "'/>";
        print "<label for='openai_base_url'>" . __("OpenAI Base URL:") . "</label>";
        print "<input dojoType='dijit.form.TextBox' name='openai_base_url' id='openai_base_url' value='" . htmlspecialchars($openai_base_url, ENT_QUOTES) . "' placeholder='" . self::DEFAULT_API_BASE_URL . "'/>";
        print "<label for='openai_model'>" . __("OpenAI Model:") . "</label>";
        print "<input dojoType='dijit.form.TextBox' name='openai_model' id='openai_model' value='" . htmlspecialchars($openai_model, ENT_QUOTES) . "' placeholder='" . self::DEFAULT_MODEL . "'/>";
        print "</fieldset>";
    }
    
    /**
     * Renders TL;DR specific settings.
     * @return void
     */
    private function renderTldrSettings()
    {
        $tldr_prompt = $this->host->get($this, "tldr_prompt", self::DEFAULT_TLDR_PROMPT);
        $tldr_max_tokens = $this->host->get($this, "tldr_max_tokens", self::DEFAULT_MAX_TOKENS);
        $tldr_min_article_length = $this->host->get($this, "tldr_min_article_length", self::DEFAULT_MIN_ARTICLE_LENGTH);
        $tldr_fallback_max_chars = $this->host->get($this, "tldr_fallback_max_chars", self::DEFAULT_TLDR_FALLBACK_MAX_CHARS);
        $tldr_truncate_trigger_length = $this->host->get($this, "tldr_truncate_trigger_length", self::DEFAULT_TLDR_TRUNCATE_TRIGGER);
        $tldr_truncate_keep_start = $this->host->get($this, "tldr_truncate_keep_start", self::DEFAULT_TLDR_KEEP_START);
        $tldr_truncate_keep_end = $this->host->get($this, "tldr_truncate_keep_end", self::DEFAULT_TLDR_KEEP_END);
        
        print "<fieldset>";
        print "<legend>" . __("TL;DR Specific Settings") . "</legend>";
        print "<label for='tldr_prompt'>" . __("TL;DR Prompt Instruction:") . "</label>";
        print "<textarea dojoType='dijit.form.SimpleTextarea' name='tldr_prompt' id='tldr_prompt' style='width: 100%; height: 80px;'>" . htmlspecialchars($tldr_prompt, ENT_QUOTES) . "</textarea>";
        print "<span class='text-muted'>" . __("This text is sent to OpenAI to instruct it on how to summarize.") . "</span>";
        
        print "<label for='tldr_max_tokens'>" . __("TL;DR Max Tokens (Summary Length):") . "</label>";
        print "<input dojoType='dijit.form.NumberSpinner' name='tldr_max_tokens' id='tldr_max_tokens' value='" . ((int)$tldr_max_tokens) . "' constraints='{min:50,max:1000,places:0}' style='width: 100px;'/>";
        print "<span class='text-muted'>" . __("Max tokens for summary. Approx 3-4 tokens per word.") . "</span>";
        
        print "<label for='tldr_min_article_length'>" . __("TL;DR Min Article Length (Chars):") . "</label>";
        print "<input dojoType='dijit.form.NumberSpinner' name='tldr_min_article_length' id='tldr_min_article_length' value='" . ((int)$tldr_min_article_length) . "' constraints='{min:0,max:5000,places:0}' style='width: 100px;'/>";
        print "<span class='text-muted'>" . __("Only generate TL;DR if content is longer than this.") . "</span>";
        
        print "<label for='tldr_fallback_max_chars'>" . __("TL;DR Fallback Max Characters:") . "</label>";
        print "<input dojoType='dijit.form.NumberSpinner' name='tldr_fallback_max_chars' id='tldr_fallback_max_chars' value='" . ((int)$tldr_fallback_max_chars) . "' constraints='{min:1000,max:100000,places:0}' style='width: 100px;'/>";
        print "<span class='text-muted'>" . __("Fallback max characters if advanced truncation is disabled.") . "</span>";
        
        print "<label for='tldr_truncate_trigger_length'>" . __("TL;DR Truncate if longer than (Chars):") . "</label>";
        print "<input dojoType='dijit.form.NumberSpinner' name='tldr_truncate_trigger_length' id='tldr_truncate_trigger_length' value='" . ((int)$tldr_truncate_trigger_length) . "' constraints='{min:0,max:100000,places:0}' style='width: 100px;'/>";
        print "<span class='text-muted'>" . __("Apply start/end truncation if longer. Set 0 to disable.") . "</span>";
        
        print "<label for='tldr_truncate_keep_start'>" . __("TL;DR Keep Start Chars:") . "</label>";
        print "<input dojoType='dijit.form.NumberSpinner' name='tldr_truncate_keep_start' id='tldr_truncate_keep_start' value='" . ((int)$tldr_truncate_keep_start) . "' constraints='{min:0,max:50000,places:0}' style='width: 100px;'/>";
        
        print "<label for='tldr_truncate_keep_end'>" . __("TL;DR Keep End Chars:") . "</label>";
        print "<input dojoType='dijit.form.NumberSpinner' name='tldr_truncate_keep_end' id='tldr_truncate_keep_end' value='" . ((int)$tldr_truncate_keep_end) . "' constraints='{min:0,max:50000,places:0}' style='width: 100px;'/>";
        print "<span class='text-muted'>" . __("Characters to keep from start and end for truncation.") . "</span>";
        print "</fieldset>";
    }
    
    /**
     * Renders connection settings.
     * @return void
     */
    private function renderConnectionSettings()
    {
        $curl_timeout = $this->host->get($this, "curl_timeout", self::DEFAULT_CURL_TIMEOUT);
        $curl_connect_timeout = $this->host->get($this, "curl_connect_timeout", self::DEFAULT_CURL_CONNECT_TIMEOUT);
        
        print "<fieldset>";
        print "<legend>" . __("Connection Settings") . "</legend>";
        print "<label for='curl_timeout'>" . __("cURL Timeout (seconds):") . "</label>";
        print "<input dojoType='dijit.form.NumberSpinner' name='curl_timeout' id='curl_timeout' value='" . ((int)$curl_timeout) . "' constraints='{min:10,max:300,places:0}' style='width: 100px;'/>";
        print "<label for='curl_connect_timeout'>" . __("cURL Connect Timeout (seconds):") . "</label>";
        print "<input dojoType='dijit.form.NumberSpinner' name='curl_connect_timeout' id='curl_connect_timeout' value='" . ((int)$curl_connect_timeout) . "' constraints='{min:5,max:60,places:0}' style='width: 100px;'/>";
        print "</fieldset>";
    }
    
    /**
     * Renders auto-tagging settings.
     * @return void
     */
    private function renderAutotagSettings()
    {
        print "<hr/>";
        print "<h2>" . __("Auto Tag Settings") . "</h2>";
        
        $autotag_enabled = $this->host->get($this, "autotag_enabled", false);
        $autotag_label_language = $this->host->get($this, "autotag_label_language", self::DEFAULT_LABEL_LANGUAGE);
        $autotag_openai_model = $this->host->get($this, "autotag_openai_model", self::DEFAULT_MODEL);
        $autotag_max_tags = $this->host->get($this, "autotag_max_tags", self::DEFAULT_MAX_TAGS);
        $autotag_min_article_length = $this->host->get($this, "autotag_min_article_length", self::DEFAULT_MIN_TAG_LENGTH);
        $autotag_fallback_max_chars = $this->host->get($this, "autotag_fallback_max_chars", self::DEFAULT_AUTOTAG_FALLBACK_MAX_CHARS);
        $autotag_truncate_trigger_length = $this->host->get($this, "autotag_truncate_trigger_length", self::DEFAULT_AUTOTAG_TRUNCATE_TRIGGER);
        $autotag_truncate_keep_start = $this->host->get($this, "autotag_truncate_keep_start", self::DEFAULT_AUTOTAG_KEEP_START);
        $autotag_truncate_keep_end = $this->host->get($this, "autotag_truncate_keep_end", self::DEFAULT_AUTOTAG_KEEP_END);
        
        print "<fieldset>";
        print "<legend>" . __("General Auto Tagging") . "</legend>";
        print "<label class='checkbox'><input dojoType='dijit.form.CheckBox' type='checkbox' name='autotag_enabled' id='autotag_enabled' " . ($autotag_enabled ? "checked" : "") . ">&nbsp;" . __('Enable Auto Tagging globally') . "</label>";
        print "<span class='text-muted'>" . __("If enabled, tags will be generated based on per-feed settings.") . "</span>";
        print "</fieldset>";
        
        print "<fieldset>";
        print "<legend>" . __("Auto Tagging - OpenAI Settings") . "</legend>";
        print "<label for='autotag_openai_model'>" . __("OpenAI Model for Tagging:") . "</label>";
        print "<input dojoType='dijit.form.TextBox' name='autotag_openai_model' id='autotag_openai_model' value='" . htmlspecialchars($autotag_openai_model, ENT_QUOTES) . "' placeholder='" . self::DEFAULT_MODEL . "'/>";
        print "<span class='text-muted'>" . __("Model for generating tags. API Key and Base URL from Core settings will be used.") . "</span>";
        
        print "<label for='autotag_label_language'>" . __("Label Language:") . "</label>";
        print "<input dojoType='dijit.form.TextBox' name='autotag_label_language' id='autotag_label_language' value='" . htmlspecialchars($autotag_label_language, ENT_QUOTES) . "' placeholder='" . self::DEFAULT_LABEL_LANGUAGE . "'/>";
        print "<span class='text-muted'>" . __("Language for generated tags (e.g., English, Spanish, zh-CN).") . "</span>";
        
        print "<label for='autotag_max_tags'>" . __("Max Tags per Article:") . "</label>";
        print "<input dojoType='dijit.form.NumberSpinner' name='autotag_max_tags' id='autotag_max_tags' value='" . ((int)$autotag_max_tags) . "' constraints='{min:1,max:10,places:0}' style='width: 100px;'/>";
        print "<span class='text-muted'>" . __("Maximum number of tags to generate per article.") . "</span>";
        
        print "<label for='autotag_min_article_length'>" . __("Min Article Length for Tags (Chars):") . "</label>";
        print "<input dojoType='dijit.form.NumberSpinner' name='autotag_min_article_length' id='autotag_min_article_length' value='" . ((int)$autotag_min_article_length) . "' constraints='{min:0,max:5000,places:0}' style='width: 100px;'/>";
        print "<span class='text-muted'>" . __("Only generate tags if content is longer than this.") . "</span>";
        
        print "<label for='autotag_fallback_max_chars'>" . __("AutoTag Fallback Max Characters:") . "</label>";
        print "<input dojoType='dijit.form.NumberSpinner' name='autotag_fallback_max_chars' id='autotag_fallback_max_chars' value='" . ((int)$autotag_fallback_max_chars) . "' constraints='{min:1000,max:100000,places:0}' style='width: 100px;'/>";
        print "<span class='text-muted'>" . __("Fallback max characters if advanced truncation is disabled.") . "</span>";
        
        print "<label for='autotag_truncate_trigger_length'>" . __("AutoTag Truncate if longer than (Chars):") . "</label>";
        print "<input dojoType='dijit.form.NumberSpinner' name='autotag_truncate_trigger_length' id='autotag_truncate_trigger_length' value='" . ((int)$autotag_truncate_trigger_length) . "' constraints='{min:0,max:100000,places:0}' style='width: 100px;'/>";
        print "<span class='text-muted'>" . __("Apply start/end truncation if longer. Set 0 to disable.") . "</span>";
        
        print "<label for='autotag_truncate_keep_start'>" . __("AutoTag Keep Start Chars:") . "</label>";
        print "<input dojoType='dijit.form.NumberSpinner' name='autotag_truncate_keep_start' id='autotag_truncate_keep_start' value='" . ((int)$autotag_truncate_keep_start) . "' constraints='{min:0,max:50000,places:0}' style='width: 100px;'/>";
        
        print "<label for='autotag_truncate_keep_end'>" . __("AutoTag Keep End Chars:") . "</label>";
        print "<input dojoType='dijit.form.NumberSpinner' name='autotag_truncate_keep_end' id='autotag_truncate_keep_end' value='" . ((int)$autotag_truncate_keep_end) . "' constraints='{min:0,max:50000,places:0}' style='width: 100px;'/>";
        print "<span class='text-muted'>" . __("Characters to keep from start and end for truncation.") . "</span>";
        print "</fieldset>";
    }
    
    /**
     * Renders the feed listings section.
     * @return void
     */
    private function renderFeedListings()
    {
        print "<h2>" . __("Per-feed Auto-summarization & Auto-tagging") . "</h2>";
        print_notice("Enable for specific feeds in the feed editor.");
        
        $tldr_enabled_feeds = $this->host->get_array($this, "tldr_enabled_feeds");
        $this->host->set($this, "tldr_enabled_feeds", $tldr_enabled_feeds);
        
        if (count($tldr_enabled_feeds) > 0) {
            print "<h3>" . __("TL;DR enabled for (click to edit):") . "</h3>";
            print "<ul class='panel panel-scrollable list list-unstyled'>";
            foreach ($tldr_enabled_feeds as $f) {
                $feed_title = Feeds::_get_title($f);
                print "<li><i class='material-icons'>rss_feed</i> <a href='#' onclick='CommonDialogs.editFeed($f)'>". htmlspecialchars($feed_title) . " (ID: $f)</a></li>";
            }
            print "</ul>";
        } else {
            print "<p>" . __("TL;DR auto-summarization is not enabled for any feeds.") . "</p>";
        }
        
        $autotag_enabled_feeds = $this->host->get_array($this, "autotag_enabled_feeds");
        $this->host->set($this, "autotag_enabled_feeds", $autotag_enabled_feeds);
        
        if (count($autotag_enabled_feeds) > 0) {
            print "<h3>" . __("Auto-Tagging enabled for (click to edit):") . "</h3>";
            print "<ul class='panel panel-scrollable list list-unstyled'>";
            foreach ($autotag_enabled_feeds as $f) {
                $feed_title = Feeds::_get_title($f);
                print "<li><i class='material-icons'>label</i> <a href='#' onclick='CommonDialogs.editFeed($f)'>". htmlspecialchars($feed_title) . " (ID: $f)</a></li>";
            }
            print "</ul>";
        } else {
            print "<p>" . __("Auto-tagging is not enabled for any feeds.") . "</p>";
        }
    }
    
    // ===========================================
    // Core Article Processing Methods
    // ===========================================

    
    /**
     * Calls the OpenAI API to generate a TL;DR summary for the given text content.
     * Uses configured settings for API key, model, prompt, tokens, and truncation.
     * @param string $text_content The raw article content (HTML or plain text).
     * @param string $article_title The title of the article (optional).
     * @return string The generated summary text, or an empty string on failure.
     */
    private function get_openai_summary($text_content, $article_title = "") 
    {
        $api_key = $this->host->get($this, "openai_api_key");
        $base_url = $this->host->get($this, "openai_base_url", self::DEFAULT_API_BASE_URL);
        $model = $this->host->get($this, "openai_model", self::DEFAULT_MODEL);
        $tldr_prompt_setting = $this->host->get($this, "tldr_prompt", self::DEFAULT_TLDR_PROMPT);
        $tldr_max_tokens = (int)$this->host->get($this, "tldr_max_tokens", self::DEFAULT_MAX_TOKENS);
        $curl_timeout = (int)$this->host->get($this, "curl_timeout", self::DEFAULT_CURL_TIMEOUT);
        $curl_connect_timeout = (int)$this->host->get($this, "curl_connect_timeout", self::DEFAULT_CURL_CONNECT_TIMEOUT);

        _debug("tldrplugin: Starting TLDR summary generation with model: $model, base_url: $base_url, max_tokens: $tldr_max_tokens");

        // Basic text cleaning
        $text_content = strip_tags($text_content);
        $text_content = trim($text_content);
        
        // Get TLDR truncation settings
        $tldr_fallback_max_chars = (int)$this->host->get($this, "tldr_fallback_max_chars", self::DEFAULT_TLDR_FALLBACK_MAX_CHARS);
        $tldr_truncate_trigger_length = (int)$this->host->get($this, "tldr_truncate_trigger_length", self::DEFAULT_TLDR_TRUNCATE_TRIGGER);
        $tldr_truncate_keep_start = (int)$this->host->get($this, "tldr_truncate_keep_start", self::DEFAULT_TLDR_KEEP_START);
        $tldr_truncate_keep_end = (int)$this->host->get($this, "tldr_truncate_keep_end", self::DEFAULT_TLDR_KEEP_END);
        
        $text_content = $this->truncate_text(
            $text_content,
            $tldr_truncate_trigger_length,
            $tldr_truncate_keep_start,
            $tldr_truncate_keep_end,
            $tldr_fallback_max_chars
        );
        
        _debug("tldrplugin: TLDR content length after potential truncation: " . mb_strlen($text_content));

        $prompt_body = $tldr_prompt_setting;
        if (!empty($article_title)) {
            $prompt_body .= " The title of the article is \"" . htmlspecialchars($article_title) . "\".";
        }
        $prompt_body .= "\n\nArticle content:\n\n" . $text_content;

        $data = [
            "model" => $model,
            "messages" => [
                ["role" => "system", "content" => "You are a helpful assistant that provides concise summaries."],
                ["role" => "user", "content" => $prompt_body]
            ],
            "max_tokens" => $tldr_max_tokens
        ];

        $response = $this->callOpenAI($data, $api_key, $base_url, $curl_timeout, $curl_connect_timeout);
        
        if (empty($response)) {
            return "";
        }

        $summary = trim($response['choices'][0]['message']['content']);
        _debug("tldrplugin: Successfully generated summary: " . substr($summary, 0, 100) . "...");
        return $summary;
    }
    
    /**
     * Makes an API call to OpenAI.
     * @param array $data The request data
     * @param string $api_key The API key
     * @param string $base_url The base URL
     * @param int $curl_timeout The timeout
     * @param int $curl_connect_timeout The connect timeout
     * @return array|null The decoded response or null on failure
     */
    private function callOpenAI($data, $api_key, $base_url, $curl_timeout, $curl_connect_timeout)
    {
        $headers = [
            "Authorization: Bearer " . $api_key,
            "Content-Type: application/json"
        ];

        _debug("tldrplugin: Making API request to: " . rtrim($base_url, '/') . "/chat/completions");

        $ch = curl_init(rtrim($base_url, '/') . "/chat/completions");
        
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, $curl_timeout);
        curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, $curl_connect_timeout);

        $response = curl_exec($ch);
        $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curl_error = curl_error($ch);
        curl_close($ch);

        _debug("tldrplugin: API response - HTTP code: $http_code");

        if ($curl_error) {
            _debug("tldrplugin: cURL error: $curl_error");
            return null;
        }

        if ($http_code !== 200) {
            _debug("tldrplugin: HTTP error: $http_code");
            return null;
        }

        $decoded_response = json_decode($response, true);
        
        if (!$decoded_response || !isset($decoded_response['choices']) || 
            !isset($decoded_response['choices'][0]['message']['content'])) {
            _debug("tldrplugin: Invalid response format");
            return null;
        }

        return $decoded_response;
    }
    
    /**
     * Processes an article to potentially add a TL;DR summary.
     * Checks configured minimum article length before attempting summarization.
     * @param array $article The article data array.
     * @return array The modified (or original) article data array.
     */
    public function process_article($article)
    {
        $tldr_min_article_length = (int)$this->host->get($this, "tldr_min_article_length", self::DEFAULT_MIN_ARTICLE_LENGTH);
        $content_for_length_check = trim(strip_tags($article["content"] ?? ""));

        if ($tldr_min_article_length > 0 && mb_strlen($content_for_length_check) < $tldr_min_article_length) {
            $article_identifier = $article["id"] ?? $article["guid"] ?? $article["title"] ?? "unknown";
            _debug("tldrplugin: Article content length " . mb_strlen($content_for_length_check) . " is less than minimum " . $tldr_min_article_length . ". Skipping TLDR for article: " . $article_identifier);
            return $article;
        }

        $summary_text = $this->get_openai_summary($article["content"] ?? "", $article["title"] ?? "");

        if (empty($summary_text)) {
            $article_identifier = $article["id"] ?? $article["guid"] ?? $article["title"] ?? "unknown";
            _debug("tldrplugin: Failed to get summary or summary was empty for article: " . $article_identifier);
            return $article;
        }

        $tldr_html = "<div class='tldr-summary' style='border: 1px solid #ddd; padding: 10px; margin-bottom: 15px; background-color: #f9f9f9;'>";
        $tldr_html .= "<p><strong>TL;DR</strong></p>";
        $tldr_html .= "<p>" . htmlspecialchars($summary_text) . "</p>";
        $tldr_html .= "</div>";
        $article["content"] = $tldr_html . ($article["content"] ?? "");

        return $article;
    }
    
    // ===========================================
    // AJAX Handler Methods
    // ===========================================

    
    /**
     * Handles AJAX request to manually summarize an article.
     * Fetches article content, calls OpenAI, and returns summary HTML or error.
     * @return void Outputs JSON response.
     */
    public function summarizeArticle() 
    {
        header('Content-Type: application/json');
        
        $article_id = (int) ($_REQUEST["id"] ?? 0);
        if (!$article_id) {
            print json_encode(["error" => "missing_id", "message" => __("Article ID is missing.")]);
            return;
        }
        
        _debug("tldrplugin: summarizeArticle called for article ID: $article_id");

        $pdo = Db::pdo();
        $sth = $pdo->prepare("SELECT te.content, te.title FROM ttrss_entries te 
                             JOIN ttrss_user_entries tue ON te.id = tue.ref_id 
                             WHERE te.id = ? AND tue.owner_uid = ?");
        $sth->execute([$article_id, $_SESSION['uid']]);
        $article_row = $sth->fetch();

        if (!$article_row) {
            _debug("tldrplugin: Article not found or access denied for ID: $article_id");
            print json_encode(["error" => "article_not_found", "message" => __("Article not found or access denied.")]);
            return;
        }

        _debug("tldrplugin: Found article: " . substr($article_row["title"], 0, 50) . "...");

        $content_for_length_check = trim(strip_tags($article_row["content"]));
        $actual_content_length = mb_strlen($content_for_length_check);
        $tldr_min_article_length = (int)$this->host->get($this, "tldr_min_article_length", self::DEFAULT_MIN_ARTICLE_LENGTH);

        if ($tldr_min_article_length > 0 && $actual_content_length < $tldr_min_article_length) {
            _debug("tldrplugin: Article content length " . $actual_content_length . " is less than minimum " . $tldr_min_article_length . ".");
            print json_encode([
                "error" => "article_too_short",
                "message" => __("Article content is too short for a summary (min: %d chars, found: %d chars).", $tldr_min_article_length, $actual_content_length)
            ]);
            return;
        }

        $summary_text = $this->get_openai_summary($article_row["content"], $article_row["title"]);

        if (empty($summary_text)) {
            _debug("tldrplugin: Failed to get summary for article ID: " . $article_id);
            print json_encode([
                "error" => "summary_generation_failed",
                "message" => __("Failed to generate summary. Check plugin logs for details.")
            ]);
            return;
        }

        $tldr_html = "<div class=\"tldr-summary\" style='border: 1px solid #ddd; padding: 10px; margin-bottom: 15px; background-color: #f9f9f9;'>";
        $tldr_html .= "<p><strong>TL;DR</strong></p>";
        $tldr_html .= "<p>" . htmlspecialchars($summary_text) . "</p>";
        $tldr_html .= "</div>";
        
        _debug("tldrplugin: Successfully generated TLDR HTML for manual request");
        print json_encode(["tldr_html" => $tldr_html]);
    }

    /**
     * Handles AJAX request to manually auto-tag an article.
     * Fetches article content, calls OpenAI for tags, creates labels, and applies them.
     * @return void Outputs JSON response.
     */
    public function autoTagArticle() {
        header('Content-Type: application/json');
        
        $article_id = (int) ($_REQUEST["id"] ?? 0);
        if (!$article_id) {
            print json_encode(["error" => "missing_id", "message" => __("Article ID is missing.")]);
            return;
        }
        
        _debug("tldrplugin: autoTagArticle called for article ID: $article_id");

        // Manual tagging works regardless of global setting
        // Use the proper tt-rss database access method
        $pdo = Db::pdo();

        $sth = $pdo->prepare("SELECT content, title, feed_id FROM ttrss_entries te 
                             JOIN ttrss_user_entries tue ON te.id = tue.ref_id 
                             WHERE te.id = ? AND tue.owner_uid = ?");
        $sth->execute([$article_id, $_SESSION['uid']]); // Ensure user owns the article

        $article_row = $sth->fetch();

        if (!$article_row) {
            _debug("tldrplugin: Article not found or access denied for ID: $article_id");
            print json_encode(["error" => "article_not_found", "message" => __("Article not found or access denied.")]);
            return;
        }

        _debug("tldrplugin: Found article: " . substr($article_row["title"], 0, 50) . "...");

        // Check minimum article length
        $content_for_length_check = trim(strip_tags($article_row["content"]));
        $actual_content_length = mb_strlen($content_for_length_check);
        $autotag_min_article_length = (int)$this->host->get($this, "autotag_min_article_length", 50);

        if ($autotag_min_article_length > 0 && $actual_content_length < $autotag_min_article_length) {
            _debug("tldrplugin: Article content length " . $actual_content_length . " is less than minimum " . $autotag_min_article_length . ". Not generating tags for article ID: " . $article_id);
            print json_encode([
                "error" => "article_too_short",
                "message" => __("Article content is too short for auto-tagging (min: %d chars, found: %d chars).", $autotag_min_article_length, $actual_content_length)
            ]);
            return;
        }

        // Generate labels and tags using OpenAI
        $suggested_data = $this->get_labels_and_tags_from_openai($article_row["content"], $article_row["title"], $_SESSION['uid']);
        $suggested_labels = $suggested_data['labels'] ?? [];
        $suggested_tags = $suggested_data['tags'] ?? [];

        if (empty($suggested_labels) && empty($suggested_tags)) {
            _debug("tldrplugin: Failed to get labels/tags or no labels/tags suggested for article ID: " . $article_id . " (manual trigger)");
            print json_encode([
                "error" => "tag_generation_failed",
                "message" => __("Failed to generate labels and tags. Check plugin logs for details.")
            ]);
            return;
        }

        // Create labels and apply them to the article
        $applied_labels = [];
        foreach ($suggested_labels as $label_caption) {
            // Get or create the label and get its actual ID
            $label_data = $this->get_or_create_label($label_caption, $_SESSION['uid']);
            if ($label_data) {
                // Get the actual label ID from the database
                $sth_get_id = $pdo->prepare("SELECT id FROM ttrss_labels2 WHERE caption = ? AND owner_uid = ?");
                $sth_get_id->execute([$label_caption, $_SESSION['uid']]);
                $label_row = $sth_get_id->fetch();
                
                if ($label_row) {
                    $label_id = $label_row['id'];
                    
                    // Check if label is already applied to avoid duplicates
                    $sth_check = $pdo->prepare("SELECT COUNT(*) FROM ttrss_user_labels2 WHERE label_id = ? AND article_id = ?");
                    $sth_check->execute([$label_id, $article_id]);
                    $exists = $sth_check->fetchColumn();
                    
                    if (!$exists) {
                        // Apply the label to the article
                        $sth_label = $pdo->prepare("INSERT INTO ttrss_user_labels2 (label_id, article_id) VALUES (?, ?)");
                        $sth_label->execute([$label_id, $article_id]);
                        
                        $applied_labels[] = $label_caption;
                        _debug("tldrplugin: Applied label '$label_caption' to article ID: $article_id");
                    } else {
                        _debug("tldrplugin: Label '$label_caption' was already applied to article ID: $article_id");
                        $applied_labels[] = $label_caption; // Still count it as applied
                    }
                }
            } else {
                _debug("tldrplugin: Failed to create or get label for: $label_caption");
            }
        }

        // Create and apply tags
        $applied_tags = [];
        if (!empty($suggested_tags)) {
            $success = $this->create_tags_for_article($article_id, $suggested_tags, $_SESSION['uid']);
            if ($success) {
                $applied_tags = $suggested_tags;
                _debug("tldrplugin: Applied tags to article ID $article_id: " . implode(", ", $applied_tags));
            } else {
                _debug("tldrplugin: Failed to apply tags to article ID: $article_id");
            }
        }

        if (!empty($applied_labels) || !empty($applied_tags)) {
            $response_parts = [];
            if (!empty($applied_labels)) {
                $response_parts[] = sprintf(__("%d label(s): %s"), count($applied_labels), implode(", ", $applied_labels));
            }
            if (!empty($applied_tags)) {
                $response_parts[] = sprintf(__("%d tag(s): %s"), count($applied_tags), implode(", ", $applied_tags));
            }
            
            $message = __("Successfully applied") . " " . implode(" and ", $response_parts);
            _debug("tldrplugin: Successfully applied labels and tags to article ID $article_id");
            print json_encode([
                "success" => true,
                "message" => $message
            ]);
        } else {
            print json_encode([
                "error" => "no_tags_applied",
                "message" => __("No labels or tags could be applied to the article.")
            ]);
        }
    }

    /**
     * Handles AJAX request to test the OpenAI API connection with current settings.
     * @return void Outputs JSON response.
     */
    public function testApiConnection() 
    {
        header('Content-Type: application/json');
        
        $api_key = $this->host->get($this, "openai_api_key");
        $base_url = $this->host->get($this, "openai_base_url", self::DEFAULT_API_BASE_URL);
        $model = $this->host->get($this, "openai_model", self::DEFAULT_MODEL);
        $curl_timeout = (int)$this->host->get($this, "curl_timeout", 30);
        $curl_connect_timeout = (int)$this->host->get($this, "curl_connect_timeout", 15);

        $data = [
            "model" => $model,
            "messages" => [
                ["role" => "user", "content" => "Hello, this is a test. Please respond with 'API connection successful'."]
            ],
            "max_tokens" => 20
        ];

        $response = $this->callOpenAI($data, $api_key, $base_url, $curl_timeout, $curl_connect_timeout);

        if (!$response) {
            print json_encode(["error" => "API connection failed"]);
            return;
        }

        print json_encode([
            "success" => "API connection successful", 
            "response" => $response['choices'][0]['message']['content']
        ]);
    }
    
    // ===========================================
    // Utility Methods
    // ===========================================

    
    /**
     * Truncates text based on specified rules: either by keeping start/end parts or by a fallback max length.
     * @param string $text The text to truncate.
     * @param int $trigger_length If text is longer than this, advanced truncation (start/end) applies. 0 to disable.
     * @param int $keep_start Number of characters to keep from the start for advanced truncation.
     * @param int $keep_end Number of characters to keep from the end for advanced truncation.
     * @param int $fallback_max_length Fallback maximum length if advanced truncation is not active/triggered.
     * @return string The truncated text.
     */
    private function truncate_text($text, $trigger_length, $keep_start, $keep_end, $fallback_max_length) 
    {
        $original_length = mb_strlen($text);

        if ($trigger_length > 0 && $original_length > $trigger_length) {
            // Advanced truncation: keep_start + "..." + keep_end
            if ($keep_start > 0 || $keep_end > 0) {
                $start_text = ($keep_start > 0) ? mb_substr($text, 0, $keep_start) : "";
                $end_text = ($keep_end > 0) ? mb_substr($text, $original_length - $keep_end, $keep_end) : "";

                // Ensure we don't overlap if the text is shorter than keep_start + keep_end
                if ($keep_start + $keep_end >= $original_length) {
                    return $text; // Return original text if sum of parts is too large
                }

                $separator = (!empty($start_text) && !empty($end_text)) ? "\n...\n" : "";
                return $start_text . $separator . $end_text;
            }
        }

        // Fallback to simple max length truncation if advanced is not active or not triggered
        if ($original_length > $fallback_max_length) {
            return mb_substr($text, 0, $fallback_max_length);
        }

        return $text;
    }
    
    // ===========================================
    // Auto Tagging Helper Methods
    // ===========================================

    /**
     * Retrieves all existing label captions for a given user.
     * @param int $owner_uid The user's ID.
     * @return string[] An array of label captions.
     */
    private function get_existing_labels($owner_uid) 
    {
        $pdo = Db::pdo();
        $sth = $pdo->prepare("SELECT caption FROM ttrss_labels2 WHERE owner_uid = ? ORDER BY caption");
        $sth->execute([$owner_uid]);

        $labels = array();
        while ($row = $sth->fetch()) {
            $labels[] = $row['caption'];
        }
        return $labels;
    }

    /**
     * Initializes the color palette for new labels.
     * Generates a list of visually distinct colors, avoiding very light/dark ones.
     * Ensures the palette is initialized only once.
     * @return void
     */
    private function initialize_label_colors() {
        if ($this->label_colors_initialized) return;
        // Generate colors based on the same quantization as colorPalette function in TTRSS
        for ($r = 0; $r <= 0xFF; $r += 0x33) {
            for ($g = 0; $g <= 0xFF; $g += 0x33) {
                for ($b = 0; $b <= 0xFF; $b += 0x33) {
                    // Filter out very light colors to ensure contrast with white text,
                    // and very dark colors for general visibility.
                    // This is a heuristic and might need adjustment.
                    $brightness = (($r * 299) + ($g * 587) + ($b * 114)) / 1000;
                    if ($brightness > 40 && $brightness < 200) { // Avoid too bright and too dark
                         $this->label_palette[] = sprintf('%02X%02X%02X', $r, $g, $b);
                    }
                }
            }
        }
        if (empty($this->label_palette)) { // Fallback if filter is too aggressive
            $this->label_palette[] = "007bff"; // A default nice blue
        }
        $this->label_colors_initialized = true;
    }

    /**
     * Selects a random background color from the initialized palette
     * and determines a contrasting foreground (text) color (black or white).
     * @return string[] Array containing two hex color codes: [fg_color, bg_color].
     */
    private function get_random_label_colors() {
        $this->initialize_label_colors();

        $bg_color = $this->label_palette[array_rand($this->label_palette)];

        // Determine text color (black or white) based on background brightness
        list($r, $g, $b) = sscanf($bg_color, "%02x%02x%02x");
        $brightness = (($r * 299) + ($g * 587) + ($b * 114)) / 1000;
        $fg_color = ($brightness > 125) ? '000000' : 'FFFFFF'; // Black text on light, white on dark

        return [$fg_color, $bg_color];
    }

    /**
     * Retrieves an existing label by caption for a user, or creates a new one if not found.
     * New labels are assigned random foreground/background colors.
     *
     * @param string $caption The caption of the label.
     * @param int $owner_uid The user's ID.
     * @return array|null An array representing the label [feed_id, caption, fg_color, bg_color],
     *                    or null if creation failed.
     */
    private function get_or_create_label($caption, $owner_uid) {
        $pdo = Db::pdo();
        $sth = $pdo->prepare("SELECT id, fg_color, bg_color FROM ttrss_labels2
            WHERE caption = ? AND owner_uid = ?");
        $sth->execute([$caption, $owner_uid]);

        if ($row = $sth->fetch()) {
            return array(
                Labels::label_to_feed_id($row["id"]), // This converts label_id to the format TTRSS expects for article labels
                $caption,
                $row["fg_color"],
                $row["bg_color"]
            );
        }

        list($fg_color, $bg_color) = $this->get_random_label_colors();

        $sth = $pdo->prepare("INSERT INTO ttrss_labels2
            (owner_uid, caption, fg_color, bg_color)
            VALUES (?, ?, ?, ?)");

        try {
            $sth->execute([$owner_uid, $caption, $fg_color, $bg_color]);
            $label_id = $pdo->lastInsertId();

            return array(
                Labels::label_to_feed_id($label_id),
                $caption,
                $fg_color,
                $bg_color
            );
        } catch (PDOException $e) {
            // Handle potential duplicate caption race condition or other DB errors
            _debug("tldrplugin: Error creating label '$caption': " . $e->getMessage());
            // Try fetching again in case it was created by a concurrent process
            $sth_retry = $pdo->prepare("SELECT id, fg_color, bg_color FROM ttrss_labels2 WHERE caption = ? AND owner_uid = ?");
            $sth_retry->execute([$caption, $owner_uid]);
            if ($row_retry = $sth_retry->fetch()) {
                 return array(
                    Labels::label_to_feed_id($row_retry["id"]),
                    $caption,
                    $row_retry["fg_color"],
                    $row_retry["bg_color"]
                );
            }
            return null; // Failed to create or find label
        }
    }

    /**
     * Calls the OpenAI API to generate both labels and tags for the given article content.
     * Uses configured settings for API key, model, language, max tags, and truncation.
     * Includes existing user labels in the prompt for context.
     *
     * @param string $article_content The raw article content (HTML or plain text).
     * @param string $article_title The title of the article.
     * @param int $owner_uid The user's ID.
     * @return array An array with 'labels' and 'tags' keys, each containing arrays of strings, or empty arrays on failure.
     */
    private function get_labels_and_tags_from_openai($article_content, $article_title, $owner_uid) {
        $api_key = $this->host->get($this, "openai_api_key"); // Reuse TLDR API key
        $base_url = $this->host->get($this, "openai_base_url", "https://api.openai.com/v1"); // Reuse TLDR base URL
        $tag_model = $this->host->get($this, "autotag_openai_model", "gpt-3.5-turbo");
        $label_language = $this->host->get($this, "autotag_label_language", "English");
        $max_tags = (int)$this->host->get($this, "autotag_max_tags", 5);
        $curl_timeout = (int)$this->host->get($this, "curl_timeout", 60);
        $curl_connect_timeout = (int)$this->host->get($this, "curl_connect_timeout", 30);

        _debug("tldrplugin: AutoTag: Starting tag generation. Model: $tag_model, Lang: $label_language, MaxTags: $max_tags");

        $text_content_stripped = strip_tags($article_content);
        $text_content_stripped = trim($text_content_stripped);

        // Get AutoTag truncation settings
        $autotag_fallback_max_chars = (int)$this->host->get($this, "autotag_fallback_max_chars", 10000);
        $autotag_truncate_trigger_length = (int)$this->host->get($this, "autotag_truncate_trigger_length", 1000);
        $autotag_truncate_keep_start = (int)$this->host->get($this, "autotag_truncate_keep_start", 800);
        $autotag_truncate_keep_end = (int)$this->host->get($this, "autotag_truncate_keep_end", 200);

        $text_for_prompt = $this->truncate_text(
            $text_content_stripped,
            $autotag_truncate_trigger_length,
            $autotag_truncate_keep_start,
            $autotag_truncate_keep_end,
            $autotag_fallback_max_chars
        );
        _debug("tldrplugin: AutoTag content length after potential truncation: " . mb_strlen($text_for_prompt));

        $existing_labels = $this->get_existing_labels($owner_uid);
        $existing_labels_json = json_encode($existing_labels, JSON_UNESCAPED_UNICODE);

        $system_prompt = "You are an expert at analyzing text and suggesting relevant labels and tags for articles in a news aggregator. Your goal is to provide concise and accurate categorization.";
        $user_prompt = "Analyze the following article content (and title, if provided) and suggest both labels and tags. The suggestions should be in $label_language.\n";
        $user_prompt .= "Here is a list of existing labels in the system. Prioritize using these if they are highly relevant, but also suggest new labels if appropriate: $existing_labels_json\n";
        if (!empty($article_title)) {
            $user_prompt .= "Article Title: \"" . htmlspecialchars($article_title) . "\"\n";
        }
        $user_prompt .= "Article Content:\n\"" . $text_for_prompt . "\"\n\n"; // Use the truncated text
        $user_prompt .= "Respond with a JSON object containing two keys:\n";
        $user_prompt .= "1. \"labels\" - an array of up to $max_tags colored labels (broad categories, topics, themes)\n";
        $user_prompt .= "2. \"tags\" - an array of up to $max_tags specific tags (keywords, entities, specific topics)\n";
        $user_prompt .= "Labels should be more general categorizations, while tags should be more specific to the article content. ";
        $user_prompt .= "If no suitable labels or tags are found, return empty arrays. Do not include explanations or apologies in your response, only the JSON object.";

        $headers = [
            "Authorization: Bearer " . $api_key,
            "Content-Type: application/json"
        ];
        $data = [
            "model" => $tag_model,
            "messages" => [
                ["role" => "system", "content" => $system_prompt],
                ["role" => "user", "content" => $user_prompt]
            ],
            "response_format" => ["type" => "json_object"],
            "temperature" => 0.3, // Lower temperature for more deterministic tags
            "max_tokens" => $max_tags * 10 + 50 // Estimate tokens for tags + JSON overhead
        ];

        _debug("tldrplugin: AutoTag: Making API request to: " . rtrim($base_url, '/') . "/chat/completions. Prompt text (first 200 chars): ".substr($user_prompt,0,200)." Existing labels (first 100): ".substr($existing_labels_json,0,100));

        $ch = curl_init(rtrim($base_url, '/') . "/chat/completions");
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, $curl_timeout);
        curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, $curl_connect_timeout);

        $response_body = curl_exec($ch);
        $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curl_error = curl_error($ch);
        curl_close($ch);

        _debug("tldrplugin: AutoTag: API response HTTP code: $http_code. Body (first 200): ".substr($response_body,0,200));

        if ($curl_error) {
            _debug("tldrplugin: AutoTag: cURL error: $curl_error");
            return [];
        }
        if ($http_code !== 200) {
            _debug("tldrplugin: AutoTag: API error. HTTP $http_code. Body: $response_body");
            return [];
        }

        $response_data = json_decode($response_body, true);
        if (json_last_error() !== JSON_ERROR_NONE || !isset($response_data['choices'][0]['message']['content'])) {
            _debug("tldrplugin: AutoTag: Failed to parse OpenAI JSON response or expected content missing. Error: " . json_last_error_msg() . " Body: " . $response_body);
            return [];
        }

        $message_content_json = $response_data['choices'][0]['message']['content'];
        $response_data_parsed = json_decode($message_content_json, true);

        if (json_last_error() !== JSON_ERROR_NONE || !isset($response_data_parsed['labels']) || !isset($response_data_parsed['tags'])) {
             _debug("tldrplugin: AutoTag: Failed to parse labels/tags JSON from message content or keys missing/invalid. Content: " . $message_content_json);
            // Attempt to gracefully handle if the response is just a list of tags not in the expected JSON structure as a fallback
            $potential_tags = array_map('trim', explode(',', $message_content_json));
            $filtered_tags = array_filter($potential_tags, function($tag) { return !empty($tag); });
            if (!empty($filtered_tags) && count($filtered_tags) <= $max_tags * 2) { // Heuristic: if it looks like a list of tags
                 _debug("tldrplugin: AutoTag: Attempting fallback parsing of tags from: " . $message_content_json);
                 return ['labels' => array_slice($filtered_tags, 0, $max_tags), 'tags' => []];
            }
            return ['labels' => [], 'tags' => []];
        }

        // Sanitize and limit labels
        $final_labels = [];
        if (is_array($response_data_parsed['labels'])) {
            foreach ($response_data_parsed['labels'] as $label) {
                if (is_string($label) && !empty(trim($label))) {
                    $final_labels[] = trim($label);
                }
            }
        }

        // Sanitize and limit tags
        $final_tags = [];
        if (is_array($response_data_parsed['tags'])) {
            foreach ($response_data_parsed['tags'] as $tag) {
                if (is_string($tag) && !empty(trim($tag))) {
                    $final_tags[] = trim($tag);
                }
            }
        }

        _debug("tldrplugin: AutoTag: Successfully extracted labels: " . implode(", ", array_slice($final_labels, 0, $max_tags)));
        _debug("tldrplugin: AutoTag: Successfully extracted tags: " . implode(", ", array_slice($final_tags, 0, $max_tags)));
        return [
            'labels' => array_slice($final_labels, 0, $max_tags),
            'tags' => array_slice($final_tags, 0, $max_tags)
        ];
    }

    /**
     * Creates tags for an article in the TT-RSS system.
     * Uses the same method as the TT-RSS Article class for tag management.
     *
     * @param int $article_id The article ID.
     * @param array $tags Array of tag names to apply.
     * @param int $owner_uid The user's ID.
     * @return bool True on success, false on failure.
     */
    private function create_tags_for_article($article_id, $tags, $owner_uid) {
        if (empty($tags)) {
            return true;
        }

        $pdo = Db::pdo();
        
        // Get the internal article ID
        $sth = $pdo->prepare("SELECT int_id FROM ttrss_user_entries WHERE ref_id = ? AND owner_uid = ?");
        $sth->execute([$article_id, $owner_uid]);
        $row = $sth->fetch();
        
        if (!$row) {
            _debug("tldrplugin: Could not find internal article ID for article $article_id");
            return false;
        }
        
        $int_id = $row['int_id'];
        
        // Normalize tags (same as TT-RSS does)
        $normalized_tags = [];
        foreach ($tags as $tag) {
            $tag = trim($tag);
            if (!empty($tag)) {
                $normalized_tags[] = $tag;
            }
        }
        
        if (empty($normalized_tags)) {
            return true;
        }

        $tags_to_cache = [];
        
        // Delete existing tags for this article
        $dsth = $pdo->prepare("DELETE FROM ttrss_tags WHERE post_int_id = ? AND owner_uid = ?");
        $dsth->execute([$int_id, $owner_uid]);
        
        // Check if tag already exists and insert if not
        $csth = $pdo->prepare("SELECT post_int_id FROM ttrss_tags WHERE post_int_id = ? AND owner_uid = ? AND tag_name = ?");
        $usth = $pdo->prepare("INSERT INTO ttrss_tags (post_int_id, owner_uid, tag_name) VALUES (?, ?, ?)");
        
        foreach ($normalized_tags as $tag) {
            $csth->execute([$int_id, $owner_uid, $tag]);
            
            if (!$csth->fetch()) {
                $usth->execute([$int_id, $owner_uid, $tag]);
            }
            
            array_push($tags_to_cache, $tag);
        }
        
        // Update tag cache
        $tags_str = join(",", $tags_to_cache);
        $sth = $pdo->prepare("UPDATE ttrss_user_entries SET tag_cache = ? WHERE ref_id = ? AND owner_uid = ?");
        $sth->execute([$tags_str, $article_id, $owner_uid]);
        
        _debug("tldrplugin: Created tags for article $article_id: " . implode(", ", $tags_to_cache));
        return true;
    }
}