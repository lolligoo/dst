#
#!/bin/bash
#
# 安装必要依赖及软件
#
# 屏幕输出规则
info(){ echo -e "\e[92m[$(date "+%T") 信息] \e[0m$1"; }
warming(){ echo -e "\e[33m[$(date "+%T") 警告] \e[0m$1"; }
error(){ echo -e "\e[31m[$(date "+%T") 错误] \e[0m$1";}

info "安装所需依赖库及软件。。。"
sudo apt-get update
sudo apt-get -y install lib32gcc1 lib32stdc++6 libcurl4-gnutls-dev:i386
sudo apt-get -y screen grep lua5.2 git

info "创建虚拟交换空间并启用。。。"
if [ ! -f /swapfile ]; then
    sudo mkswap /swapfile &> /dev/null
    sudo chmod 0600 /swapfile
    sudo chmod 0666 /etc/fstab
    echo "/swapfile    swap    swap    defaults 0 0" >> /etc/fstab
fi
if [[ $(free|grep ^Swap|cut -d":" -f2|tr -cd "[0-9]") == "000" ]]; then
    sudo swapon /swapfile
fi

info "安装Steamcmd。。。"
if [ ! -f "$HOME/steamcmd/steamcmd.sh" ]; then
    wget http://ozwsnihn1.bkt.clouddn.com/dst/steamcmd/steamcmd_linux.tar.gz
    tar -xvzf steamcmd_linux.tar.gz
    rm steamcmd_linux.tar.gz
    ./steamcmd/steamcmd.sh+quit
fi

if [ $? -eq 0 ]; then info "Steamcmd安装完成！" fi

info "下载脚本文件。。。"
git clone https://github.com/GoforDance/dst.git

echo 'dst="./dst/shell/dst.sh"' >> .bashrc
source .bashrc
