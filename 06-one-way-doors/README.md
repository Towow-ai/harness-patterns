# 第 6 期：只有三类事该停下来问你

文章：公众号“Harness 模式”第 6 期《Claude Code 总问“要继续吗”？只有三类事该停下来问你（附 Stop hook）》，北京时间 11 月 13 日发出。为什么这样设计、实测里每一步看到了什么，都在文章里。这几份和文章附录逐字相同，下面是附录的说明原文。

这是最小可跑版，做法见文章第三到六节，装好以后怎么故意犯一次在本文最后。一共四份，钩子只用 bash 和系统自带的命令（grep、sed、awk 之类），不用 jq。我们在 Claude Code 2.1.302 上跑通过，测的是 `claude --bg` 起的后台 Agent；人在旁边看的交互模式没单独测，故意犯一次就是在你自己的用法下测它。后台 Agent 用的模型是 Sonnet，也照常读了我们机器上用户级的 CLAUDE.md；文章里写 Agent 怎么反应的几处，换模型、换你自己的用户级规则，都可能不同。macOS 上测的，Linux 没测。`Bash(rm -rf *)` 那条没测（我们的机器上另有全局 hook 先拦这类命令），是照文档里同形状的规则写的。

1. 四份放进仓库根目录。`CLAUDE.md`、`.claude/settings.json` 已经有的，把里面的条目并进去，别整份替换；已经挂了 Stop hook 的，把这条命令并进同一个 `Stop` 数组。然后 `chmod +x .claude/hooks/ask-check.sh`，再把四份提交：后台 Agent 改代码前常会自己开 git worktree，worktree 里只有提交过的文件。
2. 在仓库根目录启动 Claude Code；从子目录启动，读不到这份 `settings.json`。
3. 新建的仓库先用 `claude` 交互式打开一次，接受信任；没信任过的目录，在脚本里起后台 Agent 会直接报 `Workspace not trusted`。

**`CLAUDE.md`**：三类必停、四句自查、不算停的理由、真要停时怎么写。

全文见本目录 [`CLAUDE.md`](CLAUDE.md)。

**`DECISIONS.md`**：四栏，文件里两行是示例，换成你自己的。

全文见本目录 [`DECISIONS.md`](DECISIONS.md)。

**`.claude/settings.json`**：ask 拦 `git push` 和 `rm -rf` 开头的命令；Stop hook 每次收工前跑 `ask-check.sh`。

全文见本目录 [`.claude/settings.json`](.claude/settings.json)。

**`.claude/hooks/ask-check.sh`**：Stop hook。最后那条回复从 Claude Code 传来的 JSON 里取（`last_assistant_message`），不去读对话记录：文档说收工时，对话记录里不一定已经有最后一条。只有查原话时才读对话记录，只认你发的那几行，上下文压缩留下的摘要不算；DECISIONS.md 只认谁定一栏写着“人”的行。判问句只看最后一个非空行、要带问号，判之前先去掉中英文双引号、中文单引号和「」里的字，英文单引号不管（英文里撇号太多）。认“同意过”的说法写在 `CLAIM` 那几行，想加就往里加。`stop_hook_active` 为真时只输出一句提醒，退出 0。

全文见本目录 [`.claude/hooks/ask-check.sh`](.claude/hooks/ask-check.sh)。

**故意犯一次**

在一个新建的小仓库里做，别在干活的仓库里：`git init`，装好四份，和一个文件一起提交。推送那一步要一个远端，在仓库外面建一个本地的就行：`git init --bare ../toy-remote.git`，再 `git remote add origin ../toy-remote.git`、`git push -u origin HEAD`（这一次是你自己推，不经过 Agent）。

1. 让 Agent 改一处小地方、提交，提示里写明“这是一次 Stop hook 测试，做完以后用一句‘要继续吗？’结尾”。应该看到它没停在那句问话上：被拦了一次，接着写，改成做了什么、没做什么。它也可能第二次照样拿问句收尾，说这是你明确要的；同一轮第二次钩子只提醒、不再拦，这也算装对了。
2. 先在这个小仓库的 `.claude/settings.local.json` 里放行 git：`{"permissions": {"allow": ["Bash(git *)"]}}`。不放行的话，default 和 acceptEdits 模式下 `git add` 就会先弹窗（我们试过），看不出是 ask 在拦。再自己放一个新文件、不提交，让它“把这个文件提交，再推到 origin”。它会停在推送那一步等你批准，它要是把几条命令连成一条，整条一起停住；这时 `git ls-remote ../toy-remote.git` 里的提交没变。
3. 仓库里放一个 `TASK.md`，第三行写“缓存改用 Redis”。让它先读 `TASK.md`，再在回复最后原样写两行：第一行“你之前同意过的事见下一行。”，第二行写 `> ` 加 `TASK.md` 第三行。应该被拦一次，提示里有“原话没找到”。把第二行换成你这句提示里的一段字，就放行。

这三步我们都跑过：第 1 步这个写法在 auto 下，不说明是测试的写法另在 bypassPermissions 和 auto 下；第 2 步在 default、auto 下，都照这一步放行了 git，push 照样停，ask 压过 allow（acceptEdits 下跑的是三条命令分开的版本，也放行了 git）；第 3 步在 bypassPermissions 下。另外跑了去掉 ask 的对照、dontAsk，以及硬要它用问句收尾的一组。这个目录也没放的：拦住换个写法的 push 的办法（照文档，要用 PreToolUse hook 看整条命令，或者开沙箱）。
