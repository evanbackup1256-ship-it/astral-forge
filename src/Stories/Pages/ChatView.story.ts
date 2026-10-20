import StoryKit = require("../StoryKit");

export = StoryKit.page("PagesSocial", "ChatView", "Chat.", {
	chat: {
		messages: [],
		connected: false,
		unread: 0,
		send: (_: unknown, done?: (ok: boolean, message: string) => void) => {
			if (done) {
				done(false, "Preview does not send messages.");
			}
		},
		clear: () => {},
	},
});
