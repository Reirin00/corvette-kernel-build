#!/usr/bin/env bash
# 抢抓 corvette 重启循环的 panic 现场（adb 已可用，serial a1cd0e58）
set -u
U=/usr/lib/UotanToolbox/Bin/platform-tools/adb
OUT=/home/reirin/WorkBuddy/偏移量/work/corvette-debug/hot
mkdir -p "$OUT"

"$U" start-server >/dev/null 2>&1
hit=0
for i in $(seq 1 600); do
  L=$("$U" devices 2>/dev/null | awk 'NR>1 && $2=="device"{print $1; exit}')
  if [ -n "${L:-}" ]; then
    hit=$((hit+1)); TS=$(date +%H%M%S)
    echo "[$((i))] #$hit 命中 $L  $TS"
    timeout 3 "$U" shell 'echo "uptime=$(cat /proc/uptime)"; echo "kernel=$(uname -r)"; echo "bootreason=$(getprop ro.boot.bootreason)"; echo "boot_completed=$(getprop sys.boot_completed)"' 2>/dev/null | tee "$OUT/info_$TS.txt"
    timeout 5 "$U" shell 'su -c "cat /sys/fs/pstore/console-ramoops-0"' > "$OUT/pstore_$TS.txt" 2>/dev/null
    timeout 4 "$U" shell 'dmesg' > "$OUT/dmesg_$TS.txt" 2>/dev/null
    SZ=$(stat -c%s "$OUT/pstore_$TS.txt" 2>/dev/null || echo 0)
    DSZ=$(stat -c%s "$OUT/dmesg_$TS.txt" 2>/dev/null || echo 0)
    echo "     pstore=${SZ}B dmesg=${DSZ}B"
    if [ "${SZ:-0}" -gt 2000 ]; then
      echo "=== pstore 关键行 ==="
      grep -nE "Unable to handle|Internal error|Kernel panic|BUG:|Call trace|PC is at|watchdog|SError|pc :|lr :|CPU: [0-9]" "$OUT/pstore_$TS.txt" | tail -25
      echo "=== 文件: $OUT/pstore_$TS.txt ==="
      exit 0
    fi
    sleep 2
  else
    sleep 0.5
  fi
done
echo "结束，命中 $hit 次"
