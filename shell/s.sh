#
#!/bin/bash
#####################################################################
# Author:  STEAM@GoforDream http://steamcommunity.com/id/gofordream/#
# Lisence: MIT                                                      #
# Date:    2018-01-19 22:25:25                                      #
#####################################################################

DST_conf_dirname="DoNotStarveTogether"   
DST_conf_basedir="$HOME/.klei" 
DST_bin_cmd="./dontstarve_dedicated_server_nullrenderer"   
DST_game_path="$HOME/DSTServer"
DST_script_filepath="$HOME/.dstscript"
DST_script_conffile="$DST_script_filepath/server.conf"

getconfig() {
    if [[ $(grep "$1" -c $DST_script_conffile) > 0 ]]; then
        grep "^$1" $DST_script_conffile | cut -d"=" -f2
    fi
}

exchange() {
    if [[ $(grep "$1" -c $DST_script_conffile) > 0 ]]; then
        oldstr="$(grep "^$1" $DST_script_conffile)"
        new="$1=$2"
        sed -i "s/$oldstr/$new/g" $DST_script_conffile
    fi
}

find_screen() {
    if [ $(screen -ls|grep -c "$1") -eq 0 ]; then
        return 1
    else
        return 0
    fi
}

info(){ echo -e "\e[92m[$(date "+%T") 信息] \e[0m$1"; }
warming(){ echo -e "\e[33m[$(date "+%T") 警告] \e[0m$1"; }
error(){ echo -e "\e[31m[$(date "+%T") 错误] \e[0m$1";}

check_auto_update(){
    ping -c 2 -i 0.2 -W 3 steamcommunity.com &> /dev/null
    if [ $? -eq 0 ]; then
        info "MOD自动更新已开启！"
        exchange "mod_update" "true"
    else
        warming "Steam创意工坊无法访问，MOD自动更新已关闭！"
        exchange "mod_update" "false"
    fi
    ping -c 2 -i 0.2 -W 3 kleientertainment.com &> /dev/null
    if [ $? -eq 0 ]; then
        info "游戏服务端自动更新已开启！"
        exchange "game_update" "true"
    else
        warming "Klei官网无法访问，游戏服务端自动更新已关闭！"
        exchange "game_update" "false"
    fi
}

checklib(){
    list="lib32gcc1 lib32stdc++6 libcurl4-gnutls-dev:i386 screen grep lua5.2 diffutils htop"
    for i in $list; do
        dpkg -s $i &> /dev/null
        if [ $? -gt 0 ]; then
            warming "依赖库 $i 未安装！"
            info "正在安装依赖库 $i ..."
            sudo apt-get -y install $i &> /dev/null
            info "依赖库 $i 安装完成！"
        fi
    done
}

openswap(){
    if [ ! -f /swapfile ]; then
        info "创建虚拟交换空间 ..."
        sudo dd if=/dev/zero of=/swapfile bs=1M count=4096 &> /dev/null
        sudo mkswap /swapfile &> /dev/null
        sudo chmod 0600 /swapfile
        sudo chmod 0666 /etc/fstab
        echo "/swapfile    swap    swap    defaults 0 0" >> /etc/fstab
    fi
    if [[ $(free|grep ^Swap|cut -d":" -f2|tr -cd "[0-9]") == "000" ]]; then
        info "启用虚拟交换空间 ..."
        sudo swapon /swapfile
    fi
}

cmd_install(){
    if [ ! -f "$HOME/steamcmd/steamcmd.sh" ]; then
        info "正在安装 steamcmd ..."
        wget http://ozwsnihn1.bkt.clouddn.com/dst/steamcmd/steamcmd_linux.tar.gz &> /dev/null
        tar -xvzf steamcmd_linux.tar.gz &> /dev/null
        rm steamcmd_linux.tar.gz
        info "Steamcmd 已安装。"
    fi
}

first_install(){
    checklib
    openswap
    cmd_install
    if [ ! -f $DST_game_path/version.txt ]; then 
        game_update
    fi
}

game_update(){
    info "正在更新游戏服务端 ..."
    cd $HOME/steamcmd
    ./steamcmd.sh+login anonymous+force_install_dir "${DST_game_path}"+app_update 343050 validate+quit &> /dev/null
    cd $HOME
    info "游戏服务端已更新。"
}

getserverversion(){
    DST_server_version="000000"
    if [ -f "$DST_game_path/version.txt" ];then
        DST_server_version=$(cat $DST_game_path/version.txt)
    fi
}

