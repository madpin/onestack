<?php
class ArticleSummaryExtension extends Minz_Extension
{


  protected array $csp_policies = [
    'default-src' => '*',
  ];

  public function init()
  {
    $this->registerHook('entry_before_display', array($this, 'addSummaryButton'));
    $this->registerController('ArticleSummary');
    Minz_View::appendStyle($this->getFileUrl('style.css', 'css'));
    Minz_View::appendScript($this->getFileUrl('axios.js', 'js'));
    Minz_View::appendScript($this->getFileUrl('marked.js', 'js'));
    Minz_View::appendScript($this->getFileUrl('script.js', 'js'));
  }

  public function addSummaryButton($entry)
  {
    $url_summary = Minz_Url::display(array(
      'c' => 'ArticleSummary',
      'a' => 'summarize',
      'params' => array(
        'id' => $entry->id()
      )
    ));

    $entry->_content(
      '<div class="oai-summary-wrap">'
      . '<button data-request="' . $url_summary . '" class="oai-summary-btn"></button>'
      . '<div class="oai-summary-content"></div>'
      . '</div>'
      . $entry->content()
    );
    return $entry;
  }

  public function handleConfigureAction()
  {
    if (Minz_Request::isPost()) {
      FreshRSS_Context::$user_conf->oai_url = Minz_Request::param('oai_url', '');
      FreshRSS_Context::$user_conf->oai_key = Minz_Request::param('oai_key', '');
      FreshRSS_Context::$user_conf->oai_model = Minz_Request::param('oai_model', '');
      FreshRSS_Context::$user_conf->oai_prompt = Minz_Request::param('oai_prompt', '');
      FreshRSS_Context::$user_conf->oai_provider = Minz_Request::param('oai_provider', '');
      FreshRSS_Context::$user_conf->save();
    }
  }
}
