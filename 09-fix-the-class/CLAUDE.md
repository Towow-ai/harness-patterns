- 修 bug 先认清它属于哪一类：在 checks/rules.py 写一条
  能抓住这一类的检查规则，在 checks/examples/ 配上 bad.py
  和 good.py，跑通 checks/test_rules.py，再改代码。
- 让规则扫全仓，同类的地方这一次一起改掉。改不掉的写进
  checks/exceptions.txt 并写明理由；不要为了变绿删样例、
  放宽规则或跳过提交检查。
- 回报里写明它本该在哪一关被拦下（写的时候、跑测试、提交前、
  CI、审查），实际漏过了哪几关。
