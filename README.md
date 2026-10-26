# Harness 模式：最小可跑配置

Minimal, tested Claude Code configurations from *Harness 模式* (Harness Patterns), a Chinese-language WeChat series on agent harness patterns. Each folder holds every file of one issue's setup. Copy them (not the folder's README.md) into a git repository, follow the folder's README, then try to break it once on purpose and see what it stops and what it only flags.

这里放公众号“Harness 模式”系列每期文章里那套最小可跑配置的全部文件，一期一个目录。为什么这样设计、实测里看到了什么，写在文章里；这里只放文件。每个目录的说明写了文件放哪、用之前要做哪几件事、怎么故意犯一次；目录里的 README.md 就是这份说明，不用拷进你的仓库。每期的文件都在那期写明的 Claude Code 版本上跑通过。

| 期 | 目录 | 讲什么 | 文章 |
|---|---|---|---|
| 第 1 期 | [01-independent-verifier](01-independent-verifier/) | 写代码的 Agent 不给自己验收：只读的验收 Agent 判完成，收工和推送前都查它的结论 | [第 1 期文章](https://mp.weixin.qq.com/s/lYN7NwXgA_UvdjA-iXnyiw) |

每发一期，这里加一个目录。

许可：MIT，见 [LICENSE](LICENSE)。有问题或想合作：[联系我们](https://towow.net.cn/inquiry?r=gh-harness-patterns)。
