# 第 5 期：认领要改的文件

文章：公众号“Harness 模式”第 5 期《开了 worktree，多个 Claude Code 照样撞车：乐观锁搬过来，还要先报要改的文件》，北京时间 11 月 10 日发出。为什么这样设计、实测里每一步看到了什么，都在文章里。下面是这一期配置的完整说明，文章附录贴了其中两份短的。

这是最小可跑版，完整做法见文章第四至六节。第一次先照“故意犯一次”在 `~/drill` 里走一遍；都对了，再照“装进真仓库”装。五份文件各管一段：`.claude/settings.json` 把 hook 挂在编辑和写文件的工具上；`.claude/hooks/claims.sh` 是那道 hook；`scripts/claim.sh` 开 worktree、写认领；`scripts/land.sh` 核四样、快进合并；`CLAUDE.md` 是给 Agent 的四条规矩。

**故意犯一次（在 `~/drill` 里）**

第 1 步：新建一个仓库，主干叫 main，放一个 README.md 并提交。

```bash
mkdir ~/drill && cd ~/drill && git init -b main
echo '# drill' > README.md
git add README.md && git commit -m init
```

第 2 步：把本目录的五个文件照路径放进 `~/drill`，加执行权限，让 git 忽略 worktree 所在的目录，提交。worktree 从主干开出来，hook 和脚本得先在主干上，每个 worktree 里才有。

```bash
chmod +x .claude/hooks/claims.sh
chmod +x scripts/claim.sh scripts/land.sh
echo '.claude/worktrees/' >> .gitignore
git add .gitignore CLAUDE.md .claude/settings.json
git add .claude/hooks/claims.sh
git add scripts/claim.sh scripts/land.sh
git commit -m 'add claims'
```

再在这里跑一次 Claude，接受信任提示后退出。照官方文档，没在这个目录跑过 Claude 的，`--worktree` 会报错退出。

```bash
claude
```

第 3 步：让 a 认领 README.md，b 认领一个还不存在的 NOTES.md。每个任务第一次认领时，会顺手开好它的 worktree。

```bash
scripts/claim.sh a README.md
scripts/claim.sh b NOTES.md
```

第 4 步：在 b 的 worktree 里起 Claude，让它在 README.md 末尾加一行。照官方文档，同名目录已经存在时，`--worktree` 直接打开它，还会打开 Claude Code 自带的 worktree 隔离（它拦的是用编辑工具改主目录文件、在主目录里跑的命令和把 git 指回主目录的命令）；这一步我们没实测，我们实测用的是先起 Agent、再让它 `cd` 进 worktree，自带隔离不开，hook 照样管。`--worktree` 起不来，就 `cd .claude/worktrees/b` 再起 `claude`，官方文档手动管理 worktree 的那一节给的也是这个起法。

```bash
claude --worktree b
```

该看到两种之一：它写的时候被 hook 拦下，看到 `README.md is claimed by task a`；或者它先试着补报 README.md，被 `claim.sh` 拒。两种都对。我们实测时，Agent 被拒以后没去碰那个文件，把能做的做完，在汇报里写明缺哪个（文章第四节）。这个 Claude 会占着终端；看完它被拦就退出，退出时它要是问删不删这个 worktree，选保留。

用后台 Agent 的，起法和我们实测的一样：`claude --bg` 起来以后，第一句就让它 `cd .claude/worktrees/b` 再干活。差别在于我们起 Agent 时，那个目录还不是 git 仓库；你在仓库里起，照官方文档，Agent 要改的文件已经在一个 worktree 里，Claude 就不会另开一个，这一点我们没实测。

第 5 步：你自己从 shell 替它写进去，再提交。hook 看不见这一下。

```bash
cd ~/drill
echo hello >> .claude/worktrees/b/README.md
git -C .claude/worktrees/b add -A
git -C .claude/worktrees/b commit -qm hello
```

第 6 步：合并 b，该被拒，提示里有 `README.md(unclaimed) README.md(claimed by a)`，是第一样拦的。

