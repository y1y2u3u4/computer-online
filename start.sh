#!/bin/bash

# 启动SSH服务
echo "启动SSH服务..."
if [ "$(id -u)" != "0" ]; then
    sudo service ssh start || {
        echo "使用sudo启动SSH服务失败，尝试直接启动..."
        sudo /usr/sbin/sshd -D &
    }
else
    service ssh start || {
        echo "直接启动SSH服务失败，尝试使用sshd命令..."
        /usr/sbin/sshd -D &
    }
fi

# 检查SSH服务状态
sleep 2
if pgrep sshd > /dev/null; then
    echo "SSH服务已成功启动"
else
    echo "SSH服务启动失败"
fi

# 添加 hosts 映射
grep -q "127.0.0.1 local.adspower.net" /etc/hosts || echo "127.0.0.1 local.adspower.net" | sudo tee -a /etc/hosts

# 第一层转发：内部IP到本地
socat TCP-LISTEN:52919,fork,reuseaddr TCP:127.0.0.1:52918 2>/tmp/socat.log &

# 获取内部IP并设置RunPod代理配置
INTERNAL_IP=$(hostname -i)
echo "Container internal IP: $INTERNAL_IP:52919" > /tmp/internal_ip.txt

# 设置RunPod代理配置
export RUNPOD_PROXY_CONFIG='{"52919": "'$INTERNAL_IP':52919"}'

# 创建日志目录并设置权限
mkdir -p /home/kasm-user/logs
chown kasm-user:kasm-user /home/kasm-user/logs
chmod 755 /home/kasm-user/logs
touch /home/kasm-user/logs/adspower.log
chown kasm-user:kasm-user /home/kasm-user/logs/adspower.log
chmod 644 /home/kasm-user/logs/adspower.log

# 启动 AdsPower 无头浏览器
sudo runuser -l kasm-user -c 'cd "/opt/AdsPower Global" && DISPLAY=:1 ./adspower_global --no-sandbox --headless=true --api-key=ab5ffb76b4a5870bbeaa6a406bbf483d --api-port=50325' 2>/home/kasm-user/logs/adspower.log &

# 等待服务启动
sleep 5

# 检查服务状态
if ! curl -s http://local.adspower.net:50325/status > /dev/null; then
    echo "AdsPower 启动失败"
    echo "socat 日志:"
    cat /tmp/socat.log
    echo "AdsPower 日志:"
    cat /home/kasm-user/logs/adspower.log
fi

# 输出端口转发信息
echo "AdsPower API running on port 50325"
echo "Port forwarding: 52919 -> 50325"

# 克隆和安装smartrpa_backgroud_new
echo "开始安装smartrpa_backgroud_new..."
cd /home/kasm-user
if [ -d "smartrpa_backgroud_new" ]; then
    echo "smartrpa_backgroud_new 目录已存在，正在更新最新代码..."
    cd smartrpa_backgroud_new
    git fetch
    git reset --hard origin/main  # 假设主分支是 main，如果是 master 或其他分支请相应修改
    git pull
else
    echo "克隆 smartrpa_backgroud_new 仓库..."
    git clone https://github.com/y1y2u3u4/smartrpa_backgroud_new.git
    cd smartrpa_backgroud_new
fi

# 升级Node.js
sudo npm install -g n
sudo n stable
PUPPETEER_SKIP_DOWNLOAD=true /usr/local/bin/npm install

# 获取CPU使用率
get_cpu_usage() {
    top -l 1 | grep "CPU usage" | awk '{print $3}' | cut -d'%' -f1
}

# 获取内存使用率
get_memory_usage() {
    memory_pressure=$(memory_pressure | grep "System-wide memory free percentage" | awk '{print $5}')
    echo "$((100 - memory_pressure))"
}

# 监控资源使用情况并在必要时重启服务
monitor_and_restart() {
    local pid=$1
    while true; do
        cpu_usage=$(get_cpu_usage)
        memory_usage=$(get_memory_usage)
        
        echo "$(date '+%Y-%m-%d %H:%M:%S') - CPU使用率: ${cpu_usage}%, 内存使用率: ${memory_usage}%"
        
        if [ "${cpu_usage%.*}" -gt 95 ] || [ "${memory_usage%.*}" -gt 95 ]; then
            echo "资源使用率过高（CPU: ${cpu_usage}%, 内存: ${memory_usage}%），正在重启服务..."
            kill -15 $pid
            return 1
        fi
        
        sleep 300
    done
}

# 清理旧的日志文件，只保留最近5个
cleanup_logs() {
    cd /home/kasm-user/smartrpa_backgroud_new
    ls -t server_*.log | tail -n +6 | xargs -I {} rm -f {}
}

# 启动服务器
echo "启动smartrpa服务器..."
while true; do
    # 清理旧日志文件
    cleanup_logs
    
    # 创建带时间戳的日志文件名
    LOG_FILE="server_$(date '+%Y%m%d_%H%M%S').log"
    # 使用日志轮转来限制单个日志文件的大小
    nohup node server.js 2>&1 | tee "$LOG_FILE" | split -b 50M - "${LOG_FILE}.split." &
    SERVER_PID=$!
    echo "SmartRPA服务运行在端口8082 (PID: $SERVER_PID)"
    echo "日志文件: $LOG_FILE"
    
    # 等待服务器进程结束
    wait $SERVER_PID
    
    echo "服务器已停止，30秒后尝试重新启动..."
    sleep 30
done

# 检查服务是否启动
sleep 5
if ! curl -s http://localhost:8082 > /dev/null; then
    echo "SmartRPA服务启动失败"
    tail -n 20 server.log
else
    echo "SmartRPA服务启动成功"
fi



exit 0



# # 保持服务运行
# while true; do
#     sleep 10
# done

# bash -c "sleep infinity"
