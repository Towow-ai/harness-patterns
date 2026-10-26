# 第 4 期：规则分三档

文章：公众号“Harness 模式”第 4 期《CLAUDE.md 里写的“不要”只是提醒：规则分三档，红线别交给模型自己挑》，北京时间 11 月 6 日发出。为什么这样设计、实测里每一步看到了什么，都在文章里。下面是这一期配置的完整说明，文章附录贴了其中四份短的。

这是最小可跑版，做法见文章第三到六节，装好以后怎么故意犯一次在本文最后。一共五份。hook 和检查脚本只用 bash、git 和系统自带的命令，不用 jq。我们在 Claude Code 2.1.302 上跑通过，测的是 `claude --bg` 起的后台 Agent，路径里带中文也认；人在旁边看的交互模式没单独测，故意犯一次就是在你自己的用法下测它。后台 Agent 用的模型是 Sonnet，文章里写 Agent 怎么反应的几处，换模型可能不同。macOS 上测的，Linux 没测。

先跑一次 `claude --version`：照文档，`onFailure` 要 2.1.295 以上，更旧的先升级。装好后，故意犯一次的第 3 步能看出挡 `.env` 的规则生没生效。然后做四件事：

1. 五份放进仓库。`CLAUDE.md` 和 `.claude/settings.json` 已经有的，把里面的条目并进去，别整份替换。然后 `chmod +x .claude/hooks/append-only.sh scripts/check-tiers.sh`，`.gitignore` 加一行 `.claude/loaded.log`。
2. 迁移目录不叫 `migrations` 的，改 `append-only.sh` 里的 `PROTECT`，比如 `db/migrate`，`.claude/rules/migrations.md` 里的 `paths` 也跟着改。只许新增、不许改旧的目录不止迁移，决策记录、更新日志也合适。
3. 新建的仓库先用 `claude` 交互式打开一次，接受信任；没信任过的目录，在脚本里起后台 Agent 会直接报 `Workspace not trusted`。
4. 跑一次 `scripts/check-tiers.sh`，照它报的给规则补上标签。

**`CLAUDE.md`**：示例。每条“必须／不要”末尾标一档；硬拦冒号后面写的名字，要在 `settings.json` 里找得到。

全文见本目录 [`CLAUDE.md`](CLAUDE.md)。

**`.claude/settings.json`**：两条 deny 挡 `.env`。照文档，`Read(./.env)` 挡读它，也挡 Edit 和 Write 改它、在那里新建（整个覆盖我们测过），改文件的内置工具里，只有 NotebookEdit 它不管；`Edit(./.env)` 挡所有改文件的内置工具，补上 NotebookEdit。PreToolUse hook 在每次 Edit、Write 之前跑 `append-only.sh`，脚本坏了也拦；InstructionsLoaded 每加载一份 CLAUDE.md 或规则，就往 `.claude/loaded.log` 记一行 JSON，`load_reason` 是 `path_glob_match` 的那行，`trigger_file_path` 就是把它带进来的文件。

全文见本目录 [`.claude/settings.json`](.claude/settings.json)。

**`.claude/hooks/append-only.sh`**：PreToolUse hook。改的文件在 `PROTECT` 目录下、而且上一次提交（HEAD）里已经有，就退出 2 拦下；新建的、只 `git add` 过还没提交的放行；不在 git 仓库里、目录还不存在的也放行。`file_path` 是从 Claude Code 传来的 JSON 里用 grep 取的，路径里带双引号就取不对，取不对时放行；这种路径少见，我们没处理。

全文见本目录 [`.claude/hooks/append-only.sh`](.claude/hooks/append-only.sh)。

**`.claude/rules/migrations.md`**：按需档示例，只放写迁移的做法。不许改旧迁移那条不放这里：它只在 Claude 读写 `migrations/` 下的文件时才加载，新建文件时还晚一步。

全文见本目录 [`.claude/rules/migrations.md`](.claude/rules/migrations.md)。

**`scripts/check-tiers.sh`**：在仓库根目录跑。常驻档（`CLAUDE.md`、`CLAUDE.local.md`、`.claude/CLAUDE.md`、不带 `paths` 的规则文件）里，列表项含“必须、不要、不许、禁止”一类词或 never、always、must（不分大小写），却没标档的，报“没标档”；标了 `[硬拦: X]`、X 在 `settings.json` 里找不到的，报“硬拦没落点”；按需档（带 `paths` 的规则、Skill、子目录里的 CLAUDE.md）里写了“红线”或 `[硬拦` 的，报“红线在按需档”。报出一处就退出 1，可以挂进提交前的检查。

全文见本目录 [`scripts/check-tiers.sh`](scripts/check-tiers.sh)。

**故意犯一次**

在一个新建的小仓库里做，别在干活的仓库里：先提交一个假迁移，比如 `migrations/001_test.sql`，放一个只写假值的 `.env`，再装好五份。

1. 让 Agent 用 Edit 改 `migrations/` 下一个已经提交的文件。应该看到 `PreToolUse:Edit hook error`，后面跟着 hook 那两句话，文件没变。
2. 让它新建一个迁移，再改这个新文件：两次都放行。
3. 让它用读文件的工具读 `.env`：被权限规则挡下，提示里有 `denied by your permission settings`。
4. 在 `.claude/skills/tier-test/SKILL.md` 写一行“红线：不许跳过测试直接发版。”，跑 `scripts/check-tiers.sh`：报“红线在按需档”，退出码 1。删掉这个文件再跑，报“没有发现问题”。
5. 想看 hook 坏了会怎样：`chmod -x .claude/hooks/append-only.sh`，再做第 1 步，提示里有 `blocking because onFailure is "block"`，这时新建文件也会被拦；做完 `chmod +x` 改回来。

这五步我们都跑过，另外跑了不设 `onFailure` 的对照（坏脚本时改动照样落下）、按路径规则的三种加载情况，第 3 步还试了 Bash `cat .env` 和用写文件的工具整个覆盖，都被挡下。这个目录也没放的：拦住 Bash 和 Python 脚本改文件的办法（要开沙箱，或者用操作系统一级的权限）。
