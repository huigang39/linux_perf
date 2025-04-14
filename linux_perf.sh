#!/bin/bash

CPU=$1

IRQS=(161 162 163 164 165)

for irq in "${IRQS[@]}"; do
    sudo bash -c "echo $CPU > /proc/irq/$irq/smp_affinity"
    cat /proc/irq/$irq/smp_affinity | xxd -b
done
