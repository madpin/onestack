<?php
declare(strict_types=1);

final class TogglableMenuExtension extends Minz_Extension {
	#[\Override]
	public function init(): void {
		$this->registerTranslates();
		$this->registerHook('js_vars', [$this, 'registerJSVars']);
		Minz_View::appendScript($this->getFileUrl('togglablemenu.js', 'js'));
		Minz_View::appendStyle($this->getFileUrl('togglablemenu.css', 'css'));
	}

	#[\Override]
	public function handleConfigureAction(): void {
		$this->registerTranslates();

		if (Minz_Request::isPost()) {
			$minWidth = Minz_Request::paramInt('togglablemenu_min_width') ?: 840;
			// TODO: Update to parent::setUserConfigurationValue() methods:
			FreshRSS_Context::userConf()->TogglableMenu = [
				'menu_display_width_threshold' => $minWidth,
			];
			FreshRSS_Context::userConf()->save();
		}
	}

	/**
	 * @param array<mixed> $vars
	 * @return array<mixed>
	 */
	public function registerJSVars(array $vars) {
		// TODO: Update to parent::getUserConfigurationValue() methods:
		$vars['togglablemenu']['menu_display_width_threshold'] = FreshRSS_Context::userConf()->TogglableMenu['menu_display_width_threshold'] ?? 840;
		return $vars;
	}
}
