local lfs = require("lfs")            -- luarocks install luafilesystem
local socket = require("socket.http") -- luarocks install luasocket && apt install libssl-dev

local base_path = string.format('%s/myp/problem-solving', vim.loop.os_homedir())

local judgesMap = {
  codeforces = "Codeforces",
  spoj = "SPOJ",
  uva = "UVa",
  virtual = "Virtual Judge",
  timus = "Timus",
  euler = "Project Euler",
  poj = "POJ",
  meta = "Meta",
  hackerrank = "HackerRank",
  dmoj = "DMOJ",
  cses = "CSES",
  atcoder = "AtCoder"
}

local function sanitize(path)
  return path:gsub('[<>:"\\|?*#]', '_')
end

local function trim(s)
  return s:match '^%s*(.-)%s*$' or ''
end

-- Function to fetch HTML content from a URL
function fetch_html(url)
  local body, code, headers, status = socket.request(url)
  if code == 200 then
    return body
  end
end

local function find_contest_folder(our_base_path, contest_id)
  for folder in lfs.dir(our_base_path) do
    if folder:find('^' .. contest_id .. ' %-') then
      return folder
    end
  end
  return nil
end

local function relative_path(task, file_extension)
  local hyphen = string.find(task.group, ' %- ')
  local problem_name = trim(task.name)
  local judge, contest

  if not hyphen then
    judge = task.group
    contest = 'unknown_contest'
  else
    judge = trim(string.sub(task.group, 1, hyphen - 1))
    contest = trim(string.sub(task.group, hyphen + 3))
  end

  local original_judge = judge            -- Save the original judge name
  local lower_judge = string.lower(judge) -- Lowercase the judge name

  -- Check if lower_judge contains any key from judgesMap
  local found = false
  for key, value in pairs(judgesMap) do
    if string.find(lower_judge, key, 1, true) then
      judge = value
      found = true
      break
    end
  end

  if not found then
    judge = original_judge
  end

  local file_name = 'main'
  if file_extension == 'java' and task.languages and task.languages.java and task.languages.java.taskClass then
    file_name = task.languages.java.taskClass
  end

  if lower_judge == 'codeforces' then
    local contest_id = string.match(task.url, '%w+/(%d+)')
    if contest_id then
      local our_base_path = sanitize(string.format('%s/%s', base_path, judge))
      local existing_folder = find_contest_folder(our_base_path, contest_id)

      if existing_folder then
        -- some contests have problems some as PDF which results in different contest name but the same contest id
        contest = existing_folder
      else
        contest = contest_id .. ' - ' .. contest
      end
    end
  end

  if lower_judge == 'cses' and contest == 'CSES Problem Set' then
    local body = fetch_html(task.url)
    if body then
      local category = string.match(body, '<h4>(.-)</h4>')
      if category then
        contest = string.format('%s/%s', contest, category)
      end
    end
  end

  if lower_judge == "acwing" then
    problem_name = string.match(task.url, "/(%d+)")
  end

  return sanitize(string.format('%s/%s/%s/%s.%s', judge, contest, problem_name, file_name, file_extension))
end

local function full_path(...)
  return string.format('%s/%s', base_path, relative_path(...))
end

return {
  'xeluxee/competitest.nvim',
  dependencies = 'MunifTanjim/nui.nvim',
  opts = {
    -- output_compare_method = 'exact',
    compile_command = {
      c = { exec = 'gcc', args = { '-DSAWALHY', '-Wall', '$(FNAME)', '-O3', '-o', '$(FNOEXT)' } },
      cpp = { exec = 'g++', args = { '-std=c++23', '-DSAWALHY', '-Wall', '-Wextra', '-fsanitize=address', '-Wconversion', '$(FNAME)', '-o', '$(FNOEXT)' } },
      rust = { exec = 'rustc', args = { '$(FNAME)' } },
      java = { exec = 'javac', args = { '$(FNAME)' } },
      go = { exec = 'go', args = { 'build', '-o', '$(FNOEXT)', '$(FNAME)' }, },
    },

    run_command = {
      go = { exec = './$(FNOEXT)' },
      python = { exec = "python3", args = { "$(FNAME)" } },
    },

    template_file = '~/myp/problem-solving/template.$(FEXT)',
    received_files_extension = 'cpp',
    received_problems_path = full_path,
    received_contests_problems_path = relative_path,
    received_contests_directory = base_path,

    evaluate_template_modifiers = true,
    received_problems_prompt_path = false,
    received_contests_prompt_directory = false,
    received_contests_prompt_extension = false,
  },
  keys = {
    { 'cpd', ":silent ! g++ -g '%' -o '%:p:r'<CR>", desc = 'Compile cpp file with -g flag' },
    { 'cpt', ':CompetiTest receive testcases<CR>',  desc = 'Receive test cases' },
    { 'cpp', ':CompetiTest receive problem<CR>',    desc = 'Receive a problem' },
    { 'cpc', ':CompetiTest receive contest<CR>',    desc = 'Receive a contest' },
    { 'cpr', ':CompetiTest run<CR>',                desc = 'Run the current file' },
    { 'cpR', ':CompetiTest run_no_compile<CR>',     desc = 'Run the current file without compiling' },
    { 'cpe', ':CompetiTest edit_testcase<CR>',      desc = 'Edit test cases' },
    { 'cpa', ':CompetiTest add_testcase<CR>',       desc = 'Add new test case' },
  }
}
