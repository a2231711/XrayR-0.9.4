#!/bin/bash
# ============================================
# XrayR 一键安装脚本（官方预编译版）
# 仓库地址：https://github.com/a2231711/XrayR-0.9.4
# ============================================

# 颜色输出
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# 必须用 root 用户运行
if [[ $EUID -ne 0 ]]; then
    echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n"
    exit 1
fi

# 系统检测
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
else
    echo -e "${red}未检测到系统版本！${plain}\n"
    exit 1
fi

# 架构检测（只支持64位）
if [[ $(getconf LONG_BIT) != "64" ]]; then
    echo -e "${red}本脚本仅支持 64 位系统！${plain}\n"
    exit 1
fi

# 定义变量
INSTALL_DIR="/usr/local/XrayR"
SERVICE_FILE="/etc/systemd/system/XrayR.service"
CONFIG_FILE="${INSTALL_DIR}/config.yml"
BINARY_URL="https://github.com/XrayR-project/XrayR/releases/latest/download/XrayR-linux-amd64.zip"

echo -e "${green}=== 开始安装 XrayR ===${plain}"

# 安装依赖
echo -e "${yellow}1. 安装依赖包...${plain}"
if [[ ${release} == "centos" ]]; then
    yum install -y wget unzip curl
else
    apt update -y && apt install -y wget unzip curl
fi

# 创建目录
mkdir -p ${INSTALL_DIR}
cd ${INSTALL_DIR} || exit

# 下载预编译二进制文件
echo -e "${yellow}2. 下载官方预编译程序...${plain}"
wget -O XrayR.zip ${BINARY_URL}
if [[ $? -ne 0 ]]; then
    echo -e "${red}下载失败，请检查网络！${plain}"
    exit 1
fi

# 解压
unzip -o XrayR.zip
rm -f XrayR.zip
chmod +x XrayR

# 写入配置文件（这里是模板，你后续可在服务器上手动修改）
echo -e "${yellow}3. 写入基础配置文件...${plain}"
cat > ${CONFIG_FILE} << EOF
Log:
  Level: warning
  Output: ./XrayR.log
Panel:
  Type: V2board
  ApiHost: https://你的面板地址
  ApiKey: "你的面板密钥"
  NodeID: 你的节点ID
  Timeout: 30
  EnableTLS: false
  EnableProxyProtocol: false
  ListenIP: 0.0.0.0
Nodes:
  - PanelType: "V2board"
    NodeType: V2ray
    EnableVless: false
EOF

# 写入 systemd 服务文件
echo -e "${yellow}4. 配置系统服务...${plain}"
cat > ${SERVICE_FILE} << EOF
[Unit]
Description=XrayR Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/XrayR -config ${CONFIG_FILE}
Restart=on-failure
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# 启用并启动服务
systemctl daemon-reload
systemctl enable XrayR
systemctl start XrayR

echo -e "${green}✅ 安装完成！${plain}"
echo -e "程序路径：${INSTALL_DIR}/XrayR"
echo -e "配置文件：${CONFIG_FILE}"
echo -e "查看日志：journalctl -u XrayR -f"
echo -e "重启服务：systemctl restart XrayR"
