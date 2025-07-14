(function()
{
	const OPEN_MENU_HASH = "#aside_feed";
	const CLOSED_MENU_HASH = "#";

	const computeMenuVisibilityFromWindow = () =>
	{
		let minWidth = 840;
		if (
			window.context &&
			window.context.extensions &&
			window.context.extensions.togglablemenu &&
			typeof(window.context.extensions.togglablemenu['menu_display_width_threshold']) === "number"
		)
		{
			minWidth = window.context.extensions.togglablemenu['menu_display_width_threshold'];
		}

		return window.innerWidth > minWidth;
	};

	const updateButton = (event) =>
	{		
		const hash = window.location.hash;
		if (hash === "#close" && event.type === "hashchange")
		{
			// Are we closing a dropdown? In that case, the menu was already open, keep it that way
			const previousUrl = new URL(event.oldURL);
			if (previousUrl.hash.startsWith("#dropdown-"))
			{
				window.location.replace(OPEN_MENU_HASH);
				return;
			}
		}		

		const button = document.querySelector(".nav_menu .toggle_aside");
		let isMenuShown = hash === OPEN_MENU_HASH;		

		if (isMenuShown)
		{
			button.setAttribute("href", CLOSED_MENU_HASH);
		}
		else
		{
			button.setAttribute("href", OPEN_MENU_HASH);
		}
	};

	window.addEventListener("hashchange", updateButton);
	window.addEventListener("load", updateButton);

	if (computeMenuVisibilityFromWindow())
	{
		window.location.replace(OPEN_MENU_HASH);
	}
	else if (window.location.hash  === OPEN_MENU_HASH)
	{
		window.location.replace(CLOSED_MENU_HASH);
	}
}());
