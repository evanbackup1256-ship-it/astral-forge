--!strict
-- Pure visitor roster builder peeled from ServerServices (wave45).

local VisitorList = {}

function VisitorList.Build(bucket, isPresent)
	local list = {}
	if not bucket then
		return list
	end
	for visitor in bucket do
		if isPresent(visitor) then
			table.insert(list, {
				UserId = visitor.UserId,
				Name = visitor.Name,
				DisplayName = visitor.DisplayName,
			})
		end
	end
	table.sort(list, function(left, right)
		return left.DisplayName < right.DisplayName
	end)
	return list
end

return VisitorList
