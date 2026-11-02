#!/bin/bash
set -u
export LC_ALL=C

SN=$(printf '%s' "${1:-}" | tr -d ' \t\r\n')
INTERVAL="${INTERVAL:-1}"
SYS=/sys
[ -d /host/sys/block ] && SYS=/host/sys

fail() { jq -cn --arg e "$1" '{error:$e}'; exit 1; }
[ -n "$SN" ] || fail "serial number not specified"

# Находим устройство по серийнику через smartctl.
# NVMe-контроллер nvme0 сопоставляем с namespace nvme0n1.
DISK=""
while read -r dev args; do
    sn=$(smartctl -i $dev $args 2>/dev/null | awk -F': *' '/^Serial [Nn]umber/ {print $2; exit}' | tr -d ' \r')
    [ "$sn" = "$SN" ] || continue
    name=${dev##*/}
    if [ -d "$SYS/block/$name" ]; then
        DISK=$name
    else
        DISK=$(ls -d "$SYS/block/${name}n"* 2>/dev/null | head -n1 | xargs -r basename)
    fi
    break
done < <(smartctl --scan 2>/dev/null | sed 's/#.*//')

[ -n "$DISK" ] || fail "disk not found"
STAT="$SYS/block/$DISK/stat"
[ -r "$STAT" ] || fail "stat not readable for $DISK"

# Поля stat: 1 reads, 4 ms reading, 5 writes, 8 ms writing, 10 io_ticks, 11 weighted ms in queue
read_stat() { awk '{print $1, $4, $5, $8, $10, $11}' "$STAT"; }

S1=$(read_stat); T1=$(date +%s%N)
sleep "$INTERVAL"
S2=$(read_stat); T2=$(date +%s%N)
EL=$(( (T2 - T1) / 1000000 )); [ "$EL" -gt 0 ] || EL=1

read -r util qlen rawait wawait < <(awk -v a="$S1" -v b="$S2" -v el="$EL" 'BEGIN {
    split(a, x, " "); split(b, y, " ")
    dr = y[1]-x[1]; drms = y[2]-x[2]; dw = y[3]-x[3]; dwms = y[4]-x[4]
    dio = y[5]-x[5]; dq = y[6]-x[6]
    util = dio*100/el; if (util > 100) util = 100
    printf "%.2f %.2f %.2f %.2f\n", util, dq/el, (dr>0 ? drms/dr : 0), (dw>0 ? dwms/dw : 0)
}')

jq -nc \
    --argjson a "$util" --argjson q "$qlen" \
    --argjson r "$rawait" --argjson w "$wawait" \
    '{active_time_percent:$a, queue_length:$q, read_await_ms:$r, write_await_ms:$w}'