```bash
scripts/land.sh b
```

第 7 步：在主干上直接改 README.md 并提交，再合并 a，该被拒：`main changed your files since the claim: README.md`。a 认领时记下的版本，已经不是主干现在的样子，这就是核版本。

```bash
cd ~/drill
echo x >> README.md && git commit -qam x
scripts/land.sh a
```

**装进真仓库**

第 1 步：把五个文件放进仓库根目录，照“故意犯一次”第 2 步加执行权限、忽略 worktree 目录、提交。你的仓库已经有 CLAUDE.md 或 `.claude/settings.json` 的，把本目录那份的内容并进去，别整份覆盖。脚本里主干名写死为 `main`；合并脚本跑测试默认用 `python3 -m pytest -q`。都不是的话，先改脚本：主干名在两个脚本里，测试命令在 `land.sh` 标着 `edit me` 的那一行，或者用环境变量 `LAND_TEST` 传进去。

第 2 步：每个任务开工前，从完成判据倒推要改的文件，认领下来。下面拿文章第四节那个计算器举例：任务 a 要加一个子命令，改实现、测试和登记表。

```bash
scripts/claim.sh a commands/sub.py \
  tests/test_sub.py commands/__init__.py
```

第 3 步：在这个 worktree 里起 Claude，起法和退路同“故意犯一次”第 4 步。

```bash
claude --worktree a
```

用后台 Agent 的，起来以后第一句让它 `cd .claude/worktrees/a`。从主目录起、又没让它 `cd` 进去，照官方文档它会自己另开一个不叫 a 的 worktree：hook 认不出它是 a，把 a 认领的文件也当成别人的拦下，没人认领的文件反倒放行；主干测试能跑通的话，`land.sh a` 什么也没合进去，照样打印 landed，活却在另一个分支上。这条错路我们没让真 Agent 走过：hook 那一下是拿 hook 的输入模拟的，空分支的合并在临时仓库里跑过。

第 4 步：Agent 说做完了，你在主目录合并。汇报里说缺哪个文件、哪里还没接上的，先别合（文章第六节）。被拒时，提示会写明是哪一样没过。

```bash
scripts/land.sh a
```

缺的文件在别的任务手里时，比如任务 b 还要改登记表，登记表归 a：先别合 b，等 a 照上面合进去，再照下面的顺序放开 a 的认领、把 b 的 worktree rebase 到主干、让 b 补报。b 手上的改动要先提交。不 rebase 就补报会被拒：a 合并时改过登记表。

```bash
scripts/claim.sh --release a
git -C .claude/worktrees/b rebase main
scripts/claim.sh b commands/__init__.py
```

然后让 b 的 Agent 接着做完、提交，再合并 b。

```bash
scripts/land.sh b
```

第 5 步：任务彻底做完、合进去以后放开认领（上面放开过的，再跑一次也没事），别的任务才能认领这些文件；再删掉它的 worktree 和分支，以后同名的任务才开得出新的 worktree。

```bash
scripts/claim.sh --release a
git worktree remove .claude/worktrees/a
git branch -d a
```

我们在 Claude Code 2.1.302、macOS 上用后台 Agent（bypassPermissions 模式）实测过。后台 Agent 跑的是 `land.sh` 加 `--no-renames` 之前的版本，和这里只差这一个参数，跑过一遍逐条测试和一遍自然场景（任务 b 先后交给两个 Agent：第一个做实现和测试，第二个补报并接上登记表），结果就是文章第四、五节写的；加了这个参数以后，脚本级的测试和上面的“故意犯一次”都在这一版上重跑过。Agent 都是先起来、再 `cd` 进的 worktree，没有用 `claude --worktree`，Claude Code 自带的 worktree 隔离也没开。为了不让本机别的全局设置和 hook 混进结果，都只加载项目级设置（启动时带 `--setting-sources project,local`）；用户级的 CLAUDE.md 不归这个参数管，照样读进来了。“故意犯一次”除了第 2 步跑 Claude 和第 4 步起 Agent，命令都照原样跑过；第 4 步 Agent 被拦的那一下用 hook 的输入模拟。真 Agent 被这道 hook 拦下，我们在逐条测试里跑过；文章第四节那个 Agent 碰上的是另一种：补报被 `claim.sh` 拒。

