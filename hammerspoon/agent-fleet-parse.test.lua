local parse = require("agent-fleet-parse")

local PASS, FAIL = 0, 0

local function check(name, actual, expected)
	if actual == expected then
		print("ok - " .. name)
		PASS = PASS + 1
	else
		print("FAIL - " .. name)
		print("  expected: " .. tostring(expected))
		print("  actual:   " .. tostring(actual))
		FAIL = FAIL + 1
	end
end

-- parseLine (via parseRecords, one line)
local line = "working\t%101\tdotfiles:1.1\tdotfiles\tdotfiles\tFix login bug\t1700000000"
local records = parse.parseRecords(line)
check("parseRecords single line count", #records, 1)
local record = records[1]
check("parseLine state", record.state, "working")
check("parseLine pane", record.pane, "%101")
check("parseLine target", record.target, "dotfiles:1.1")
check("parseLine session", record.session, "dotfiles")
check("parseLine project", record.project, "dotfiles")
check("parseLine title", record.title, "Fix login bug")
check("parseLine updatedAt", record.updatedAt, 1700000000)

check("parseRecords rejects short line", #parse.parseRecords("working\t%101"), 0)

-- parseRecords with multiple lines
local output = "working\t%101\tdotfiles:1.1\tdotfiles\tdotfiles\tFirst\t1\n"
	.. "waiting\t%102\tmerlin:2.1\tmerlin\tmerlin\tSecond\t2\n"
local multi = parse.parseRecords(output)
check("parseRecords count", #multi, 2)
check("parseRecords first title", multi[1].title, "First")
check("parseRecords second title", multi[2].title, "Second")

-- windowOf
check("windowOf extracts window index", parse.windowOf({ target = "dotfiles:3.1" }), "3")

-- sortRecords: waiting before working before done; recency desc within group
local mixed = {
	{ state = "done", updatedAt = 5, title = "d" },
	{ state = "waiting", updatedAt = 1, title = "w1" },
	{ state = "working", updatedAt = 3, title = "wk" },
	{ state = "waiting", updatedAt = 9, title = "w2" },
}
local sorted = parse.sortRecords(mixed)
check("sort: waiting first (newest)", sorted[1].title, "w2")
check("sort: waiting second (oldest)", sorted[2].title, "w1")
check("sort: working third", sorted[3].title, "wk")
check("sort: done last", sorted[4].title, "d")

-- countByState
local counts = parse.countByState({
	{ state = "working" },
	{ state = "working" },
	{ state = "waiting" },
	{ state = "done" },
})
check("countByState working", counts.working, 2)
check("countByState waiting", counts.waiting, 1)
check("countByState done", counts.done, 1)

-- diffTransitions
local prevByPane = { ["%101"] = "working", ["%102"] = "waiting" }
local newRecords = {
	{ pane = "%101", state = "done", title = "finished" },
	{ pane = "%102", state = "waiting", title = "still waiting" }, -- no change
	{ pane = "%103", state = "working", title = "new agent" }, -- first-seen, no transition
}
local transitions, currentByPane = parse.diffTransitions(prevByPane, newRecords)
check("diffTransitions count", #transitions, 1)
check("diffTransitions kind", transitions[1].kind, "done")
check("diffTransitions record title", transitions[1].record.title, "finished")
check("diffTransitions tracks new pane", currentByPane["%103"], "working")

print()
print("PASS=" .. PASS .. " FAIL=" .. FAIL)
os.exit(FAIL == 0 and 0 or 1)
