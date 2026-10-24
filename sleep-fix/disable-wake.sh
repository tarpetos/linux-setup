#!/bin/bash
# Disable problematic wakeups (PCIe bridges, GPU, Ethernet) but leave USB (mouse/keyboard) enabled
for dev in GP12 GPP0 GPP8 PT24 PT29; do
    if grep -q "^$dev.*enabled" /proc/acpi/wakeup; then
        echo $dev > /proc/acpi/wakeup
    fi
done
