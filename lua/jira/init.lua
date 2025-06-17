local curl = require("plenary.curl")
local Utils = require("jira.utils")

---@class JiraConfig
---@field domain string
---@field token string
---@field key string | string[]
---@field api_version? number
---@field format? fun(issue: table): string[]
---@field auth_type? "Basic" | "Bearer"
---@field user? string
local config = {
	domain = vim.env.JIRA_DOMAIN,
	user = vim.env.JIRA_USER,
	token = vim.env.JIRA_API_TOKEN,
	key = vim.env.JIRA_PROJECT_KEY,
	api_version = 3,
	auth_type = "Basic",
}

---@return string[]
local function get_keys()
	if type(config.key) == "string" then
		return vim.tbl_map(vim.trim, vim.split(config.key, ","))
	end
	return config.key ---@type string[]
end

---@param issue_id string
local function get_issue(issue_id)
	local headers = {
		["Content-Type"] = "application/json",
	}
	if config.auth_type == "Bearer" then
		headers["Authorization"] = "Bearer " .. config.token
	else
		headers["Authorization"] = "Basic " .. Utils.b64encode(config.user .. ":" .. config.token)
	end
	local response =
		curl.get("https://" .. config.domain .. "/rest/api/" .. config.api_version .. "/issue/" .. issue_id, {
			headers = headers,
		})
	if response.status < 400 then
		return vim.fn.json_decode(response.body)
	else
		print("Non 200 response: " .. response.status)
	end
end

---@param issue table
---@return string[]
local function format_issue(issue)
	local assignee = ""
	if issue.fields.assignee ~= vim.NIL then
		local i, j = string.find(issue.fields.assignee.displayName, "%w+")
		if i ~= nil then
			assignee = " - @" .. string.sub(issue.fields.assignee.displayName, i, j)
		end
	end

	local description_content
	if config.api_version == 3 then
		description_content = Utils.adf_to_markdown(issue.fields.description)
	else
		description_content = issue.fields.description
	end

	local content = {
		issue.fields.summary,
		"---",
		"`" .. issue.fields.status.name .. "`" .. assignee,
		"",
		description_content,
	}
	return content
end

local Jira = {}

function Jira.open_issue()
	local issue_id = Jira.parse_issue() or vim.fn.input("Issue: ")
	local url = "https://" .. config.domain .. "/browse/" .. issue_id

	if vim.ui.open then
		vim.ui.open(url)
		return
	end

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
		local format = config.format or format_issue
		local content = format(issue)
		vim.lsp.util.open_floating_preview(content, "markdown", { border = "rounded" })
	end)
end

---@return string | nil
function Jira.parse_issue()
	local current_word = vim.fn.expand("<cWORD>")
	for _, key in ipairs(get_keys()) do
		local i, j = string.find(current_word, key .. "%-%d+")
		if i ~= nil then
			return string.sub(current_word, i, j)
		end
	end
	return nil
end

---@param opts? JiraConfig
---@return JiraConfig
function Jira.setup(opts)
	opts = opts or {}
	config = vim.tbl_deep_extend("force", config, opts)

	if config.auth_type == "Basic" and (not config.user or config.user == "") then
		vim.notify(
			"The parameter `user` is required when `auth_type` is 'Basic'.",
			vim.log.levels.ERROR,
			{ title = "Jira configuration error" }
		)
	end

	vim.api.nvim_create_user_command("JiraView", Jira.view_issue, {})
	vim.api.nvim_create_user_command("JiraOpen", Jira.open_issue, {})
	return config
end

return Jira
