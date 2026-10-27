# 第 7 期：接班先跑脚本重算状态

文章：公众号“Harness 模式”第 7 期《Claude Code 压缩后就“失忆”？接班先跑脚本重算状态，别信摘要里的数字（附交接模板）》，北京时间 11 月 17 日发出。为什么这样设计、实测里每一步看到了什么，都在文章里。这几份和文章附录逐字相同，下面是附录的说明原文。

这是最小可跑版，做法见文章第三到六节，装好以后怎么故意犯一次在本文最后。一共五份，脚本只用 bash、git 和系统自带的命令（sed、head、tail 之类），加你项目自己的测试命令。我们在 macOS 上的 Claude Code 2.1.302 跑通过，测的是后台 Agent（`claude --bg` 起的、不占终端的 Agent），模型是 Sonnet，也读了我们机器上用户级的 CLAUDE.md；文章里写 Agent 怎么反应的几处，换模型、换你自己的用户级规则，都可能不同。人在旁边看的交互模式，和在你自己仓库里手动 `/compact`，以你故意犯一次的结果为准。

1. 五份放进仓库根目录。`CLAUDE.md`、`.claude/settings.json` 已经有的，把里面的条目并进去，别整份替换；已经挂了 SessionStart 的，把这一条并进同一个数组。然后 `chmod +x scripts/state.sh`，再把五份提交。
2. 把 `state.sh` 里 `TEST_CMD` 那一行换成你项目里只收集、不运行测试的命令。
3. 在仓库根目录启动 Claude Code；从子目录启动，读不到这份 `settings.json`。

**`scripts/state.sh`**：压缩以后重算测试数、还没提交的改动、当前分支，每个数后面印着命令；出错也写到标准输出、退出 0。

全文见本目录 [`scripts/state.sh`](scripts/state.sh)。

**`.claude/settings.json`**：只挂一个 SessionStart，matcher 是 `compact`。

全文见本目录 [`.claude/settings.json`](.claude/settings.json)。

**`CLAUDE.md`**：两条，并进你现有的。

全文见本目录 [`CLAUDE.md`](CLAUDE.md)。

**`docs/task-template.md`**：任务说明四样，最后一节原样发给子 Agent。

全文见本目录 [`docs/task-template.md`](docs/task-template.md)。

**`.claude/agents/cold-reader.md`**：冷读子 Agent，只给 Glob，只答六问。

全文见本目录 [`.claude/agents/cold-reader.md`](.claude/agents/cold-reader.md)。

**故意犯一次**

1. 让它只跑一部分测试，告诉你结果。比如：

```
python3 -m pytest tests/unit -q
```

2. 手动压缩一次：

```
/compact
```

3. 对它说：我要派一个子 Agent 改某个函数，先别派，把任务说明写进 `handoff/task.md`，做好的标准里写上仓库现有的测试数，要求改完一个都不能从通过变成失败。
4. 打开 `handoff/task.md` 看两处：测试数是全仓的数，还是第 1 步那一部分；数后面有没有命令。再问它：压缩以后，上下文里有没有一段以“压缩后重算的状态”开头的文字。
5. 想看冷读，让它把这份说明原样交给 cold-reader 三次，三份回答对着看：哪一样三份都答“说明里没有”，就先补哪一样。

这个目录没放的是我们测试用的玩具仓库和撑满上下文用的填充文件，它们只为让后台 Agent 自动压缩。
