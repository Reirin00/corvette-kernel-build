# corvette 内核编译（一加 Ace 3 Pro / PJX110 / SM8650）

基于 [cctv18/oppo_oplus_realme_sm8650](https://github.com/cctv18/oppo_oplus_realme_sm8650)（QinJackson/oplus-ace3pro_sm8650 同源）的 make + Clang20 流程裁剪，专编 corvette。**不用绿厂官方 Bazel**。

- OKI 模式（一加官方源码）+ make + LLVM/Clang20，带 ccache（首次约 22min，二次约 6min）
- SukiSU Ultra (susfs-main) / KernelSU Next 可选，manual hooks 默认
- 产物：AnyKernel3 直刷 zip（Release + Artifacts 双份）
- 版本号 / ccache 键按所选源码分支的 Makefile 动态推导

## 源码分支（source_branch 参数）

| 分支 | 内核 | 对应系统 | 状态 |
|---|---|---|---|
| **默认** `oneplus/sm8650_b_16.0.0_oneplus12_6.1.141` | 6.1.141 | **ColorOS 16** | ✅ 本机实测能开机（见下） |
| `oneplus/sm8650_v_15.0.0_ace_3_pro` | 6.1.75 | ColorOS 15 | 分支已验证存在 |
| `oneplus/sm8650_u_14.1.0_oneplus_ace3pro` | 6.1.75 | ColorOS 14.1 | 分支已验证存在 |

16 代没有 corvette 专用分支（截至 2026-10-25），默认分支是一加12源码的 SM8650 通用内核——cctv18 官方发布同源通用包，本机已实测（用户刷过 6.1.141 与 6.1.145 的通用包均正常开机）。

## 内核版本后缀（关键）

默认后缀 **`android14-11-o-gf421ce937631`** —— 取自本机刷机成功过的包
（`AnyKernel3_SukiSUUltra_40708`，`Linux version 6.1.141-android14-11-o-gf421ce937631`）。

- 刷前仍建议 `adb shell uname -r` 核对：若手机真实后缀不同，触发时把完整后缀填进 `kernel_suffix`（开头不带连字符）
- 后缀不匹配 → vendor 模块 vermagic 校验失败 → **不开机**
- 刷前用 KernelFlasher/TWRP **备份 boot**

## 功能配置

触发参数默认值已按需求调好：

- `bbr_enable=default`：BBR 设为默认拥塞算法（同时编入 CUBIC/Vegas/Westwood/HTCP/Brutal）
- `better_net=true`：IP_SET 全家桶 + XT_SET（IP6_NF_NAT 的 vintf 检测问题已由 config.patch 处理）
- **恒开**（workflow 内置步骤）：`CONFIG_KSM=y`、`CONFIG_ZSTD_COMPRESS=y`、`CONFIG_ZSTD_DECOMPRESS=y`、`CONFIG_MQ_IOSCHED_KYBER=y`
- **内核源码自带**（勿重复加）：`CONFIG_UCLAMP_TASK=y`、`CONFIG_NET_SCH_FQ=y`（14.1/15 分支已验证；141 分支编译日志有 config 预览可确认）
- 默认关：SSG 调度器（一加12上都致不开机）、Re-Kernel、Baseband-guard、KPM —— 首次编译少变量，稳定后自行开启

## 使用步骤

1. Actions → 「corvette (一加Ace3Pro) 6.1 OKI内核」→ Run workflow（参数保持默认即适配 ColorOS 16）
2. 等 20-60 分钟，产物在 Release 和 Artifacts
3. 产物验证：AK3 包应含 `META-INF/`、`anykernel.sh`、`Image`，**不含 dtbo**
4. 刷入：TWRP / HorizonKernelFlasher / SukiSU 管理器
5. 验证：
   ```bash
   adb shell uname -r                                    # 6.1.141-android14-11-o-gf421ce937631
   adb shell cat /proc/sys/net/ipv4/tcp_available_congestion_control   # 含 bbr
   adb shell cat /proc/sys/net/ipv4/tcp_congestion_control             # bbr
   adb shell zcat /proc/config.gz | grep -E 'TCP_CONG_BBR|KSM=|ZSTD_COMPRESS|MQ_IOSCHED_KYBER'
   ```

## 救砖

fastboot 刷回备份的 boot.img（boot_a / boot_b 都刷）。

## 维护说明

- workflow 从 `fastbuild_6.1.75.yml` 程序化生成（21 处确定性替换，v2），源 fork 在本地 `偏移量/work/corvette-qinjackson/`
- 编译动作全部来自上游 cctv18 项目；本项目改了：源码分支参数化、ccache/版本号动态化、KSM/ZSTD/Kyber 步骤、参数默认值、Release 文案
- 待办：网络恢复后核实 cctv18 是否有 6.1.145 分支，有则加入 source_branch 选项
