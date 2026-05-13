#!/bin/bash
# ============================================
# XrayR 一键安装脚本（纯源码编译版，仅依赖你的仓库）
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

# 定义变量（只依赖你自己的仓库）
GIT_REPO="https://github.com/a2231711/XrayR-0.9.4.git"
SRC_DIR="/root/xrayr_src"
INSTALL_DIR="/usr/local/XrayR"
SERVICE_FILE="/etc/systemd/system/XrayR.service"
CONFIG_FILE="${INSTALL_DIR}/config.yml"

echo -e "${green}=== 开始安装 XrayR（源码编译版） ===${plain}"

# 1. 安装基础依赖
echo -e "${yellow}1. 安装基础依赖包...${plain}"
if [[ ${release} == "centos" ]]; then
    yum install -y wget curl git
else
    apt update -y && apt install -y wget curl git
fi

# 2. 安装 Go 环境（稳定版）
echo -e "${yellow}2. 安装 Go 编译环境...${plain}"
if ! command -v go &> /dev/null; then
    wget https://dl.google.com/go/go1.21.13.linux-amd64.tar.gz
    rm -rf /usr/local/go
    tar -C /usr/local -xzf go1.21.13.linux-amd64.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    source /etc/profile
    rm -f go1.21.13.linux-amd64.tar.gz
fi

# 3. 拉取你自己仓库的源码
echo -e "${yellow}3. 拉取你的源码仓库...${plain}"
rm -rf ${SRC_DIR}
git clone ${GIT_REPO} ${SRC_DIR}
cd ${SRC_DIR} || exit

# 4. 编译程序（跳过安全校验，强制编译）
echo -e "${yellow}4. 编译 XrayR 程序...${plain}"
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o XrayR main.go

if [[ ! -f XrayR ]]; then
    echo -e "${red}编译失败，请检查源码是否完整！${plain}"
    exit 1
fi

# 5. 安装程序
echo -e "${yellow}5. 安装程序到系统目录...${plain}"
mkdir -p ${INSTALL_DIR}
cp -f XrayR ${INSTALL_DIR}/
chmod +x ${INSTALL_DIR}/XrayR

# 6. 写入配置文件（模板，后续可修改）
echo -e "${yellow}6. 写入基础配置文件...${plain}"
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

# 7. 配置 systemd 服务
echo -e "${yellow}7. 配置系统服务...${plain}"
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

# 8. 启动服务
systemctl daemon-reload
systemctl enable XrayR
systemctl start XrayR

echo -e "${green}✅ 安装完成！${plain}"
echo -e "程序路径：${INSTALL_DIR}/XrayR"
echo -e "配置文件：${CONFIG_FILE}"
echo -e "查看日志：journalctl -u XrayR -f"
echo -e "重启服务：systemctl restart XrayR"
