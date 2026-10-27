# 第 2 期：盯产出，给巡检装死人开关

文章：公众号“Harness 模式”第 2 期《监控全绿，Agent 却一夜没交活：心跳只证明它活着，要盯产出，还要给巡检装死人开关》，北京时间 10 月 30 日发出。为什么这样设计、实测里每一步看到了什么，都在文章里。这四份和文章附录逐字相同，下面是附录的说明原文。

这是最小可跑版，做法见文章第三到六节，装好以后怎么故意犯一次在本文最后。四份，外加 `.gitignore` 一行。巡检和死人开关由 cron 跑，cron 的 PATH 只有 `/usr/bin:/bin`，所以这两个脚本除了 bash 和 git，只用系统自带的命令。在 Claude Code 2.1.302 和 macOS 自带的 cron 上整条跑通过；Linux 上 `date -r 文件` 同样是取文件的修改时间（GNU date 的写法），我们没在 Linux 上测。

用之前做四件事：

1. 四份放进仓库，`chmod +x scripts/*.sh`；`.gitignore` 加一行 `.watch/`，巡检的记录和告警都写在这里。
2. 主干叫 master 的，在 crontab 里加一行 `BASE=master`；一小时的门槛在 `MAX_AGE`（秒），死人开关的 `LIMIT` 取两个巡检周期多一点。
3. `crontab.txt` 里 `R` 改成仓库的绝对路径，路径带空格也照写，两行里的 `"$R"` 已经加了引号。`ALERT_CMD` 换成你的通知，webhook 地址留在单引号里：有的群机器人的地址带 `&`，不加引号，命令会在 `&` 处断开，后半截地址和告警正文都会丢掉。群机器人要 JSON 的（比如 Slack），换成 `crontab.txt` 里注释着的那行，用 jq 包一层，别的机器人按它要的字段改；`/usr/bin` 里没有 jq 的，先装上，再写它的全路径（cron 的 PATH 只有 `/usr/bin:/bin`）。cron 会把任务打出来的东西发进本机邮箱（macOS 在 `/var/mail/` 下），平时没人看，所以 curl 带着 `-o /dev/null`，成功时不出声。
4. 先在终端手动跑一次 `scripts/watch-output.sh`，`.watch/log` 里会多出一行 `late=…`：仓库干净时是 `late=0`；有超过一小时没合回的旧分支、改了没提交的旧 worktree，这一行会先把它们列出来，`.watch/alerts` 里也记一条。然后再装 crontab。不先跑，死人开关第一次跑时还找不到记录，会先叫一声“巡检还没有留下过记录”；巡检真的从没跑起来过，它也是这样叫。`crontab crontab.txt` 会替换掉你现有的 crontab，已经有的话，用 `crontab -e` 把这几行加进去。仓库放在桌面、文稿、下载这几个目录里的，macOS 可能不让 cron 读，要先在系统设置里给 `/usr/sbin/cron` 完全磁盘访问权限，这一条我们没测。

**`scripts/watch-output.sh`**：巡检。列出超过 `MAX_AGE` 秒没合回主干的分支，和改了没提交、改动超过 `MAX_AGE` 秒没再动过的 worktree，每轮写一行。开头那行 `GIT_OPTIONAL_LOCKS=0` 让它对 git 只读：不去写 Agent 正在用的 worktree 的 index（暂存区），免得和 Agent 的 git 命令抢锁。

全文见本目录 [`scripts/watch-output.sh`](scripts/watch-output.sh)。

**`scripts/deadman.sh`**：死人开关。只看巡检的记录多久没更新。

全文见本目录 [`scripts/deadman.sh`](scripts/deadman.sh)。

**`scripts/alert.sh`**：告警出口。记一行，再交给 `ALERT_CMD`。

全文见本目录 [`scripts/alert.sh`](scripts/alert.sh)。

**`crontab.txt`**：两行定时，外加路径和通知。

全文见本目录 [`crontab.txt`](crontab.txt)。

**装好以后，故意犯一次**：

1. 让一个后台 Agent 在 worktree 里提交一个改动、不合回。一个半小时内，你应该收到一条“没合回 main”，后面列着这个分支。
2. 把 crontab 里巡检那一行注释掉，等一个多小时（从注释掉算，最长约 70 分钟），你应该收到“巡检已经多少秒没有新记录”。收不到，先看 `.watch/alerts`：里面有这一条，是你的通知没接通；没有，是 cron 没把脚本跑起来。
3. 把那一行改回来。下一轮巡检写了记录，死人开关就不再响；在那之前，它可能还会再响几次。测完先移除第 1 步那个 worktree（`git worktree remove <路径>`；里面还有没提交的东西，它会拒绝，确认不要了再加 `--force`），再把分支合回或删掉，不然巡检每半小时还会报它一次。

我们在三个新仓库里照着测过，都把两行改成每分钟跑，巡检门槛缩到 2 分钟，死人开关 150 秒。每次都有一个分支提交了、不合回，三次都是巡检在提交满 2 分钟后的第一轮报了它；前两次另有一个合回主干的分支，一次也没报。停法换着来，两次注释掉巡检那一行，一次把巡检脚本改名，死人开关都在巡检最后一次记录 3 分钟后响了，告警经 curl 送到了本机的一个收件端。最后一次的仓库路径带空格，crontab 照这一版写，地址里带 `&`，收件端收到的地址是完整的。改了没提交那一项另测了两次：后台 Agent 在 worktree 里新建一个文件、不提交，我们在它干到一半时用 `claude stop` 停掉，巡检门槛同样缩到 2 分钟，改动不满 2 分钟的那几轮记的是 `late=0`，满 2 分钟后的第一轮报出了它。
