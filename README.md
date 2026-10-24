# corvette 内核编译（一加 Ace 3 Pro / PJX110 / SM8650）

基于 [cctv18/oppo_oplus_realme_sm8650](https://github.com/cctv18/oppo_oplus_realme_sm8650)（QinJackson/oplus-ace3pro_sm8650 同源）的 make + Clang20 流程裁剪，专编 corvette。**不用绿厂官方 Bazel**。

- OKI 模式（一加官方源码）+ make + LLVM/Clang20，带 ccache（首次约 22min，二次约 6min）
- SukiSU Ultra (susfs-main) / KernelSU Next 可选，manual hooks 默认
- 产物：AnyKernel3 直刷 zip（Release + Artifacts 双份）

## 源码分支（均在 cctv18 打包源码仓库内）

| 选项 | 分支 | 对应系统 |
|---|---|---|
| **默认** | `oneplus/sm8650_u_14.1.0_oneplus_ace3pro` | ColorOS 14.1 (Android 14) |
| 可选 | `oneplus/sm8650_v_15.0.0_ace_3_pro` | ColorOS 15 (Android 15) |

两者内核均为 **6.1.75**。

## ⚠️ 刷机前必查

1. `adb shell uname -r` 看当前内核完整版本号（形如 `6.1.75-android14-11-o-g<后缀>`）
2. 与默认后缀 **`android14-11-o-g1132d864665d`**（取自 lai1285/OnePlusAce3Pro_MKSU_SUSFS）**不一致时**，触发 workflow 时在 `kernel_suffix` 填入手机的真实后缀（开头不要加连字符）
3. 后缀不匹配 → vendor 模块 vermagic 校验失败 → **不开机**
4. 刷前用 KernelFlasher/TWRP **备份 boot**

## 功能配置

触发参数默认值已按需求调好：

- `bbr_enable=default`：BBR 设为默认拥塞算法（同时编入 CUBIC/Vegas/Westwood/HTCP/Brutal）
- `better_net=true`：IP_SET 全家桶 + XT_SET（IP6_NF_NAT 的 vintf 检测问题已由 config.patch 处理）
- **恒开**（workflow 内置步骤）：`CONFIG_KSM=y`、`CONFIG_ZSTD_COMPRESS=y`、`CONFIG_ZSTD_DECOMPRESS=y`、`CONFIG_MQ_IOSCHED_KYBER=y`
- **内核源码自带**（勿重复加）：`CONFIG_UCLAMP_TASK=y`、`CONFIG_NET_SCH_FQ=y`
- 默认关：SSG 调度器（在一加12上致不开机，corvette 未验证）、Re-Kernel、Baseband-guard、KPM —— 首次编译尽量少变量，稳定后可自行开启

## 使用步骤

1. Actions → 「corvette (一加Ace3Pro) 6.1.75 OKI内核」→ Run workflow
   - `source_branch` 按手机系统选（14.1 默认 / 15）
   - `kernel_suffix` 通常留空（见上方必查）
2. 等 20-60 分钟，产物在 Release 和 Artifacts
3. 产物验证：AK3 包应含 `META-INF/`、`anykernel.sh`、`Image`，**不含 dtbo**
4. 刷入：TWRP / HorizonKernelFlasher / SukiSU 管理器
5. 验证：
   ```bash
   adb shell uname -r                                    # 6.1.75-android14-11-o-g1132d864665d（或你填的后缀）
   adb shell cat /proc/sys/net/ipv4/tcp_available_congestion_control   # 含 bbr
   adb shell cat /proc/sys/net/ipv4/tcp_congestion_control             # bbr
   adb shell zcat /proc/config.gz | grep -E 'TCP_CONG_BBR|KSM=|ZSTD_COMPRESS|MQ_IOSCHED_KYBER'
   ```

## 救砖

fastboot 刷回备份的 boot.img（boot_a / boot_b 都刷）。

## 维护说明

- workflow 从 `fastbuild_6.1.75.yml` 程序化生成（17 处确定性替换），源 fork 在本地 `偏移量/work/corvette-qinjackson/`
- 编译动作全部来自上游 cctv18 项目，本项目只改了：源码分支、ccache 命名、KSM/ZSTD/Kyber 步骤、参数默认值、Release 文案
