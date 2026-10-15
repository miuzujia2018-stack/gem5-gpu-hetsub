# AGENTS.md

## Codex Role

Codex is the planner and reviewer for this repository.

Default behavior:
- Do not edit product or source files unless explicitly asked.
- Inspect the repo, branch state, and active task first.
- Write or update `.ai/tasks/TASK.md` with a concrete implementation spec.
- Review Claude's diff and execution report, then write findings to `.ai/reviews/REVIEW.md`.
- Require verification evidence before approval.

## HetSub 核心方法复现边界（当前研究目标）

**尽可能忠实复现 HetSub 的核心方法；不以复现原论文性能数值、性能曲线或优势幅度为目标，不复现原论文的实验框架和系统平台。** 本节优先于旧任务、旧需求文档中不一致的研究目标与范围；下方强制干净构建及运行前验证门禁继续有效。

- **固定当前平台**：沿用 gem5-gpu / flexible Garnet / VI_hammer、当前 CPU/GPU/缓存系统、64-tile 布局、Docker 环境和现有应用。与 `gem5-gpu-bak`、`gem5-gpu-tbp` 比较时对齐实际配置、端点映射、输入和测量口径。不得为复现论文而迁移 Noxim、搭建 SNN/神经形态平台、复制原文数据集或重建其 RTL/工艺实验流程。
- **允许必要的 NoC 内部改造**：独立子网、链路位宽、buffer/VC、仲裁、电源状态和 NI relay 属于待复现方法本身，不等于更换系统平台。改动须集中、可解释，按实际链路容量和存储位数核算资源；不能为了少改代码，把关键资源竞争或时序效果仅替换成标签和事后统计修正。
- **核心机制优先**：独立常开 dual-line 与 PG Mesh 子网；真实宽窄 flit 与序列化/反序列化；拥塞驱动的动态子网选择；PG 唤醒与转换代价；静态 long-link、crossbar bypass 和有界 relay；Algorithm 1 的单调路径限制与 Algorithm 2 的 Hilbert 分层插入。不能仅实现 Hilbert 路由就称完成 HetSub。
- **验收机制，不验收论文收益**：检查机制是否在实际数据路径中生效、消息守恒与正确交付、顺序和流控、资源约束、时序、排空和应用正确性。不得要求达到原文的 38% 延迟改善、58% 静态功耗降低、16% 面积节省，或要求优于 bak/TBP。不为贴合原文曲线调整平台、挑选结果或反复调参。
- **允许在当前平台测量性能**：用于客观比较和解释机制，保留负收益与适用边界；“不复现性能”不意味着免测服务时间、带宽、拥塞和唤醒代价。当前 CPU/GPU 工作负载下的结果是方法迁移评估，不是原文 SNN 实验的复现。
- **明确完成度**：报告“已实现／近似／未实现”的逐项机制清单及测试证据。近似和缺失必须进入结论，不用主观相似度百分比或原文结果替代证据；未实现的核心机制不能静默省略后宣称完成。
- **禁止过度工程化、过度哈希**：优先复用现有类、脚本和测试入口，不新增通用调度平台、插件体系、在线重配置或无关重构。只保留现有强制源码/二进制构建凭据，不新增逐包/CSV/图表哈希、哈希链或登记数据库。

实施方案优先参考 [固定平台下的忠实复现方案](docs/HETSUB_FAITHFUL_PLATFORM_PLAN.md)，具体文件范围与阶段验收写入 `.ai/tasks/TASK.md`。共享 Mesh 的旧最小适配方案仅作受限退路，不可当成独立双子网已经复现的证据。方案中的性能比较矩阵服务于当前平台评估，不扩张为重建原论文实验体系。

## Handoff Files

- Task spec: `.ai/tasks/TASK.md`
- Execution report: `.ai/reports/REPORT.md`
- Review findings: `.ai/reviews/REVIEW.md`

## Review Expectations

- Findings first: bugs, regressions, missing validation, or scope drift.
- Keep architecture changes explicit.
- Approve only when the task acceptance criteria and test evidence are satisfied.

## Repo-Specific Notes

