# TLDR Summarizer Plugin for Tiny Tiny RSS

This plugin for [Tiny Tiny RSS (tt-rss)](https://tt-rss.org) generates a concise "Too Long; Didn't Read" (TL;DR) summary for articles using the OpenAI API and prepends it to the article content.

## Features

*   **Automatic Summaries**: Configure the plugin to automatically generate and prepend TL;DR summaries for articles from specific feeds.
*   **Manual Summaries**: Add a button to articles to manually trigger TL;DR generation.
*   **OpenAI Integration**: Uses the OpenAI API (e.g., GPT-3.5-turbo, GPT-4) to generate summaries.
*   **Configurable**: Set your OpenAI API key, base URL (optional, for proxies or alternative endpoints), and model.

## Requirements

*   A running instance of Tiny Tiny RSS.
*   PHP 7.0+ with cURL extension enabled.
*   An OpenAI API key.

## Installation

1.  Clone this repository or download the files into a new directory (e.g., `tldr_plugin`) inside your tt-rss `plugins.local` or `plugins` directory.
    ```bash
    cd /path/to/your/tt-rss/plugins.local/
    git clone <repository_url_of_this_plugin> tldr_plugin
    ```
    (Replace `<repository_url_of_this_plugin>` with the actual URL if you host it on Git.)
    If installing manually, create a directory named `tldr_plugin` and place `init.php`, `tldr_plugin.php`, and `tldr_plugin.js` into it. (Note: The current structure only uses `tldr_plugin.php` and `tldr_plugin.js`. `init.php` from the original plan might be an error if it's not the main plugin loader for tt-rss, usually it's `init.php` or `plugin.php` per plugin directory that tt-rss looks for. Assuming the main file is `tldr_plugin.php` and it's correctly named to be loaded, or there's a loader `init.php` that includes it).
    *Self-correction: tt-rss typically expects an `init.php` in the plugin's root directory. The current plan created `tldr_plugin.php`. This will need to be named `init.php` in the plugin's directory, or an `init.php` will need to load `tldr_plugin.php`.*

    For this setup, assuming `tldr_plugin.php` should be the main file, it should be renamed to `init.php` within its own plugin directory (e.g., `tldr_summarizer/init.php`). The `tldr_plugin.js` is correctly referenced from there.

2.  Enable the "tldrplugin" in tt-rss: Go to `Preferences` -> `Plugins` and check the box next to "TLDR Summarizer (tldrplugin)".

## Configuration

1.  Go to `Preferences` -> `Feeds` -> `TLDR Summarizer Settings (tldrplugin)`.
2.  Enter your **OpenAI API Key**. This is required.
3.  Optionally, change the **OpenAI Base URL**. Defaults to `https://api.openai.com/v1`. Useful if you are using a proxy or a compatible alternative API endpoint.
4.  Optionally, change the **OpenAI Model**. Defaults to `gpt-3.5-turbo`. You can specify other models like `gpt-4` if your API key has access.
5.  Click `Save`.

**To enable automatic TL;DR generation for specific feeds:**

1.  Right-click on a feed (or go to `Actions` -> `Edit feed` when the feed is selected).
2.  In the `Edit Feed` dialog, go to the `Plugins` tab.
3.  Check the box for `Generate TL;DR summary for this feed`.
4.  Save the feed settings.

## Manual TL;DR Generation

If the plugin is active, you should see a "short_text" icon (tooltip: "Generate TL;DR") on articles in the headline view or when an article is open. Click this icon to generate a TL;DR summary for that specific article.

## Notes on Plugin Order

If you are also using a full-text extraction plugin (like the original `mercury_fulltext` or others), the TLDR Summarizer should ideally run *after* the full-text plugin to ensure it summarizes the complete content. Plugin execution order in tt-rss is often based on plugin directory names (alphabetical) or the order they were enabled. You may need to adjust plugin directory names (e.g., `01_mercury_fulltext`, `02_tldr_plugin`) if your version of tt-rss doesn't offer explicit ordering and you need to enforce a sequence.

## Troubleshooting

*   Ensure your OpenAI API key is correct and has sufficient quota.
*   Check the tt-rss system logs for any error messages from the plugin (often requires debug mode to be enabled in tt-rss config).
*   Verify that the cURL extension is enabled in your PHP installation.
*   If summaries are not appearing, ensure the plugin is enabled for the feed and that an API key is configured.

## License

This plugin is released under the [MIT License](LICENSE.md) (or specify your chosen license).
(You would need to add a `LICENSE.md` file if you specify one).
