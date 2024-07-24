sudo bash -c "echo $1 | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor" && cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
