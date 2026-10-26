# 第 1 期：独立验收

文章：公众号“Harness 模式”第 1 期[《别让 Agent 既当运动员又当裁判：Claude Code 独立验收的 4 个做法（附最小可跑配置）》](https://mp.weixin.qq.com/s/lYN7NwXgA_UvdjA-iXnyiw)。为什么这样设计、实测里每一步看到了什么，都在文章里。这六份和文章附录逐字相同。

六份各管一段：`settings.json` 把两道 hook 挂上，并禁止 Agent 动 git 标签；`verifier.md` 定义验收 Agent；`guard-verifier-write.sh` 是拦写入的 hook；`stop-gate.sh` 是 Stop hook，`state-hash.sh` 替它算工作区的状态；`pre-push-gate.sh` 装成 git 的 pre-push，推送没有 pass 结论的提交就拒推。

六份放进一个 git 仓库就能用，在 Claude Code 2.1.293 上整条链路跑通过。`.claude/` 和 `scripts/` 两个目录放在你仓库的根目录（`.claude` 以点开头，用 `cp 目录/*` 拷不到，要连目录一起拷）；你已经有 `.claude/settings.json` 的，把里面的条目并进去，别整份覆盖。要装 git 和 python3（3.8 以上），三个 hook 都用 python3，不是 Python 项目也要装。

## 用之前做四件事

1. `.gitignore` 里写上所有跑起来会往仓库里写的东西：`.verdicts/`、测试缓存（Python 是 `__pycache__/` 和 `.pytest_cache/`）、程序自己的数据文件。漏了 `.verdicts/`，写结论本身就改了状态，结论永远对不上；漏了缓存或数据文件，验收之后再跑测试、用程序，状态一变，结论又对不上。
2. 新建的仓库先交互式打开一次 Claude Code，接受对这个目录的信任，项目设置才会完整生效；脚本放好后跑一次 `chmod +x scripts/*`。
3. 先提交一次，在终端里跑 `git tag verified` 定基线。以后每次验收通过、你看过结论，提交代码，再跑 `git tag -f verified` 挪基线。
4. 装 pre-push：`ln -s ../../scripts/pre-push-gate.sh .git/hooks/pre-push`。团队里每人都要装。

例子是 Python 项目，测试命令换成你自己的；JS 项目去掉 `-B` 那串参数；拷副本时 node_modules 可以不拷，但要在副本里建个软链接指回原仓库那份，不然副本里的测试一跑就报找不到模块，每处改坏看上去都红了。

## 故意犯一次

收工那道 Stop hook 只拦一下、提个醒，挡不住；真正挡住没验收的代码的，是推送前那道 pre-push。搭完以后，故意犯一次，看它拦不拦：

1. 改一行代码，叫 Claude 不验收、直接收工：看它被拦下，提示里要它先派验收 Agent。它要是听你的、再收工一次，这次会放行，但界面上会出现那句提醒。
2. 让它派验收，交回 pass 后再收工：放行。
3. 发一句新话，只问一个问题、不改代码：收工不被拦。
4. 再改一行，让 Claude 先 `git commit` 再收工：照样被拦。
5. 不验收就 `git push`：被 pre-push 拒掉。

## 文件

- `.claude/settings.json`：禁止 Agent 跑 `git tag` 和 `git update-ref`，在调用工具前挂写入 hook，在收工时挂 Stop hook。
- `.claude/agents/verifier.md`：验收 Agent 的定义。在仓库里只能写结论，改坏在临时目录的副本里做。
- `scripts/guard-verifier-write.sh`：拦写入的 hook。验收 Agent 只能写 `.verdicts/` 和临时目录，主 Agent 不能写 `.verdicts/`。
- `scripts/stop-gate.sh`：收工前的检查，没有对得上当前状态的 pass 结论就拦一次。
- `scripts/state-hash.sh`：把整个工作区算成一串校验值，没提交的改动、新文件、删掉的文件都算在内。
- `scripts/pre-push-gate.sh`：推送前的检查，推送的提交没有 pass 结论就拒推。
