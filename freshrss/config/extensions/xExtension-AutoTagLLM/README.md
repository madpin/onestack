# AutoTagLLM Extension for FreshRSS

This extension automatically adds tags to new entries using OpenAI's GPT models. It hooks into FreshRSS's `entry_before_insert` event, calls OpenAI for tag suggestions when no tags are present, and merges them with your existing tag vocabulary.

## Features
- Auto-tags new articles using OpenAI GPT-4o-mini
- Merges AI suggestions with your existing tag vocabulary
- Sanitizes content to optimize token usage
- Robust error handling and logging
- Respects rate limits with proper exception handling

## Requirements
- FreshRSS 1.24+ 
- PHP 8.1+
- Composer
- OpenAI API key

## Installation
1. Place this folder in `freshrss/config/extensions/xExtension-autotagllm`
2. Navigate to the extension directory:
   ```bash
   cd freshrss/config/extensions/xExtension-autotagllm
   ```
3. Install dependencies:
   ```bash
   composer install --no-dev --optimize-autoloader
   ```
4. Set your OpenAI API key in the environment:
   ```bash
   export OPENAI_API_KEY="sk-your-api-key-here"
   ```
   Or add it to your Docker environment variables
5. Enable the extension in FreshRSS: Configuration → Extensions → AutoTagLLM

## Usage
- Tags are automatically added to new entries that don't already have tags
- Existing tags from your vocabulary are prioritized over new AI suggestions
- The extension processes title and content, extracting 3-5 relevant tags
- Tags are formatted in lowercase with underscores (snake_case)

## Configuration
The extension uses sensible defaults but respects OpenAI rate limits:
- Model: gpt-4o-mini (cost-effective)
- Temperature: 0.2 (consistent results)
- Max tokens: 100 (sufficient for tag generation)
- Content limit: 4000 characters (avoids token limits)

## Troubleshooting
- Check FreshRSS logs for any error messages
- Ensure the OpenAI API key is properly set
- Verify Composer dependencies are installed
- Check that the extension is enabled in FreshRSS settings

## Security
- API keys are loaded from environment variables (never hardcoded)
- Content is sanitized before sending to OpenAI
- Strict JSON parsing prevents injection attacks
- Error handling prevents crashes from API failures
