#!/usr/bin/env bash
# 生成 GitHub Release 说明。由 build_corvette.yml 的 release job 调用。
#
# 需要的工作目录环境变量（workflow 已 export）：
#   FULL_VERSION    UTS_RELEASE，如 6.1.141-android14-11-o-gf421ce937631-v4.2.1-866-gb16e8-cb
#   TIME_FORM       构建时间
#   SOURCE_BRANCH   内核源码分支
#   KSU_REF         SukiSU 分支（builtin / main / ...）
#   KSU_BRANCH      显示名
#   KSU_VER         KernelSU 版本号
#   LZ4KD / LZ4 / SSG / REKERNEL / BETTER_NET / BBR / KPM / BASEGUARD   功能的 true/false
#
# 用法：bash gen_release_notes.sh [输出文件]   默认 release_notes.md

set -u
OUT="${1:-release_notes.md}"

# 只列出开启的功能，避免十几行 true/false 噪音
FEATS=""
add_feat() { FEATS="${FEATS}- $1"$'\n'; }
[ "${LZ4:-false}"        = "true" ] && add_feat "LZ4 压缩"
[ "${LZ4KD:-false}"      = "true" ] && add_feat "LZ4KD（zram 需先关闭）"
[ "${BETTER_NET:-false}" = "true" ] && add_feat "网络功能增强"
[ "${BBR:-false}"        = "true" ] && add_feat "BBR / Brutal 拥塞控制"
[ "${SSG:-false}"        = "true" ] && add_feat "三星 SSG IO 调度器"
[ "${REKERNEL:-false}"   = "true" ] && add_feat "Re-Kernel"
[ "${KPM:-false}"        = "true" ] && add_feat "KPM 内核模块"
[ "${BASEGUARD:-false}"  = "true" ] && add_feat "内核级基带保护"
[ -z "$FEATS" ] && FEATS="- （无额外功能项）"$'\n'

# 内核版本与 KSU 版本从 UTS_RELEASE 里拆出来，表格里更好读
KREL="${FULL_VERSION:-unknown}"
KSU_TAG=""
case "$KREL" in
  *-v[0-9]*-g[0-9a-f]*-*) KSU_TAG="${KREL##*-v}"; KSU_TAG="v${KSU_TAG%-*}" ;;
esac
KREL_BASE="${KREL%%-v*}"

# 产物 md5（有就写，没有就略过）
MD5=""
for f in release_zips/AnyKernel3_*.zip; do
  [ -f "$f" ] && MD5="$(md5sum "$f" | cut -d' ' -f1)" && break
done

{
  echo "# 一加 Ace 3 Pro（corvette / PJX110）· 6.1 内核"
  echo
  if [ "${KSU_REF:-}" = "builtin" ]; then
    echo "给 ColorOS 16 用的 SukiSU 内核。这一版走 **builtin** 路线：提权在内核源码里直接调用"
    echo '`ksu_handle_execveat_sucompat`，不经过 LSM。'
  else
    echo "给 ColorOS 16 用的 SukiSU 内核。这一版走 **${KSU_REF:-unknown}** 路线。"
  fi
  echo
  echo "## 构建信息"
  echo
  echo "| 项目 | 值 |"
  echo "| --- | --- |"
  echo "| 内核 | \`${KREL_BASE}\` |"
  echo "| Root | ${KSU_BRANCH:-SukiSU} \`${KSU_VER:-?}\` · ${KSU_TAG:-?} · \`${KSU_REF:-?}\` |"
  echo "| 源码 | \`${SOURCE_BRANCH:-?}\` |"
  echo "| 构建 | ${TIME_FORM:-?} (UTC+8) |"
  echo "| 刷入 | \`boot\`（当前 slot，不改 init_boot） |"
  [ -n "$MD5" ] && echo "| md5 | \`${MD5}\` |"
  echo

  if [ "${KSU_REF:-}" = "builtin" ]; then
    echo "## 本版改动"
    echo
    echo "从运行时 hook 换成源码级 hook："
    echo
    echo "| | 旧版 | 本版 |"
    echo "| --- | --- | --- |"
    echo "| 提权路径 | LSM \`task_fix_setuid\` | 源码直调 \`execveat_sucompat\` |"
    echo "| kprobes / tracepoint | 有 | 无 |"
    echo "| 15 秒复位 | 有此机制 | 机制不存在 |"
    echo "| LSM 剩余职责 | 提权 + 隐藏 | 仅 mount 隐藏 |"
    echo
    echo "依据：对内核镜像恢复 kallsyms（111753 条符号）后反汇编各 syscall 入口，"
    echo "逐条核对 \`bl\` 目标偏移与符号表地址一致；同时确认 \`ksu_task_fix_setuid\` 未参与编译。"
    echo
  fi

  echo "## 已启用"
  echo
  echo "- SUSFS（mount 隐藏 / stat 隐藏）"
  printf '%s' "$FEATS"
  echo

  echo "## 刷之前先备份"
  echo
  echo "**本机没有 pstore、没有 ramoops、没有 last_kmsg** —— 刷坏后拿不到 panic 日志，"
  echo "只能靠屏幕现象判断问题。先备份 boot："
  echo
  echo '```bash'
  echo "dd if=/dev/block/by-name/boot_a of=/sdcard/boot_a_backup.img"
  echo '```'
  echo
  echo "崩了就把这个 img 刷回 \`boot_a\`。"
  echo
  echo "## 安装"
  echo
  echo "1. **TWRP / 第三方 Recovery** —— 刷入本 zip，重启"
  echo "2. **已有 root** —— 用 [HorizonKernelFlasher](https://github.com/libxzr/HorizonKernelFlasher/releases) 刷入，重启"
  echo "3. **已装 SukiSU 管理器** —— 管理器内直接刷入，重启"
  echo
  if [ "${LZ4KD:-false}" != "true" ]; then
    echo "之前刷过 LZ4KD 版本的话，先关掉 zram 再刷本版。"
    echo
  fi
  echo "## 管理器"
  echo
  echo "- [SukiSU Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra/releases)"
  echo "- [KernelSU Next](https://github.com/KernelSU-Next/KernelSU-Next/releases)"
} > "$OUT"

printf 'release notes -> %s (%s 行)\n' "$OUT" "$(wc -l < "$OUT")"
