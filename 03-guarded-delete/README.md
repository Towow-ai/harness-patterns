# 第 3 期：给删除上两道锁

文章：公众号“Harness 模式”第 3 期《hook 拦得住 rm -rf，拦不住 Agent 写的 Python 删除：给删除上两道锁（附配置）》，北京时间 11 月 3 日发出。为什么这样设计、实测里每一步看到了什么，都在文章里。下面是这一期配置的完整说明，文章附录是它的压缩版。

这是最小可跑版，完整做法见文章第三至六节。第一次照下面的步骤，在新建的小仓库里拿假文件试；试通了，再改 `PROTECTED` 和 deny 里的名字。四份文件各管一段：`.claude/settings.json` 打开 sandbox、把 `records` 写进 deny、挂上 hook；`.claude/hooks/guard.sh` 是拦 git 回滚的 hook；`tools/guarded.py` 是删除函数，代码里 import `guarded_rmtree`，shell 里直接跑这个文件；`CLAUDE.md` 是三条删除规矩。另在 `records/` 里建一个空文件 `.do-not-delete`。

**装上（第一次在新建的小仓库里）**

第 1 步：建一个小仓库，主干叫 main。

```bash
mkdir drill && cd drill && git init -b main
```

第 2 步：把本目录四份文件照路径放好，再放几个假文件、一个要改的小文件和一个被 git 忽略的 build 目录，加上执行权限，提交。

```bash
mkdir -p records/events build
echo '{"seq": 1}' > records/events/a.jsonl
touch records/.do-not-delete
echo 'x = 1' > app.py
echo 'build/' > .gitignore
echo out > build/out.txt
chmod +x .claude/hooks/guard.sh
git add -A && git commit -m init
```

第 3 步：在这个仓库的根目录启动 Claude Code。直接退出，说明 sandbox 起不来，照官方 sandbox 文档装好依赖再开；新仓库第一次启动时，照官方文档会请你确认信任这个目录。

```bash
claude
```

我们实测用的是 bypassPermissions 模式。直接敲 `claude` 起来的默认是 auto 模式：照官方文档，auto 模式里另有一个分类器先审 Agent 要做的事，sandbox 里的命令也可能要等它审，判成危险就不跑。下面哪一步要是看到分类器给的拒绝理由（多半是方括号里的一条规则名），那条命令根本没跑，不算 sandbox 或 hook 拦的；想看到它们那一下，用 `claude --permission-mode default` 起手动模式（没有分类器），它问你要不要执行时点同意。auto 和手动这两种模式我们都没测。

**故意犯一次**（每一步单独让 Claude 跑一次）

第 1 步：让它跑下面这条，该看到 `BLOCKED: this command deletes or moves a protected path.`，是 hook 拦的。

```bash
rm -rf records/events
```

第 2 步：另起一次，让它跑下面这条，该看到 `Operation not permitted`，records 里一个文件没少，是 sandbox 拦的（照官方文档，Linux 和 WSL2 上同类的写入报 `Read-only file system`，我们没测）。两条拼成一行跑的话，hook 会把整行先拦下，Python 那半根本没跑，你会以为是 sandbox 拦的。

```bash
python3 -c "import shutil; shutil.rmtree('records')"
```

第 3 步：在 app.py 里加一行先不提交，拿一行丢了也不心疼的改动，让它跑下面这条，该看到 `BLOCKED: this command can throw away uncommitted work.`。这一步才说明 hook 真接上了。

```bash
git checkout -- app.py
```

第 4 步：该看到 `REFUSED: …/records/.do-not-delete protects …/records/events`，是删除函数拒的。

```bash
python3 tools/guarded.py records/events --force
```

第 5 步：该看到 `deleted build`，该删的照删。

```bash
python3 tools/guarded.py build
```

第 6 步：第 3 步那行改动还没提交的话，让它跑下面这条。没有任何提示，改动没了，这是文章第三节那个洞。

```bash
python3 -c "import subprocess; subprocess.run(
  ['git', 'checkout', '--', 'app.py'])"
```

