# 第 9 期：先写检查规则再改代码

文章：公众号“Harness 模式”第 9 期《Agent 修过的 bug 总回来？先写检查规则再改代码：修复的五个等级（附检查规则模板）》，北京时间 11 月 24 日发出。为什么这样设计、实测里每一步看到了什么，都在文章里。这几份和文章附录逐字相同，下面是附录的说明原文。

这是最小可跑版，做法见文章第四到七节，怎么故意犯一次见文章第八节。一共七份，只用 Python 3.9 以上的标准库和 git。我们在 macOS 上的 git 2.54.0 和 Claude Code 2.1.302 跑通过，测的是后台 Agent（`claude --bg` 起的、不占终端的 Agent），模型是 Sonnet，权限模式是 bypassPermissions，也读了我们机器上用户级的 CLAUDE.md，那份里没有修 bug、写检查规则一类的条目；文章里写 Agent 怎么反应的几处，换模型、换你自己的规则，都可能不同。

1. 七份放进仓库根目录。`CLAUDE.md` 已经有的，把三条并进去，别整份替换。
2. 在仓库根目录跑这两行，让 git 用 `.githooks/` 里的钩子：

```
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit
```

3. 跑一次 `python3 checks/rules.py`，看仓库里现在有几处；报出来的改掉，或者写进例外表并写明理由，再提交。

`core.hooksPath` 是本地设置，不跟着仓库走，每个新克隆都要再跑一次第一行。

三处边界：检查扫的是工作区里所有没被 `.gitignore` 忽略的 `.py` 文件，没 `git add` 的新文件也算；暂存区和工作区不一致时，它看的是工作区，暂存区里那份错的照样能提交进去，这也是 CI 要再跑一遍的原因。`git commit --no-verify` 能跳过 pre-commit 钩子。示例那条规则只认 `requests.get(...)` 这种写法，`from requests import get` 以后的 `get(...)`、`session.get(...)`、`timeout=None` 它都不报。

这个目录不含 CI 配置：在 CI 里跑和钩子同一行 `python3 checks/test_rules.py && python3 checks/rules.py`，红了不合。

**`CLAUDE.md`**：三条，并进你现有的。

全文见本目录 [`CLAUDE.md`](CLAUDE.md)。

**`.githooks/pre-commit`**：先证明，再扫全仓；哪一步失败，包括脚本自己出错，都挡下这次提交。

全文见本目录 [`.githooks/pre-commit`](.githooks/pre-commit)。

**`checks/rules.py`**：检查规则。一类一条，用 `@rule("名字")` 登记；扫整个仓库，读不懂的文件算没过，例外要写理由。

全文见本目录 [`checks/rules.py`](checks/rules.py)。

**`checks/test_rules.py`**：证明每条规则抓得住。坏样例必须报、好样例必须不报，样例缺了算没过。

全文见本目录 [`checks/test_rules.py`](checks/test_rules.py)。

**`checks/exceptions.txt`**：例外表。起初只有说明，一行一条，理由必填。

全文见本目录 [`checks/exceptions.txt`](checks/exceptions.txt)。

**`checks/examples/requests-timeout/bad.py`**：坏样例：规则必须报它。

全文见本目录 [`checks/examples/requests-timeout/bad.py`](checks/examples/requests-timeout/bad.py)。

**`checks/examples/requests-timeout/good.py`**：好样例：规则必须不报它。

全文见本目录 [`checks/examples/requests-timeout/good.py`](checks/examples/requests-timeout/good.py)。

这个目录没放的：我们的单测（24 条，在临时 git 仓库里跑这套文件，不起 Claude）和实测用的订单小项目。
