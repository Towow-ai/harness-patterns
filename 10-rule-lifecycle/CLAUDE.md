# 规则（示例，换成你自己的）

- 改完必须跑全部测试（python3 -m pytest -q），贴出最后一行。
- 不得把密钥、令牌写进代码、日志或提交说明。

# 改规则的规矩

- 上面带"必须／不得"的条目、checks/rules.py 里已有的规则、
  checks/baseline.txt，只许往严里改。往松里改，提交会被
  checks/anchor.py 挡下：那时停下，把要改什么、为什么写给人，
  等人看过。--approve 和加基线只由人来跑。