我们在 Claude Code 2.1.302、macOS 上用后台 Agent（bypassPermissions 模式）实测过六遍。和这里逐字相同的四份加空标记文件跑过最后一遍：逐条一遍，结果就是文章第六节那张表；表外另跑的几步里，让删除函数删仓库根，被拒；shell 里 `rm`、Python 里 `os.remove` 各删一个仓库根下的单个文件，都删掉了。第五遍的 CLAUDE.md 第一条还是旧写法（不许裸写 `os.remove`），另外三份和这里相同。第四遍的删除函数还没加“当前目录、仓库根、家目录不删”那一条，CLAUDE.md 也是旧写法，settings.json 和 hook 和这里相同；那一遍另验了三处：hook 没有执行权限时每条 Bash 命令都被拦下，Agent `cd` 进子目录以后 deny 照样认，从子目录启动时三样都不在。第三遍用的是更早一版（deny 写的是 `./records/**`，hook 没设 `onFailure`，删除函数还没收紧下面说的几处，CLAUDE.md 也是旧写法），文章第四节那次自然问法就在这一遍；第一遍用的是再早的版本，hook 对删除命令的判法和这里一样，git 回滚一类后来补了 `switch` 和 `--discard-changes`；第二遍故意不装 hook，只开 sandbox。六遍都只加载项目级设置（启动时带 `--setting-sources project,local`），都交代后台 Agent 不进 worktree。你本机的用户级设置会一起生效，比如把某些命令排除在 sandbox 外，第一次用假目录试，也是为了这个。实测的小仓库是脚本建的，文件名和上面“装上”第 2 步不完全一样；“装上”第 1、2 步和“故意犯一次”的命令，另在脚本里照字面跑过，不经过 Claude Code。“故意犯一次”第 6 步我们跑的是写成一行的同一条命令。

几处细节：

- deny 写 `Edit(...)`，不写 `Write(...)`。照官方文档，路径规则只认 `Edit` 和 `Read`，写成 `Write` 它照收，但从不查。
- deny 的路径写 `/records/**`，开头的 `/` 指启动 Claude Code 的目录。Claude Code 只读启动目录下的 `.claude/settings.json`，从子目录启动时，deny、sandbox 和 hook 都不生效。
- hook 比 sandbox 先跑。`rm -rf records` 这类命令先被 hook 拦下；没有 hook，sandbox 也会拦，我们实测过。
- hook 怎么判：只看命令的字。先找会丢掉没提交改动的 git 子命令，`git -C`、`git -c` 开头的也认，写在 `for`、`if` 里的也认；再找删除或移动命令（`rm`、`rmdir`、`unlink`、`shred`、`mv`、`find -delete`），字里又出现受保护的名字，就拦。拦下时以退出码 2 结束，Claude Code 拒绝这次调用，把提示原样交给 Agent：别换写法重试，去问人。它也会漏：不带 `--` 的 `git checkout app.py` 这类写法认不出，见文章第三节。脚本里的 `python3` 带 `-I`，仓库根有个 `json.py` 也不会被先导入、把 hook 弄崩。
- hook 自己出错也拦：settings.json 里设了 `"onFailure": "block"`，照官方文档要 Claude Code 2.1.295 及以上，更低的版本遇到这个键会怎样，没测。脚本没有执行权限时，每条 Bash 命令都被拦下，我们实测过；找不到 python3 时，照文档也算出错，同样会拦，没测。碰到每条 Bash 都被拦，先查 `guard.sh` 的执行权限和 python3。
- `PROTECTED` 那一行旁边写着 `# edit me`：第一次先别改，用假目录试通了，再换成你的目录名，settings.json 的 deny 里也改一处。
- 删除函数：空字符串和只有空格的路径直接拒；目标是当前目录、仓库根、家目录或 `/` 的，带 `--force` 也拒。查未跟踪文件时带了 `--untracked-files=all`，你的 git 配置不显示未跟踪文件，也照样认得出。被 .gitignore 忽略的文件不算，比如 `.env`、本地数据，不带 `--force` 也照删，这是有意的：“故意犯一次”第 5 步删 build 靠的就是它。它先把软链接解析到真正的目录再查标记；指向别处的软链接，`shutil.rmtree` 本身就不删。不在 git 仓库里，按“有没提交的改动”处理，要带 `--force`；没装 git 时查不了仓库根，判不出就拒，带 `--force` 也删不了。
- 原生 Windows 上要删掉 `failIfUnavailable` 那一行，见文章第六节；这时没有 sandbox，“故意犯一次”第 2 步会真删 records。

**`.claude/settings.json`**：打开 sandbox，不许 Agent 申请在 sandbox 外重跑，sandbox 起不来就不启动；`records` 写进 deny；调用 Bash 之前先跑 hook，hook 自己出错也拦。

全文见本目录 [`.claude/settings.json`](.claude/settings.json)。

**`.claude/hooks/guard.sh`**：拦 git 回滚，兼作 sandbox 不在时的兜底。受保护的名字在 `PROTECTED` 那一行。

全文见本目录 [`.claude/hooks/guard.sh`](.claude/hooks/guard.sh)。

**`tools/guarded.py`**：删除函数。代码里调用其中的 `guarded_rmtree`，shell 里跑 `python3 tools/guarded.py 路径`。

全文见本目录 [`tools/guarded.py`](tools/guarded.py)。

**`CLAUDE.md`**：三条删除规矩。

全文见本目录 [`CLAUDE.md`](CLAUDE.md)。

本目录没有的：按清单删的部署脚本，要接你自己的部署流程，文章第五节写了它要守的规则。