startserver(){
    if [ ! -d "${DST_conf_basedir}/${DST_conf_dirname}" ]; then 
        mkdir -p ${DST_conf_basedir}/${DST_conf_dirname}
    fi
    echo -e "\e[92m是否新建存档：1.是 2.否\e[0m"
    read isnew
    case $isnew in
        1)
        echo -e "\e[92m请输入存档名称：（不要包含中文）\e[0m"
        read cluster
        cluster=$cluster
        exchange "cluster" "$cluster"
        if [ ! -d "${DST_conf_basedir}/${DST_conf_dirname}/${cluster}" ]; then 
            mkdir -p ${DST_conf_basedir}/${DST_conf_dirname}/${cluster}
        fi
        setcluster
        settoken
        createlistfile
        setserverini
        setworld
        echo -e "\e[92m是否设置管理员、黑名单和白名单：1.是  2.否\e[0m"
        read setlist
        case $setlist in  
            1)
            listmanager;;
        esac
        ;;
        2)
        echo -e "\e[92m已有存档：\e[0m"
        ls -l ${DST_conf_basedir}/${DST_conf_dirname} |awk '/^d/ {print $NF}'
        echo -e "\e[92m请输入已有存档名称：\e[0m"
        read cluster
        cluster=$cluster
        exchange "cluster" "$cluster"    
        ;;
    esac
    savelog    
    cd "${DST_game_path}/bin"
    echo -e "\e[92m请选择要开启的世界:1.地上(主世界) 2.洞穴(附从世界) 3.地上+洞穴(主世界+附从世界)\e[0m"
    read shard 
    case $shard in
        1)        
        screen -dmS "DST_Master" /bin/sh -c "$DST_bin_cmd -conf_dir $DST_conf_dirname -cluster $cluster -shard Master"
        exchange "Master" "1"
        exchange "Caves" "0"
        ;;
        2)
        screen -dmS "DST_Caves" /bin/sh -c "$DST_bin_cmd -conf_dir $DST_conf_dirname -cluster $cluster -shard Caves"
        exchange "Master" "0"
        exchange "Caves" "1"
        ;;
        3)        
        screen -dmS "DST_Master" /bin/sh -c "$DST_bin_cmd -conf_dir $DST_conf_dirname -cluster $cluster -shard Master"
        sleep 3
        screen -dmS "DST_Caves" /bin/sh -c "$DST_bin_cmd -conf_dir $DST_conf_dirname -cluster $cluster -shard Caves"
        exchange "Master" "1"
        exchange "Caves" "1"
        ;;
    esac
    exchange "server" "true"
    DST_now=$(date +"%F %T")
    echo "${DST_now}: 服务器开启中。。。请稍候。。。"
    sleep 10
    startcheck
    menu
}

if [ $(getconfig "lib_installed" ) == false ]; then
    sudo apt-get update
    first_install
    exchange "lib_installed" "true"
fi

# New menu
    clientip=$(curl -s http://members.3322.org/dyndns/getip)
    getpresentcluster
    getserverversion
    getpresentserver
    echo -e "\e[33m====== 欢迎使用饥荒联机版($DST_server_version)独立服务器脚本[Linux-Steam] By GoforDream ======\e[0m"
    echo -e "\e[31m存档目录：$DST_conf_basedir/${DST_conf_dirname}\e[0m"
    echo -e "\e[31mMOD 安装目录：$DST_game_path/mods\e[0m"
    echo -e "\e[92m本云服务器公网IP: $clientip 直连代码：c_connect(\"$clientip\", $serverport)\e[0m"
    echo -e "\e[92m[1]启动服务器              [2]关闭服务器            [3]重启服务器\e[0m"  
    echo -e "\e[92m[4]查看游戏服务器状态      [5]添加或移除MOD         [6]设置管理员和黑、白名单\e[0m"
    echo -e "\e[92m[7]控制台                  [8]查看自动更新进程      [9]退出本脚本\e[0m"
    echo -e "\e[92m[10]删除存档               [12]更改房间设置         [14]自动公告\e[0m"
    echo -e "\e[92m=============================世界信息===========================================\e[0m"
    getworldstate
    getplayernumber        
    echo -e "\e[33m当前服务器开启的世界：$server  当前存档槽：$cluster\e[0m"
    if [[ $(screen -ls | grep -c "DST_Master") > 0 || $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
        getworldname
        echo -e "\e[33m当前是世界第 $presentcycles 天 $presentseason的第 $presentday 天 $presentphase  游戏模式: $gamemode\e[0m"
        echo -e "\e[31m房间名:$world_name 密码: $passkey 人数: $number/$maxplayer\e[0m"
    fi
    getplayerlist
    echo -e "\e[33m================================================================================\e[0m"
    echo -e "\e[92m请输入命令代号：\e[0m"
