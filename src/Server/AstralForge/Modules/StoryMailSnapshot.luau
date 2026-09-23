--!strict
-- Pure Story/Mail snapshot builders peeled from ServerServices (wave44).

local StoryMailSnapshot = {}

function StoryMailSnapshot.BuildStory(profile, storyChapters, ProgressionGate)
	local storyState = {}
	for index, chapter in storyChapters do
		storyState[index] = {
			Id = chapter.Id,
			Unlocked = ProgressionGate.Progress(profile, chapter.Kind) >= chapter.Target,
			Progress = ProgressionGate.Progress(profile, chapter.Kind),
			Target = chapter.Target,
			Read = profile.Story.Read[chapter.Id] == true,
			Claimed = profile.Story.Claimed[chapter.Id] == true,
		}
	end
	return storyState
end

function StoryMailSnapshot.BuildMailbox(profile, mailMessages, ProgressionGate)
	local mailState = {}
	local unreadMail = 0
	for _, message in mailMessages do
		if not profile.Mailbox.Deleted[message.Id] and ProgressionGate.Meets(profile, message.Requirement) then
			local read = profile.Mailbox.Read[message.Id] == true
			if not read then
				unreadMail += 1
			end
			table.insert(mailState, {
				Id = message.Id,
				Read = read,
				Claimed = profile.Mailbox.Claimed[message.Id] == true,
			})
		end
	end
	return mailState, unreadMail
end

-- Client Mailbox rail bag (wave49).
function StoryMailSnapshot.MailboxPublic(messages, unread: number)
	return {
		Messages = messages,
		Unread = unread,
	}
end

return StoryMailSnapshot