几处细节：

- 认领的路径一律从仓库根目录写，不带 `./`，也不写绝对路径，一个文件一行，不能认领目录。脚本按字面比，`./a` 和 `a` 会被当成两个文件。
- 脚本用了 `git rev-parse --path-format`，要 git 2.31 以上。
- hook 只挂了 `Edit|Write`。笔记本编辑工具传给 hook 的路径字段叫什么，官方文档没写，没挂。
- hook 按 Claude Code 传进来的 `cwd` 判断自己在哪个 worktree，不靠 `$CLAUDE_PROJECT_DIR`。照官方文档，桌面端的 worktree 里 hook 在主目录跑、要从 `cwd` 读 worktree 路径，这个写法正好对得上；桌面端我们没测。
- hook 自己出错时（比如找不到 python3），照官方文档，Claude Code 默认照常写，兜底在合并那一步。
- Claude Code 自带的隔离开着时，Agent 自己跑 `claim.sh` 补报会不会被拦，我们没测。文档说隔离的检查读的是命令的字和命令在哪个目录跑，没说跑一个脚本算不算；开头那次对照实测里，进了隔离的 Agent 跑 `python3 -m pytest -q` 照常放行，只有一条塞了几段 heredoc 的长命令被拒，所以我们推断 `claim.sh` 也会放行。真被拦了，你在主目录替它补报就行。
- 每次合并成功后，`land.sh` 把认领里记的版本挪到新的主干。不然同一个任务的下一轮，会把自己上一轮合进去的提交当成别人的改动，每一轮都在第二样被拦下，只能靠 `--accept` 放行（脚本里试过）。
- 第一样用的是 `git diff --no-renames`。git 默认把改名只列成新名字，把别人认领的文件改名成自己认领的路径，就看不出来；加上这个参数，改名按删掉旧名、新增新名算，旧名在别人的认领里，照样拒。脚本里试过。
- 第四样我们在脚本里试过：让两个合并同时抢主干，跑了 7 次，每次都是一个合进去、另一个被拒，没有一次两个都合进去（其中 6 次在加 `--no-renames` 之前的版本上跑，第四样那段代码没改）。快进因为别的原因失败时，提示也是 `main moved`，比如主目录里有个没跟踪的同名文件；这时先看 git 自己印出来的报错，重跑不会好。
- 认领文件在 `.git/claims/` 下，一个任务一份，第一行是 `base` 加主干提交，后补的行带“+ ”。两个脚本改它时用同一把目录锁，一次只有一个在写；脚本被强行杀掉时这把锁会留下，之后两个脚本都会一直等，删掉 `.git/claims/.lock` 就好。
- 只在 macOS 上测过，Windows、Linux 没测。

**`.claude/settings.json`**：在编辑和写文件之前先跑 hook。

全文见本目录 [`.claude/settings.json`](.claude/settings.json)。

**`.claude/hooks/claims.sh`**：在哪个 worktree、写的是谁的文件。别人认领的都拦；自己有认领时，认领外的也拦；仓库外的放行。

全文见本目录 [`.claude/hooks/claims.sh`](.claude/hooks/claims.sh)。

**`scripts/claim.sh`**：第一次认领时开 worktree、记下主干提交；别人手里的文件拒绝；主干改过、你还没跟上的文件拒绝补报。

全文见本目录 [`scripts/claim.sh`](scripts/claim.sh)。

**`scripts/land.sh`**：在主目录跑，按顺序核四样，快进合并，合并后挪版本。

全文见本目录 [`scripts/land.sh`](scripts/land.sh)。

**`CLAUDE.md`**：给 Agent 的四条规矩。

全文见本目录 [`CLAUDE.md`](CLAUDE.md)。

没贴的：不是文件的那一类认领，以及自动合并。
