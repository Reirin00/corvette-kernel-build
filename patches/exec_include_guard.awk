#!/usr/bin/awk -f
# 把 50 号补丁里 fs/exec.c 段的 susfs_def.h include 改写成幂等版本。
#
# 原始:  +#ifdef CONFIG_KSU_SUSFS / +#include <linux/susfs_def.h> / +#endif
# 改为:  +#ifndef KSU_SUSFS_DEF_H / 原三行 / +#endif // KSU_SUSFS_DEF_H
#
# 关键: 多插 2 行会把 patch 判成 malformed, 所以必须同步把所在 hunk 的
# 旧/新行数各加 2 —— 这里按"hunk 体实际行数"重算, 不靠人工数。
{ lines[NR] = $0 }
END {
    inblk = 0
    hit = 0
    for (i = 1; i <= NR; i++) {
        if (lines[i] ~ /^diff --git a\/fs\/exec\.c /) { inblk = 1 }
        if (inblk == 1 && lines[i] ~ /^\+#ifdef CONFIG_KSU_SUSFS$/ &&
            lines[i+1] ~ /^\+#include <linux\/susfs_def\.h>$/ &&
            lines[i+2] ~ /^\+#endif$/ && hit == 0) {
            hit = i
            break
        }
    }
    if (hit == 0) {
        print "ERR: 找不到 exec.c 的 susfs_def.h include 三行" > "/dev/stderr"
        exit 2
    }

    # 1) 先输出, hit 处扩成五行
    n = 0
    for (i = 1; i <= NR; i++) {
        n++
        out[n] = lines[i]
        if (i == hit) {
            out[n] = "+#ifndef KSU_SUSFS_DEF_H"
            n++; out[n] = lines[i]
            n++; out[n] = lines[i+1]
            n++; out[n] = lines[i+2]
            n++; out[n] = "+#endif // KSU_SUSFS_DEF_H"
            i += 2
        }
    }

    # 2) 找到 hit 所属 hunk 头(向上找 @@), 按实际内容重算行数
    h = 0
    for (i = 1; i <= hit; i++) if (out[i] ~ /^@@ /) h = i
    if (h == 0) { print "ERR: 找不到所属 hunk 头" > "/dev/stderr"; exit 3 }
    # hunk 体: h+1 .. (下一个 @@ 或 diff --git 之前)
    oh = 0
    for (i = h + 1; i <= n; i++) {
        if (out[i] ~ /^@@ / || out[i] ~ /^diff --git /) break
        if (out[i] ~ /^\+/) nh++
        else oh++
    }
    # old 计数 = 非 '+' 行; new 计数 = 全部行
    oldc = oh
    newc = oh + nh
    match(out[h], /^@@ -[0-9,]+ \+[0-9,]+ @@/)
    ctx = substr(out[h], RLENGTH + 1)
    split(out[h], parts, " ")
    # 保留原起始行号
    start_old = substr(parts[2], 2)
    sub(/,.*/, "", start_old)
    start_new = substr(parts[3], 2)
    sub(/,.*/, "", start_new)
    out[h] = "@@ -" start_old "," oldc " +" start_new "," newc " @@" ctx

    for (i = 1; i <= n; i++) print out[i]
    print "OK hit=" hit " hunkline=" h " old=" oldc " new=" newc > "/dev/stderr"
}
