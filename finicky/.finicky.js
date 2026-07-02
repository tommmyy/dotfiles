module.exports = {
	defaultBrowser: "Google Chrome",

	handlers: [
		// {
		//   match: finicky.matchHostnames(["*.slack.com", "slack.com"]),
		//   browser: {
		//     name: "Google Chrome",
		//     profile: "Profile 3",
		//   },
		// },
		// {
		//   match: ({ url }) => url.protocol === "slack",
		//   browser: {
		//     name: "Google Chrome",
		//     profile: "Profile 3",
		//   },
		// },
		{
			match: finicky.matchHostnames(["*.linear.app", "linear.app"]),
			browser: {
				name: "Google Chrome",
				profile: "Profile 3",
			},
		},
	],
};
