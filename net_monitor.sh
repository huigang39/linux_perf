#!/bin/bash

nic_statistics_info() {

cat << 'EOF'
# ---------------------------------------------------------------------------- #
#                                NIC statistics                                #
# ---------------------------------------------------------------------------- #
EOF

  NIC=$1

  for f in $(ls /sys/class/net/$NIC/statistics/); do
        TAG="$f: ";
        VAL=$(cat /sys/class/net/$NIC/statistics/$f 2>/dev/null);
        echo $TAG $VAL;
    done
}

hardirqs_info() {

cat << 'EOF'
# ---------------------------------------------------------------------------- #
#                              Hardware Interrupts                             #
# ---------------------------------------------------------------------------- #
EOF

  NIC=$1

  egrep "$NIC" /proc/interrupts | awk \
    '{ for (i=2;i<=NF-3;i++) sum[i]+=$i; }
     END {
      for (i=2;i<=NF-3; i++) {
        tags=sprintf("cpu_%d: ", i-2);
        printf(tags sum[i] "\n");
      }
     }'

  egrep "$NIC" /proc/interrupts | awk \
    '{ for (i=2;i<=NF-3; i++)
        sum+=$i;
        tags=sprintf("%s_queue: ", $NF);
        printf(tags sum "\n");
        sum=0;
      }'
}

softirqs_info(){

cat << 'EOF'
# ---------------------------------------------------------------------------- #
#                              Software Interrupts                             #
# ---------------------------------------------------------------------------- #
EOF

for dir in "NET_RX" "NET_TX"; do
  grep $dir /proc/softirqs | awk -v dir=$dir \
    '{ for (i=2;i<=NF-1;i++) {
          tags=sprintf("cpu_%d_%s: ", i-2, dir); \
          printf(tags $i "\n"); \
        }
      }'
  done
}

softnet_stat_info()
{

  if [[ -z "${SOFTNET_HEADER_PRINTED+x}" ]]; then
cat << 'EOF'
# ---------------------------------------------------------------------------- #
#                            Kernel Processing Drops                           #
# ---------------------------------------------------------------------------- #
EOF
    declare -g SOFTNET_HEADER_PRINTED=1
  fi

  TYP=$1
  IDX=$2

  TAG="$TYP: ";
  VAL=$(cat /proc/net/softnet_stat | awk -v IDX="$IDX" '{sum+=strtonum("0x"$IDX);} END{print sum;}')

  echo $TAG $VAL;
}

net_stat_info()
{

  if [[ -z "${SOFTNET_HEADER_PRINTED+x}" ]]; then
cat << 'EOF'
# ---------------------------------------------------------------------------- #
#                            TCP Abnormal Statistics                           #
# ---------------------------------------------------------------------------- #
EOF
    declare -g SOFTNET_HEADER_PRINTED=1
  fi

  PATTERN=$1
  ARG_IDX=$2

  VAL=$(netstat -s | grep "$PATTERN" | awk -v i=$ARG_IDX '{print $i}')
  TYP=$(echo "$PATTERN" | tr ' ' '_' | sed 's/\$//g')

  TAG="$TYP: ";
  echo $TAG $VAL;
}


NIC=$1

nic_statistics_info $NIC
hardirqs_info $NIC
softirqs_info $NIC

softnet_stat_info "dropped" 2
softnet_stat_info "time_squeeze" 3
softnet_stat_info "cpu_collision" 9
softnet_stat_info "received_rps" 10
softnet_stat_info "flow_limit_count" 11

net_stat_info "segments retransmited" 1
net_stat_info "TCPLostRetransmit" 2
net_stat_info "fast retransmits$" 1
net_stat_info "retransmits in slow start" 1
net_stat_info "classic Reno fast retransmits failed" 1
net_stat_info "TCPSynRetrans" 2

net_stat_info "bad segments received" 1
net_stat_info "resets sent$" 1
net_stat_info "connection resets received$" 1

net_stat_info "connections reset due to unexpected data$" 1
net_stat_info "connections reset due to early user close$" 1
