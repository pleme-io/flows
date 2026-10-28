use("moji", [:after_first, :before_first, :includes, :starts_with, :trim])
use("retsu", [:contains, :first, :is_empty, :rest])
use("shisutemu", [:status_of, :stdout_of])

OLD = "pleme-io/substrate/.github/workflows/"
NEW = "pleme-io/flows/.github/workflows/"
SELF = ["substrate", "flows"]

def call_line?(line)
  t = trim(line)
  includes(line, OLD) and (starts_with(t, "uses:") or starts_with(t, "- uses:"))
end

def target(line)
  rest_of = after_first(line, OLD)
  if includes(rest_of, "@")
    name = before_first(rest_of, "@")
    ref = first(split(trim(after_first(rest_of, "@")), " "))
    [name, replace(replace(ref, "\"", ""), "'", "")]
  else
    [trim(replace(replace(rest_of, "\"", ""), "'", "")), ""]
  end
end

def flow?(flows, name)
  p = "#{flows}/.github/workflows/#{name}"
  path_exists(p) and
    includes(read_file(p), join_lines(["", "  workflow_call:"]))
end

def repo_of(path)
  if starts_with(path, ".github/")
    ".github"
  else
    path_basename(before_first(path, "/.github/"))
  end
end

def status(flows, repo, name, ref)
  if contains(SELF, repo)
    "self"
  elsif ref == ""
    "no-ref"
  elsif flow?(flows, name)
    "ok"
  else
    "missing"
  end
end

def workflow_files(root)
  if starts_with(root, "/")
    raise(
      "root #{root} is absolute; glob finds nothing for an absolute pattern, so run from the org directory and pass a relative root such as ."
    )
  end
  p = if root == "."
    ""
  else
    "#{root}/"
  end
  append(
    glob("#{p}.github/workflows/*.yml"),
    glob("#{p}.github/workflows/*.yaml"),
    glob("#{p}*/.github/workflows/*.yml"),
    glob("#{p}*/.github/workflows/*.yaml"),
    glob("#{p}.github/workflow-templates/*.yml"),
    glob("#{p}*/.github/workflow-templates/*.yml")
  )
end

def scan_line(flows, path, repo, n, line)
  t = target(line)
  name = first(t)
  ref = first(rest(t))
  st = status(flows, repo, name, ref)
  new_line = if st == "ok"
    replace(line, OLD, NEW)
  else
    line
  end
  {row: "#{repo}\t#{path}\t#{n}\t#{name}\t#{ref}\t#{st}", line: new_line}
end

def scan_lines(flows, path, repo, lines, n, rows, out)
  if is_empty(lines)
    [reverse(rows), reverse(out)]
  else
    l = first(lines)
    if call_line?(l)
      r = scan_line(flows, path, repo, n, l)
      scan_lines(
        flows,
        path,
        repo,
        rest(lines),
        n + 1,
        cons(r.row, rows),
        cons(r.line, out)
      )
    else
      scan_lines(flows, path, repo, rest(lines), n + 1, rows, cons(l, out))
    end
  end
end

def scan_file(flows, write, path)
  old = read_file(path)
  res = scan_lines(
    flows,
    path,
    repo_of(path),
    split(old, line_break),
    1,
    [],
    []
  )
  new = join(first(rest(res)), line_break)
  if write and new != old
    write_file(path, new)
  end
  first(res)
end

def local(mode, flows, out, roots)
  write = mode == "write"
  files = reduce((acc, r) -> append(acc, workflow_files(r)), [], roots)
  rows = reduce((acc, f) -> append(acc, scan_file(flows, write, f)), [], files)
  write_file(
    out,
    concat(
      join(cons("repo\tpath\tline\tflow\tref\tstatus", rows), line_break),
      line_break
    )
  )
  ok = size_of(filter((r) -> includes(r, "\tok"), rows))
  write_stdout(
    unlines(
      [
        "#{mode}: files scanned #{size_of(files)}, references #{size_of(rows)}, rewritable #{ok}; ledger #{out}"
      ]
    )
  )
  if size_of(files) == 0
    exit_with(3)
  end
end

MESSAGE = join_lines(
  [
    "ci: call the reusable flows from pleme-io/flows",
    "",
    "Each uses: line names pleme-io/flows instead of pleme-io/substrate, at the",
    "same ref. The two trees are byte-identical (substrate-parity). Rewritten by",
    "flows tools/cutover.b."
  ]
)

def git(dir, args)
  exec_capture("git", "-C", dir, *args)
end

def git_ok(dir, args)
  status_of(git(dir, args)) == 0
end

def repo_dir(path)
  if starts_with(path, ".github/")
    "."
  else
    before_first(path, "/.github/")
  end
end

def ready(dir)
  clean = trim(stdout_of(git(dir, ["status", "--porcelain"]))) == ""
  on_main = trim(stdout_of(git(dir, ["rev-parse", "--abbrev-ref", "HEAD"]))) ==
    "main"
  if not clean
    "dirty"
  elsif not on_main
    "not-on-main"
  elsif not git_ok(dir, ["fetch", "-q", "origin"])
    "fetch-failed"
  elsif not git_ok(dir, ["merge", "--ff-only", "-q", "origin/main"])
    "not-fast-forward"
  else
    "ready"
  end
