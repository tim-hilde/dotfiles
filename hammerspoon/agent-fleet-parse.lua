-- Pure TSV parsing / sorting / diffing for the agent-fleet menubar module.
-- No hs.* calls, so it's runnable and testable with the plain `lua` CLI
-- (mirrors the tmux-status.js / tmux-status-state.js split: IO-performing
-- glue vs. pure, tested logic).

local M = {}

M.STATE_ORDER = { waiting = 1, working = 2, done = 3 }

-- Split one TSV line into a record. Field order matches agent-fleet-list.sh:
-- state, pane_id, target, session, project, title, updated_at.
local function parseLine(line)
	local fields = {}
	for field in (line .. "\t"):gmatch("(.-)\t") do
		table.insert(fields, field)
	end
	if #fields < 7 then
		return nil
	end
	return {
		state = fields[1],
		pane = fields[2],
		target = fields[3],
		session = fields[4],
		project = fields[5],
		title = fields[6],
		updatedAt = tonumber(fields[7]) or 0,
	}
end

function M.parseRecords(output)
	local records = {}
	for line in output:gmatch("[^\n]+") do
		local record = parseLine(line)
		if record then
			table.insert(records, record)
		end
	end
	return records
end

-- Extract the window index from a "session:window.pane" target string.
function M.windowOf(record)
	return record.target:match(":(%d+)%.")
end

function M.sortRecords(records)
	table.sort(records, function(a, b)
		local oa = M.STATE_ORDER[a.state] or 9
		local ob = M.STATE_ORDER[b.state] or 9
		if oa ~= ob then
			return oa < ob
		end
		return a.updatedAt > b.updatedAt
	end)
	return records
end

function M.countByState(records)
	local counts = { working = 0, waiting = 0, done = 0 }
	for _, record in ipairs(records) do
		if counts[record.state] ~= nil then
			counts[record.state] = counts[record.state] + 1
		end
	end
	return counts
end

-- Diff the previous pane->state map against the current record list.
-- Returns transitions to "waiting" or "done" (for notifications) plus the
-- new pane->state map (for the caller to store for the next diff). A pane
-- with no prior entry is first-seen, not a transition.
function M.diffTransitions(prevByPane, records)
	local currentByPane = {}
	for _, record in ipairs(records) do
		currentByPane[record.pane] = record.state
	end
	local transitions = {}
	for _, record in ipairs(records) do
		local prev = prevByPane[record.pane]
		if prev and prev ~= record.state and (record.state == "waiting" or record.state == "done") then
			table.insert(transitions, { record = record, kind = record.state })
		end
	end
	return transitions, currentByPane
end

return M
