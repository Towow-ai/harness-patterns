# 第 10 期：规则的上线、比对与退役

文章：公众号“Harness 模式”第 10 期《CLAUDE.md 里的“必须”怎么一刀刀变成“可以”：Agent 规则的上线、比对与退役》，北京时间 11 月 27 日发出。为什么这样设计、实测里每一步看到了什么，都在文章里。下面是这一期配置的完整说明，文章附录贴了其中六份短的。

这是最小可跑版，做法见文章第三到六节，怎么故意犯一次见文章第七节。一共八份，只用 Python 3.9 以上的标准库和 git。我们在 macOS 上的 git 2.54.0 和 Claude Code 2.1.302 跑通过，测的是后台 Agent（`claude --bg` 起的、不占终端的 Agent），模型是 Sonnet，权限模式是 bypassPermissions，没载入用户级的 settings.json，但读了我们机器上用户级的 CLAUDE.md；文章里写 Agent 怎么反应的几处，换模型、换你自己的规则，都可能不同。

1. 八份放进仓库根目录。`CLAUDE.md` 已经有的，把“改规则的规矩”那一节并进去，别整份替换；`.claude/settings.json` 已经有的，把三条 deny 并进 `permissions.deny`。装过《先写检查规则再改代码》那一套的，`checks/rules.py` 和 `.githooks/pre-commit` 同名、写法不同，别整份覆盖，先在另一个仓库试这一套。
2. 在仓库根目录跑这两行，让 git 用 `.githooks/` 里的钩子：

```
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit
```

3. 由人跑后面两行：先把仓库里已有的违规记进基线（规则名换成你自己的，每条 enforce 的规则跑一次），再记下人审过的版本，然后提交。

```
python3 checks/run.py --baseline requests-timeout
python3 checks/anchor.py --approve
```

`core.hooksPath` 是本地设置，不跟着仓库走，每个新克隆都要再跑一次第一行。人审过的版本存成一个叫 `rules-reviewed` 的轻量 tag，指向一棵只装这几份文件的树；推送时它不会自动带上去。

比对的范围：`CLAUDE.md` 里带强词的行；`checks/rules.py` 的每条规则和规则以外的代码；`checks/baseline.txt` 的条数；`anchor.py` 里 `WHOLE` 那张清单上的四份文件（设置文件、pre-commit 钩子、`run.py`、`anchor.py`），要逐字一致。新加的 hook 脚本、别的规则文件，写进 `WHOLE` 才管得到。受保护的文件暂存区和工作区不一致时，提交会先被挡，先 `git add` 或 `git stash`；检查规则扫的也是工作区，被挡后改好，要再 `git add` 一次。命中记录写在 `checks/hits.jsonl`，不进 git。`git commit --no-verify`、`git commit -n`、改掉钩子文件、换掉 `core.hooksPath`，都能跳过这一层。

**`CLAUDE.md`**：示例。文件开头两条换成你自己的规则，“改规则的规矩”那一节并进你现有的。

全文见本目录 [`CLAUDE.md`](CLAUDE.md)。

**`.claude/settings.json`**：三条 deny，挡 Agent 最顺手的三种写法：带 `--approve`、带 `rules-reviewed`、带 `--no-verify` 的命令。只认命令原文，换个写法就挡不住。

全文见本目录 [`.claude/settings.json`](.claude/settings.json)。

**`.githooks/pre-commit`**：pre-commit 钩子。先用 shell 拿 `anchor.py` 和人审过的那份逐字节比，再和人审过的版本整体比，最后按阶段跑检查规则；哪一步失败，包括脚本自己出错，都挡下这次提交。

全文见本目录 [`.githooks/pre-commit`](.githooks/pre-commit)。

**`checks/rules.py`**：检查规则。每条用 `@rule("名字", stage="...")` 登记；示例两条，一条已经在拦，一条刚上线只记录。

全文见本目录 [`checks/rules.py`](checks/rules.py)。

**`checks/run.py`**：按阶段跑检查规则，每次命中记一行进 `checks/hits.jsonl`；`--baseline 规则名` 把现有的违规记进基线，只由人来跑。

全文见本目录 [`checks/run.py`](checks/run.py)。

**`checks/anchor.py`**：和人审过的版本整体比，认得出的加严照过，其余挡下来等人看；`--approve` 把现在的样子记成人审过的版本，只由人来跑。

全文见本目录 [`checks/anchor.py`](checks/anchor.py)。

**`checks/baseline.txt`**：基线。起初只有说明。

全文见本目录 [`checks/baseline.txt`](checks/baseline.txt)。

**`checks/.gitignore`**：命中记录只留在本机。

全文见本目录 [`checks/.gitignore`](checks/.gitignore)。

这个目录没放的：我们的单测（39 条，在临时 git 仓库里跑这套文件，不起 Claude）、照文章第七节四步走一遍的脚本，和实测用的练手仓库。
