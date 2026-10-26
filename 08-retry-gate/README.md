# 第 8 期：没有新信息不重来

文章：公众号“Harness 模式”第 8 期《Agent 失败了别急着重试：给熔断器补一条规矩，没有新信息不重来》，北京时间 11 月 20 日发出。为什么这样设计、实测里每一步看到了什么，都在文章里。下面是这一期配置的完整说明，文章附录贴了其中三份短的。

这是最小可跑版，做法见文章第三到五节，怎么故意犯一次见文章第六节。一共五份，脚本只用 Python 3 和 git。我们在 macOS 上的 Claude Code 2.1.302 跑通过，测的是后台 Agent（`claude --bg` 起的、不占终端的 Agent），模型是 Sonnet，也读了我们机器上用户级和上级目录的 CLAUDE.md；文章里写 Agent 怎么反应的几处，换模型、换你自己的规则，都可能不同。

1. 五份放进仓库根目录。`CLAUDE.md`、`.claude/settings.json` 已经有的，把条目并进去，别整份替换。然后 `chmod +x scripts/*.py`，再提交。
2. 把 `record_run.py` 里 `CHECK` 那一行换成你这件活的验收命令。
3. 把测试缓存、日志这类会自己变的文件加进 `.gitignore`：没被忽略的文件都算仓库内容，缓存一变，闸门会当成有了新信息。
4. 在仓库根目录启动 Claude Code。

两处边界：开着实验性的 agent teams 时，主 Agent 给子 Agent 起了名字，它会被起成队友；队友收工时 SubagentStop 照样会跑，可这套记录认不出它，一笔都不记。子 Agent 自己把命令放到后台、先收工等通知，那次中途收工多半也会被记成一次失败。

**`CLAUDE.md`**：两条，并进你现有的。

全文见本目录 [`CLAUDE.md`](CLAUDE.md)。

**`.claude/settings.json`**：派子 Agent 和续跑之前跑闸门，子 Agent 收工时跑记录脚本；Agent 跑不了放行脚本。

全文见本目录 [`.claude/settings.json`](.claude/settings.json)。

**`scripts/retry_gate.py`**：闸门。拦下时把理由交给 Claude；读不了输入就退出 1，Claude Code 当作非阻断错误，照常派。

全文见本目录 [`scripts/retry_gate.py`](scripts/retry_gate.py)。

**`scripts/record_run.py`**：子 Agent 收工后跑验收，没过记一笔；派过子 Agent 的那一层不记；出错也退出 0，不拦子 Agent 收工。

全文见本目录 [`scripts/record_run.py`](scripts/record_run.py)。

**`scripts/retry_reset.py`**：人放行。只追加一行，不删记录；在仓库外面跑，也记进这个仓库。

全文见本目录 [`scripts/retry_reset.py`](scripts/retry_reset.py)。

这个目录没放的：我们的单测（27 条，喂假的 hook 输入，不起 Claude）和实测用的玩具仓库。
