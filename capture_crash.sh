#!/usr/bin/env bash
# 抓 corvette 刷自定义内核后「到桌面约 15 秒自动重启」的崩溃现场
# 用法: ./capture_crash.sh [抓取轮数，默认 3]
# 说明: 设备 15 秒就重启，必须用 wait-for-device + 极短命令，不能等 shell 交互
set -u
U=/usr/lib/UotanToolbox/Bin/platform-tools/adb
OUT="$(dirname "$0")/../corvette-debug"
mkdir -p "$OUT"
ROUNDS="${1:-3}"

for n in $(seq 1 "$ROUNDS"); do
  echo "======== 第 $n 轮：等待设备 ========"
  umount -l /dev 2>/dev/null; sleep 1
  "$U" kill-server 2>/dev/null; sleep 1
  "$U" start-server 2>/dev/null; sleep 2

  # 最多等 120 秒设备上线
  for i in $(seq 1 60); do
    if "$U" devices 2>/dev/null | grep -qw device; then break; fi
    sleep 2
  done
  "$U" devices 2>/dev/null | tail -n +2 | head -3

  TS=$(date +%H%M%S)
  D="$OUT/round$n-$TS"
  mkdir -p "$D"

  # 1) 上一次启动的 panic 现场（跨重启保留，最关键；pstore 只有 root 可读）
  { timeout 8 "$U" shell 'su -c "cat /sys/fs/pstore/console-ramoops-0" 2>/dev/null' 2>/dev/null
    timeout 8 "$U" shell 'cat /sys/fs/pstore/console-ramoops-0 2>/dev/null' 2>/dev/null
  } | head -c 2000000 > "$D/console-ramoops-0.txt" 2>/dev/null

  # pstore 里可能被拆成多个文件，列出来
  timeout 8 "$U" shell 'su -c "ls -l /sys/fs/pstore/" 2>/dev/null; ls -l /sys/fs/pstore/ 2>/dev/null' > "$D/pstore_ls.txt" 2>/dev/null
  timeout 8 "$U" shell 'su -c "cat /proc/last_kmsg" 2>/dev/null; cat /proc/last_kmsg 2>/dev/null' > "$D/last_kmsg.txt" 2>/dev/null
  # 2) 本次启动的 dmesg 尾部
  timeout 8 "$U" shell 'dmesg 2>/dev/null' > "$D/dmesg.txt" 2>/dev/null
  # 3) 重启原因 / 属性
  timeout 8 "$U" shell 'getprop | grep -iE "boot.reason|boot_completed|sys.boot|ro.boot.verified|ro.boot.flash" 2>/dev/null' > "$D/props.txt" 2>/dev/null
  timeout 8 "$U" shell 'uname -r; cat /proc/uptime' > "$D/minfo.txt" 2>/dev/null
  # 4) userspace 侧线索
  timeout 10 "$U" shell 'ls -t /data/system/dropbox 2>/dev/null | head -20' > "$D/dropbox.log" 2>/dev/null
  # 5) logcat 全缓冲（可能已被清，聊胜于无）
  timeout 15 "$U" logcat -b all -d > "$D/logcat.txt" 2>/dev/null

  echo "--- round$n 抓取结果 ---"
  for f in console-ramoops-0.txt last_kmsg.txt dmesg.txt props.txt minfo.txt dropbox.log logcat.txt; do
    s=$(stat -c%s "$D/$f" 2>/dev/null || echo 0)
    printf "  %-22s %8s bytes\n" "$f" "$s"
  done

  # 若拿到 pstore，直接打印关键片段
  if [ -s "$D/console-ramoops-0.txt" ]; then
    echo "--- panic 关键行 ---"
    grep -nE "Unable to handle|Internal error|BUG:|Kernel panic|Call trace|PC is at|watchdog|Watchdog|SError|esr=|pc :|lr :" \
      "$D/console-ramoops-0.txt" 2>/dev/null | tail -25
    echo "(完整文件: $D/console-ramoops-0.txt)"
    exit 0
  fi
  echo "  未取到 pstore，等下一次重启…"
  sleep 20
done

echo "全部轮次结束，查看 $OUT"
