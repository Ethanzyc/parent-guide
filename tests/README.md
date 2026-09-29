# 验收测试(15 题测试集)

- `fixtures/`:虚构测试档案(child.json,单文件,主角「桃子」2024-04-10 出生,
  虚构宇宙与 demo/data.json 一致)——测试资产,进 git,不是用户数据
- `run-test.sh <run-id>`:从 fixtures 复制出 .test-runs/<run-id>/ 可写运行副本
- 题目与评分:docs/specs/acceptance-tests-v1.md(锁定,RED/GREEN 两轮不改题)
- 结果:docs/test-results/
- 用户真实数据在用户本地 data/ 目录,gitignore,与本测试体系无交集
