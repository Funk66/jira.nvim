local curl = require("plenary.curl")
local Utils = require("jira.utils")

---@class JiraConfig
local config = {
	domain = vim.env.JIRA_DOMAIN,
	user = vim.env.JIRA_USER,
	token = vim.env.JIRA_API_TOKEN,
	key = vim.env.JIRA_PROJECT_KEY or "PM",
}

---@param issue_id string
local function get_issue(issue_id)
	local response = curl.get("https://" .. config.domain .. "/rest/api/3/issue/" .. issue_id, {
		headers = {
			["Content-Type"] = "application/json",
			["Authorization"] = "Basic " .. Utils.b64encode(config.user .. ":" .. config.token),
		},
	})
	if response.status < 400 then
		return vim.fn.json_decode(response.body)
	else
		print("Non 200 response: " .. response.status)
	end
end

local Jira = {}

function Jira.open_issue()
	local issue_id = Jira.parse_issue() or vim.fn.input("Issue: ")
	local url = "https://" .. config.domain .. "/browse/" .. issue_id
	local os_name = vim.loop.os_uname().sysname
	local is_windows = vim.loop.os_uname().version:match("Windows")

	if os_name == "Darwin" then
		os.execute("open " .. url)
	elseif os_name == "Linux" then
		os.execute("xdg-open " .. url)
	elseif is_windows then
		os.execute("start " .. url)
	end
end

function Jira.view_issue()
	local issue_id = Jira.parse_issue() or vim.fn.input("Issue: ")
	local issue = get_issue(issue_id)
	vim.schedule(function()
		if issue == nil then
			print("Invalid response")
			return
		end
		local assignee = ""
		if issue.fields.assignee ~= vim.NIL then
			local i, j = string.find(issue.fields.assignee.displayName, "%w+")
			if i ~= nil then
				assignee = " - @" .. string.sub(issue.fields.assignee.displayName, i, j)
			end
		end
		local content = {
			issue.fields.summary,
			"---",
			"`" .. issue.fields.status.name .. "`" .. assignee,
			"",
			Utils.adf_to_markdown(issue.fields.description),
		}
		vim.lsp.util.open_floating_preview(content, "markdown", { border = "rounded" })
	end)
end

---@return string | nil
function Jira.parse_issue()
	local current_word = vim.fn.expand("<cWORD>")
	local i, j = string.find(current_word, config.key .. "%-%d+")
	if i == nil then
		return nil
	end

	return string.sub(current_word, i, j)
end

---@param opts? JiraConfig
---@return JiraConfig
function Jira.setup(opts)
	opts = opts or {}
	config = vim.tbl_deep_extend("force", config, opts)
	vim.api.nvim_create_user_command("JiraView", Jira.view_issue, {})
	vim.api.nvim_create_user_command("JiraOpen", Jira.open_issue, {})
	return config
end

return Jira
