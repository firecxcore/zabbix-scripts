#!/bin/bash
set -u

if [[ -r /host/proc/cpuinfo ]]; then
    CPUINFO=/host/proc/cpuinfo
else
    CPUINFO=/proc/cpuinfo
fi

awk -F': *' '
    /^model name/ { print $2; found=1; exit }
    /^(Hardware|Processor)/ && !found { print $2; found=1; exit }
    END { if (!found) print "unknown" }
' "$CPUINFO"