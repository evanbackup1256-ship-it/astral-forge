local StoryKit = require(script.Parent.Parent.StoryKit)

return StoryKit.page("PagesSocial", "ChatView", "Chat.", {
	chat = {
		messages = {},
		connected = false,
		unread = 0,
		send = function(_, done)
			if done then
				done(false, "Preview does not send messages.")
			end
		end,
		clear = function() end,
	},
})
