#!/bin/bash

CPU=$1

IRQS=(129)

# 隔离 CPU
sudo tuna --cpus=$CPU --isolate

# 将中断绑定到 CPU
for irq in "${IRQS[@]}"; do
    sudo tuna --irqs=$irq --cpus=$CPU --move
    sudo tuna --irqs=$irq --show_irqs
done
