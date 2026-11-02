#!/bin/bash
set -u
export LC_ALL=C

command -v lspci >/dev/null 2>&1 || { echo "unknown"; exit 0; }

# Первый PCI-контроллер класса VGA, 3D или Display, без ревизии
lspci 2>/dev/null \
    | awk -F': ' '/VGA compatible|3D controller|Display controller/ {print $2; exit}' \
    | sed 's/ (rev [^)]*)$//' \
    | grep . || echo "unknown"