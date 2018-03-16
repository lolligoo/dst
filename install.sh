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
sudo yum update
sudo yum -y install glibc.i686 libstdc++.i686 libcurl4-gnutls-dev.i686
sudo yum -y screen grep lua5.2 git
sudo ln -s /usr/lib/libcurl.so.4 /usr/lib/libcurl-gnutls.so.4

info "创建虚拟交换空间并启用。。。"
if [ ! -f /swapfile ]; then
    sudo dd if=/dev/zero of=/swapfile bs=1M count=4096
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
    ./steamcmd/steamcmd.sh +quit
fi

info "下载脚本文件。。。"
git clone https://github.com/GoforDance/dst.git

echo 'alias dst="./dst/shell/dst.sh"' >> .bashrc
source .bashrc
info "安装完成，执行 dst 命令即可使用，更多请访问https://blog.wqlin.com"
