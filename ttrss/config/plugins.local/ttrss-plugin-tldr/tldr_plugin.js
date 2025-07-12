/* global xhr, App, Plugins, Article, Notify */

Plugins.tldrplugin = {
  summarizeArticle: function (id) {
    const contentElement = App.find(
      App.isCombinedMode()
        ? `.cdm[data-article-id="${id}"] .content-inner`
        : `.post[data-article-id="${id}"] .content`
    );

    Notify.progress("Generating TL;DR, please wait...");

    xhr.json(
      "backend.php",
      App.getPhArgs("tldrplugin", "summarizeArticle", { id: id }),
      (reply) => {
        if (contentElement && reply && reply.tldr_html) {
          // Prepend the TL;DR summary
          contentElement.innerHTML = reply.tldr_html + contentElement.innerHTML;
          Notify.info("TL;DR summary generated and prepended.");

          if (App.isCombinedMode()) Article.cdmMoveToId(id);

        } else if (reply && reply.message) { // Changed from reply.error to reply.message
          Notify.error(reply.message);
        }
        else {
          Notify.error("Unknown error occurred while generating TL;DR.");
        }
      }
    );
  },

  autoTagArticle: function (id) {
    Notify.progress("Generating auto labels and tags, please wait...");

    xhr.json(
      "backend.php",
      App.getPhArgs("tldrplugin", "autoTagArticle", { id: id }),
      (reply) => {
        if (reply && reply.success) {
          Notify.info(reply.message);
          
          // Force a comprehensive UI refresh
          try {
            // Method 1: Direct Headlines refresh - most reliable (with small delay)
            setTimeout(() => {
              if (typeof Headlines !== 'undefined' && Headlines.refresh) {
                Headlines.refresh();
              }
            }, 200);
            
            // Method 2: If the article is currently displayed, refresh it specifically
            if (typeof Article !== 'undefined' && Article.getActive && Article.getActive() == id) {
              setTimeout(() => {
                if (Article.view) {
                  Article.view(id);
                } else if (Article.refresh) {
                  Article.refresh();
                }
              }, 300);
            }
            
            // Method 3: For combined mode, move to the article to refresh its display
            if (App.isCombinedMode() && typeof Article !== 'undefined' && Article.cdmMoveToId) {
              setTimeout(() => {
                Article.cdmMoveToId(id);
              }, 400);
            }
            
            // Method 4: Force refresh of the article row and its metadata
            setTimeout(() => {
              const articleRow = document.querySelector(`[data-article-id="${id}"]`);
              if (articleRow) {
                // Visual feedback
                articleRow.style.transition = 'background-color 0.5s ease';
                articleRow.style.backgroundColor = '#e8f5e8';
                setTimeout(() => {
                  articleRow.style.backgroundColor = '';
                }, 1500);
                
                // Try to refresh any tag/label containers
                const tagContainers = articleRow.querySelectorAll('.tags, .labels, .hlTagContainer, .cdmHeader');
                tagContainers.forEach(container => {
                  if (container && container.style) {
                    container.style.opacity = '0.5';
                    setTimeout(() => {
                      container.style.opacity = '1';
                    }, 300);
                  }
                });
              }
            }, 500);
            
            // Method 5: Try to refresh the current feed if available
            if (typeof Feeds !== 'undefined' && Feeds.reloadCurrent) {
              setTimeout(() => {
                Feeds.reloadCurrent();
              }, 1000);
            }
            
          } catch (e) {
            console.warn("tldrplugin: Error refreshing UI:", e);
            // Fallback notification
            setTimeout(() => {
              Notify.info("Labels and tags applied successfully! Please refresh the page if you don't see the changes.");
            }, 2000);
          }
        } else if (reply && reply.message) {
          Notify.error(reply.message);
        } else {
          Notify.error("Unknown error occurred while generating auto labels and tags.");
        }
      }
    );
  },
};