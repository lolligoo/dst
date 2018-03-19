#
#!/bin/bash
#
# 安装必要依赖及软件
#
info(){ echo -e "\e[92m[$(date "+%T") 信息] \e[0m$1"; }

info "安装所需依赖库及软件。。。"
sudo apt-get update >/dev/null 2>&1
liblist="lib32gcc1 lib32stdc++6 libcurl4-gnutls-dev:i386 screen grep lua5.2 diffutils apache2"
for i in $liblist; do
    dpkg -s $i &> /dev/null
    if [ $? -gt 0 ]; then
        info "【$i】安装中。。。"
        sudo apt-get -y install $i &> /dev/null
    fi
done

info "创建虚拟交换空间并启用。。。"
if [ ! -f /swapfile ]; then
    sudo dd if=/dev/zero of=/swapfile bs=1M count=4096 >/dev/null 2>&1
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
    wget http://ozwsnihn1.bkt.clouddn.com/dst/steamcmd/steamcmd_linux.tar.gz >/dev/null 2>&1
    tar -xvzf steamcmd_linux.tar.gz >/dev/null 2>&1
    rm steamcmd_linux.tar.gz
    ./steamcmd/steamcmd.sh +quit >/dev/null 2>&1
fi

info "下载脚本文件。。。"
git clone https://github.com/GoforDance/dst.git >/dev/null 2>&1

echo 'alias dst="./dst/shell/dst.sh"' >> .bashrc
source .bashrc
rm install.sh
sudo chown -R $USER:$USER steamcmd
sudo chmod +x dst/shell/*.sh
info "安装完成，执行 dst 命令即可使用，更多请访问https://blog.wqlin.com"