end

def push_repo(flows, dir, files)
  r = ready(dir)
  if r != "ready"
    "#{dir}\t#{r}"
  else
    rows = reduce((acc, f) -> append(acc, scan_file(flows, true, f)), [], files)
    changed = filter(
      fn(f)
        includes(
          stdout_of(
            git(dir, ["status", "--porcelain", "--", replace(f, "#{dir}/", "")])
          ),
          "M"
        )
      end,
      files
    )
    if is_empty(changed)
      "#{dir}\tnothing-to-rewrite"
    elsif not git_ok(
      dir,
      append(["add", "--"], map((f) -> replace(f, "#{dir}/", ""), changed))
    )
      "#{dir}\tadd-failed"
    elsif not git_ok(dir, ["commit", "-q", "-m", MESSAGE])
      "#{dir}\tcommit-failed"
    elsif not git_ok(dir, ["push", "-q", "origin", "main"])
      "#{dir}\tpush-failed"
    else
      "#{dir}\tpushed #{size_of(changed)} files #{size_of(filter((x) -> includes(x, "\tok"), rows))} references"
    end
  end
end

def push(flows, out, roots)
  files = reduce((acc, r) -> append(acc, workflow_files(r)), [], roots)
  calls = filter((f) -> includes(read_file(f), OLD), files)
  dirs = reduce(
    fn(acc, f)
      if contains(acc, repo_dir(f)) or contains(SELF, repo_of(f))
        acc
      else
        append(acc, [repo_dir(f)])
      end
    end,
    [],
    calls
  )
  rows = map(
    (d) -> push_repo(flows, d, filter((f) -> repo_dir(f) == d, calls)),
    dirs
  )
  write_file(
    out,
    concat(join(cons("repo\tresult", rows), line_break), line_break)
  )
  pushed = size_of(filter((r) -> includes(r, "\tpushed"), rows))
  write_stdout(
    unlines(["push: repos #{size_of(dirs)}, pushed #{pushed}; ledger #{out}"])
  )
end

def size_of(xs)
  reduce((acc, _x) -> acc + 1, 0, xs)
end

def search_page(name, page)
  r = exec_capture(
    "gh",
    "api",
    "-X",
    "GET",
    "search/code",
    "-f",
    "q=org:pleme-io \"#{OLD}#{name}\"",
    "-f",
    "per_page=100",
    "-f",
    "page=#{page}",
    "--jq",
    ".total_count as $t | .items[] | \"\\($t)\\t\\(.repository.full_name)\\t\\(.path)\""
  )
  if status_of(r) != 0
    raise("search for #{name} page #{page} failed: blind, not empty")
  end
  filter((l) -> trim(l) != "", split(stdout_of(r), line_break))
end

def search_all(name, page, acc)
  sleep(7)
  rows = search_page(name, page)
  all = append(acc, map((l) -> "#{name}\t#{l}", rows))
  if size_of(rows) == 100 and page < 10
    search_all(name, page + 1, all)
  else
    all
  end
end

def search(flows, out)
  names = map(
    (p) -> path_basename(p),
    filter(
      (p) -> flow?(flows, path_basename(p)),
      glob("#{flows}/.github/workflows/*.yml")
    )
  )
  rows = reduce((acc, n) -> append(acc, search_all(n, 1, [])), [], names)
  write_file(
    out,
    concat(join(cons("flow\ttotal\trepo\tpath", rows), line_break), line_break)
  )
  write_stdout(
    unlines(
      [
        "search: flows queried #{size_of(names)}, files found #{size_of(rows)}; ledger #{out}"
      ]
    )
  )
end

test "a substrate call is rewritten to flows when flows holds the flow"
  assert call_line?("    uses: pleme-io/substrate/.github/workflows/x.yml@main")
  assert not call_line?("# uses: pleme-io/substrate/.github/workflows/x.yml@main")
  assert target("    uses: pleme-io/substrate/.github/workflows/x.yml@v1 # pin") ==
    ["x.yml", "v1"]
  assert target("    uses: \"pleme-io/substrate/.github/workflows/x.yml@main\"") ==
    ["x.yml", "main"]
end

test "the repo of a workflow file is the directory above .github"
  assert repo_of("/a/b/kensa/.github/workflows/ci.yml") == "kensa"
end

if not is_empty(argv) and first(argv) != "test"
  mode = first(argv)
  if mode == "search"
    search(first(rest(argv)), first(rest(rest(argv))))
  elsif mode == "plan" or mode == "write"
    local(
      mode,
      first(rest(argv)),
      first(rest(rest(argv))),
      rest(rest(rest(argv)))
    )
  elsif mode == "push"
    push(first(rest(argv)), first(rest(rest(argv))), rest(rest(rest(argv))))
  else
    raise("usage: cutover.b -- plan|write|push FLOWS OUT ROOT... | search FLOWS OUT")
  end
end
