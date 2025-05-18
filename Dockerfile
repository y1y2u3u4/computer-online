FROM madiator2011/kasm-core-standalone:test

# 安装依赖
USER root
RUN apt-get update && \
    apt-get install -y wget socat git nodejs npm openssh-server && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 配置SSH
RUN mkdir -p /run/sshd && \
    chmod 755 /run/sshd && \
    mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh

# SSH配置
RUN echo 'Port 22\n\
ListenAddress 0.0.0.0\n\
PermitRootLogin yes\n\
PubkeyAuthentication yes\n\
PasswordAuthentication no\n\
AuthorizedKeysFile .ssh/authorized_keys\n\
UsePAM yes\n\
X11Forwarding yes\n\
PrintMotd no' > /etc/ssh/sshd_config

# 添加SSH公钥
RUN echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOib9c12KIndxeAZjaB+L6MdKs/BbXLFwVq7lWiHPe4q zhanggongqing@zhanggongqingdeMacBook-Air.local" > /root/.ssh/authorized_keys && \
    chmod 600 /root/.ssh/authorized_keys

# 创建并设置工作目录
WORKDIR /app

# 安装 AdsPower
RUN wget -O /app/AdsPower.deb https://storage.googleapis.com/public-adspower-deb/AdsPower-Global-6.12.6-x64.deb && \
    dpkg -i /app/AdsPower.deb && \
    apt-get install -f -y && \
    rm /app/AdsPower.deb

# # 安装 SunBrowser 131
# RUN wget -O /tmp/chrome_131.tar.gz https://storage.googleapis.com/public-adspower-deb/chrome_131.tar.gz && \
#     mkdir -p /home/kasm-user/.config/adspower_global/cwd_global && \
#     tar -xzf /tmp/chrome_131.tar.gz -C /home/kasm-user/.config/adspower_global/cwd_global/ && \
#     rm /tmp/chrome_131.tar.gz && \
#     chown -R kasm-user:kasm-user /home/kasm-user/.config/adspower_global && \
#     chmod -R 755 /home/kasm-user/.config/adspower_global

# 复制并设置启动脚本
COPY start.sh /dockerstartup/custom_startup.sh
RUN chmod +x /dockerstartup/custom_startup.sh && \
    chown kasm-user:kasm-user /dockerstartup/custom_startup.sh

# 暴露端口
EXPOSE  50325 52919

# 设置目录权限
RUN mkdir -p /home/kasm-user/.config/Code && \
    mkdir -p /home/kasm-user/.vscode/extensions && \
    chown -R kasm-user:kasm-user /home/kasm-user/.config && \
    chown -R kasm-user:kasm-user /home/kasm-user/.vscode && \
    chmod -R 755 /home/kasm-user/.config && \
    chmod -R 755 /home/kasm-user/.vscode

# 切换到非 root 用户运行普通服务
USER kasm-user
# 注意：SSH服务将以root用户启动，不受此影响

EXPOSE 5000
CMD ["node", "serverless.js"]