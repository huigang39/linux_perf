#!/bin/bash

usage() {
    echo "Usage: $0 [-n <NIC> <NIC_CPU>] [-t <THREAD> <THREAD_CPU>]"
    echo "Examples:"
    echo "  Only NIC binding:   $0 -n enp2s0 3"
    echo "  Only thread binding: $0 -t test 2-4"
    echo "  Both:               $0 -n enp2s0 3 -t test 2-4"
    exit 1
}

# Check if no arguments provided
if [ $# -eq 0 ]; then
    usage
fi

# Initialize variables
NIC=""
NIC_CPU=""
THREAD=""
THREAD_CPU=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -n)
            # Check that there are at least two more parameters
            if [ $# -lt 3 ]; then
                usage
            fi
            NIC="$2"
            NIC_CPU="$3"
            shift 3
            ;;
        -t)
            if [ $# -lt 3 ]; then
                usage
            fi
            THREAD="$2"
            THREAD_CPU="$3"
            shift 3
            ;;
        *)
            usage
            ;;
    esac
done

# At least one functionality must be provided
if [ -z "$NIC" ] && [ -z "$THREAD" ]; then
    usage
fi

sudo systemctl stop irqbalance    # 停止服务
sudo systemctl disable irqbalance # 禁止开机自启

# --- NIC Binding Section ---
if [ -n "$NIC" ] && [ -n "$NIC_CPU" ]; then
    # 获取网卡所有 IRQ
    IRQS=$(awk -v nic="$NIC" '($NF == nic) || ($NF ~ (nic "-TxRx")) {gsub(/:/,"",$1); print $1}' /proc/interrupts)

    if [ -z "$IRQS" ]; then
        echo "[ERROR] No IRQs found for NIC: $NIC"
        echo "Available NIC IRQs:"
        awk '/^ *[0-9]+:/ {if($NF ~ /-TxRx-/) print $1,$NF}' /proc/interrupts
        exit 1
    fi

    echo -e "\n[1] Isolating CPU$NIC_CPU for NIC IRQs..."
    sudo tuna --cpus="$NIC_CPU" --isolate

    echo -e "\n[2] Binding NIC IRQs for $NIC to CPU$NIC_CPU..."
    for irq in $IRQS; do
        echo "Processing IRQ $irq:"
        sudo tuna --irqs="$irq" --cpus="$NIC_CPU" --move
        sudo tuna --irqs="$irq" --show_irqs | grep -v '======'
    done

    echo -e "\nNIC binding completed:"
    echo "NIC: $NIC"
    echo "NIC IRQs: $(echo $IRQS | tr '\n' ' ')"
    echo "NIC CPU: $NIC_CPU"
fi

# --- Thread Binding Section ---
if [ -n "$THREAD" ] && [ -n "$THREAD_CPU" ]; then
    echo -e "\n[Thread] Binding threads '$THREAD' to CPU$THREAD_CPU..."
    sudo tuna --threads="$THREAD" --cpus="$THREAD_CPU" --move
    sudo tuna --threads="$THREAD" --show_threads | grep -E "pid|$THREAD"
    echo -e "\nThread binding completed:"
    echo "Thread: $THREAD"
    echo "Thread CPU: $THREAD_CPU"
fi