- Current active task branch: `synthetic-traffic-three-patterns`
- Synthetic traffic execution must run inside the dedicated Docker container `gem5gpu-dev-hetsub` (image `myubuntu14:latest`), with `/home/siat/gem5-gpu-hetsub` explicitly bind-mounted at the same path. This replaces the earlier shared-container requirement by user instruction. Official clean builders may use temporary build containers with the same explicit project bind.
- Host execution of `gem5/build/X86_Network_test/gem5.opt` is not a valid verification path here because the host runtime is missing `libpython2.7.so.1.0`

## 阶段性检查与确认前必须推送 GitHub

用户工作流程：**每次请用户检查阶段性成果或确认配置、范围等事项前，必须先提交并推送当前成果到 GitHub，核对远端提交，并提供可直接查看的链接。** 此规则也适用于实施中、部分验收通过或等待确认的检查点；提交与报告须明确未完成项，不把阶段性备份称为最终验收通过。

沿用下方 SSH Backup Workflow：先运行 `./push_all_repos.sh --check`；如检查指出工作区未提交或远端尚未同步，保留并报告该事实，再按已授权流程提交、依次推送嵌套仓库和父仓库，最后再次检查远端 SHA 与父仓 gitlink。不得强推覆盖远端。若推送失败，明确失败原因，不将未推送的本地状态当作已可供 GitHub 检查的成果。源码/二进制构建门禁继续约束后续实验；GitHub 备份不代表缺失测试已经通过。

## SSH Backup Workflow

Use GitHub through the `github-miuzujia` SSH alias and
`~/.ssh/id_ed25519_miuzujia2018_stack`; never put passwords or HTTPS
credentials in a push script. Run `./push_all_repos.sh --check` before
`./push_all_repos.sh`. Nested repositories are pushed first, their remote
commit IDs are verified, parent gitlinks are updated, and the parent is pushed
last.

| Repository | Branch |
|---|---|
| `gem5-gpu-hetsub` parent | `synthetic-traffic-three-patterns` |
| central `gem5` | `gem5-gpu-hetsub` |
| `gem5-gpu`, `gpgpu-sim`, `Graphite` | `gem5-gpu-hetsub` |
| `benchmarks` | `gem5-gpu-hetsub` |

## Mandatory Clean-Build Provenance Gate (Highest Priority)

This section overrides any earlier build or manual-SCons guidance in this file.
Its purpose is to prevent an experiment from silently running a `gem5.opt`
that predates the active source tree.

- After any change under `gem5/`, `gem5-gpu/`, or `gpgpu-sim/` that can affect
  the simulator or a runtime configuration, do not run or accept an experiment
  until the corresponding verified Docker build succeeds.
- For `X86_VI_hammer_GPU`, use the repository's top-level official builder:
  `./docker_build_and_test_tbp.sh` in the TBP repository and
  `./docker_build_and_test_j64.sh` everywhere else.
- For `X86_Network_test`, use
  `./tools/reproduction/docker_build_network_test.sh`.
- The official builders must bind the current project tree explicitly, remove
  only the exact target build directory, perform a clean rebuild, record the
  source and binary SHA-256 credential, verify it, and then run the required
  tests. A failed build must not fall through to tests with an older binary.
- A direct `scons ... gem5.opt` command is diagnostic only. It does not satisfy
  this gate and must not be used to certify or publish experimental results.
- Before every simulator run, require
  `tools/reproduction/verify_gem5_build.sh verify <project-root> <build-name>`.
  `run.sh` and the supported Python entry configurations already enforce this.
  Missing or mismatched credentials are fatal (exit 42); rebuild instead of
  bypassing, editing, or manually re-recording the credential.
- If a new launcher or configuration invokes `gem5.opt`, it must call the same
  verifier before simulation. A custom unguarded entry point is not an
  authorized experimental path.
- Formal experiment metadata must retain the source fingerprint, binary hash,
  build target, build log, configuration, and command. Historical results that
  lack enough information to identify the binary must be labeled unverified
  rather than assumed to match the current source.
- Documentation-only changes outside the three fingerprinted source
  repositories do not require a simulator rebuild. Runtime configuration
  changes inside those repositories do invalidate the credential.

The local `.build_provenance/` credential directory is intentionally ignored
by Git; it is a runtime safety gate, not a replacement for committed source,
tracked experiment manifests, or preserved build/test evidence.
