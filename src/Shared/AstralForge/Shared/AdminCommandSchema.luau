--!nocheck
-- Shared presentation and input rules; authorization remains exclusively server-side.
local Schema={}
local fractional={GrantFlux=true,GrantCores=true,GrantStardust=true}
function Schema.describe(command,definition)
	local mode=if definition.World then "duration" elseif string.sub(command,1,5)=="Grant" then "add" elseif string.sub(command,1,3)=="Set" then "set" else "action"
	if definition.Moderation then mode=if command=="ServerBan" or command=="GlobalBan" then "moderation" else "action" end
	return {Mode=mode,UsesAmount=mode~="action",Minimum=if mode=="duration" then 3 elseif mode=="set" or mode=="moderation" then 0 else 1,
		Maximum=if mode=="duration" then 20 elseif command=="GrantRelic" then 10 else 9e15,
		Integer=not fractional[command],
		Summary=if mode=="set" then "Replaces the selected value; zero is allowed." elseif mode=="add" then "Adds the amount to this player's profile." elseif mode=="duration" then "Temporary client effect. Duration is in seconds." elseif definition.Moderation then "Applies the selected moderation action to one player." elseif definition.Category=="Resets" then "Changes saved progression. Review the target before confirming." else "Runs this action once on the selected player."}
end
function Schema.canonical(raw,commands)
	if type(raw)~="string" then return nil end
	local normalized=string.lower((string.gsub(raw,"^%s*(.-)%s*$","%1")))
	for id in commands do if string.lower(id)==normalized then return id end end
	return nil
end
function Schema.validate(command,definition,raw,option)
	local rule=Schema.describe(command,definition)
	if definition.Option and (type(option)~="string" or option=="") then return nil,"Choose the required option." end
	if not rule.UsesAmount then return 1 end
	local amount=tonumber(raw)
	if amount==nil or amount~=amount or amount==math.huge or amount==-math.huge then return nil,"Amount must be a finite number." end
	if amount<rule.Minimum or amount>rule.Maximum then return nil,`Amount must be between {rule.Minimum} and {rule.Maximum}.` end
	if rule.Integer and amount~=math.floor(amount) then return nil,"This command requires a whole number." end
	return amount
end
return Schema
