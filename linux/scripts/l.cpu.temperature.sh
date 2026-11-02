#!/bin/bash
set -u

if [[ -d /host/sys/class/thermal ]]; then
    SYS=/host/sys
else
    SYS=/sys
fi

max=""
for f in "$SYS"/class/thermal/thermal_zone*/temp; do
    [[ -r "$f" ]] || continue
    t=$(<"$f")
    [[ "$t" =~ ^[0-9]+$ ]] || continue
    if [[ -z "$max" || "$t" -gt "$max" ]]; then
        max=$t
    fi
done

if [[ -n "$max" ]]; then
    echo $(( max / 1000 ))
else
    echo "unknown"
fi