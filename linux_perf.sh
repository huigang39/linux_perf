#!/bin/bash

# 使用方法: 
# sudo ./linux_perf.sh <网卡名称> <IRQ绑定的CPU> <线程名> <线程绑定的CPU>
# 示例: 
# sudo ./linux_perf.sh ens3p0 3 test 2-4

# 参数检查
if [ $# -ne 4 ]; then
    echo "Usage: $0 <NIC> <NIC_CPU> <THREAD> <THREAD_CPU>"
    echo "Example: $0 ens3p0 3 test 2-4"
    exit 1
fi

NIC="$1"
NIC_CPU="$2"
THREAD="$3"
THREAD_CPU="$4"

# 获取网卡所有 IRQ
IRQS=$(awk -v nic="$NIC" '$NF == nic {gsub(/:/,"",$1); print $1}' /proc/interrupts)

if [ -z "$IRQS" ]; then
    echo "[ERROR] No IRQs found for NIC: $NIC"
    echo "Available NIC IRQs:"
    awk '/^ *[0-9]+:/ {if($NF ~ /-TxRx-/) print $1,$NF}' /proc/interrupts
    exit 1
fi

# 隔离 NIC IRQ 专用 CPU
echo -e "\n[1/3] Isolating CPU$NIC_CPU ..."
sudo tuna --cpus="$NIC_CPU" --isolate

# 绑定网卡中断
echo -e "\n[2/3] Binding NIC IRQs to CPU$NIC_CPU ..."
for irq in $IRQS; do
    echo "Processing IRQ $irq:"
    sudo tuna --irqs="$irq" --cpus="$NIC_CPU" --move
    sudo tuna --irqs="$irq" --show_irqs | grep -v '======'
done

# 绑定应用线程
echo -e "\n[3/3] Binding threads '$THREAD' to CPU$THREAD_CPU ..."
sudo tuna --threads="$THREAD" --cpus="$THREAD_CPU" --move
sudo tuna --threads="$THREAD" --show_threads | grep -E "pid|$THREAD"

echo -e "\nOperation completed:"
echo "NIC $NIC IRQs: $(echo $IRQS | tr '\n' ' ')"
echo "NIC CPU: $NIC_CPU"
echo "Thread CPU: $THREAD_CPU"
