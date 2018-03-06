#
#!/bin/bash
#
#####################################################################
# Author:  STEAM@GoforDream http://steamcommunity.com/id/gofordream/#
# Lisence: MIT                                                      #
# Date:    2018-01-19 22:25:25                                      #
#####################################################################
# 全局变量
DST_conf_dirname="DoNotStarveTogether"   
DST_conf_basedir="$HOME/.klei" 
DST_bin_cmd="./dontstarve_dedicated_server_nullrenderer"   
DST_game_path="$HOME/DSTServer"
DST_script_filepath="$HOME/dstscript"
DST_script_conffile="$DST_script_filepath/server.conf"
# 获取常量值
getconfig() {
    if [[ $(grep "$1" -c $DST_script_conffile) > 0 ]]; then
        grep "^$1" $DST_script_conffile | cut -d"=" -f2
    fi
}
# 更改常量值
exchange() {
    if [[ $(grep "$1" -c $DST_script_conffile) > 0 ]]; then
        oldstr="$(grep "^$1" $DST_script_conffile)"
        new="$1=$2"
        sed -i "s/$oldstr/$new/g" $DST_script_conffile
    fi
}
# screen 是否存在
find_screen() {
    if [ $(screen -ls|grep -c "$1") -eq 0 ]; then
        return 1
    else
        return 0
    fi
}
# 屏幕输出规则
info(){ echo -e "\e[92m[$(date "+%T") 信息] \e[0m$1"; }
warming(){ echo -e "\e[33m[$(date "+%T") 警告] \e[0m$1"; }
error(){ echo -e "\e[31m[$(date "+%T") 错误] \e[0m$1";}
# 官网访问检测
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
# 依赖及所需软件检测
checklib(){
    list="lib32gcc1 lib32stdc++6 libcurl4-gnutls-dev:i386 screen grep lua5.2 diffutils htop"
    for i in $list; do
        dpkg -s $i &> /dev/null
        if [ $? -gt 0 ]; then
            warming "$i uninstalled."
            info "Installing $i ..."
            sudo apt-get -y install $i &> /dev/null
            info "$i installed."
        fi
    done
}
#
#swap
#
openswap(){
    if [ ! -f /swapfile ]; then
        info "Creating swap space ..."
        sudo dd if=/dev/zero of=/swapfile bs=1M count=4096 &> /dev/null
        sudo mkswap /swapfile &> /dev/null
        sudo chmod 0600 /swapfile
        sudo chmod 0666 /etc/fstab
        echo "/swapfile    swap    swap    defaults 0 0" >> /etc/fstab
    fi
    if [[ $(free|grep ^Swap|cut -d":" -f2|tr -cd "[0-9]") == "000" ]]; then
        info "Opening swap ..."
        sudo swapon /swapfile
    fi
}
#
#installdst
#
cmd_install(){
    if [ ! -f "$HOME/steamcmd/steamcmd.sh" ]; then
        info "Installing steamcmd ..."
        wget http://ozwsnihn1.bkt.clouddn.com/dst/steamcmd/steamcmd_linux.tar.gz &> /dev/null
        tar -xvzf steamcmd_linux.tar.gz &> /dev/null
        rm steamcmd_linux.tar.gz
        info "Steamcmd intsalled."
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
    info "Updating DST dedicated server ..."
    cd $HOME/steamcmd
    ./steamcmd.sh+login anonymous+force_install_dir "${DST_game_path}"+app_update 343050 validate+quit &> /dev/null
    cd $HOME
    info "DST dedicated server up to date now."
}

if [ $(getconfig "lib_installed" ) == false ]; then
    sudo apt-get update
    first_install
    exchange "first" "true"
fi

getserverversion()
{
    DST_server_version="000000"
    if [ -f "$DST_game_path/version.txt" ];then
        DST_server_version=$(cat $DST_game_path/version.txt)
    fi
}

setupmod()
{
    echo "--MOD自动更新列表：" > $HOME/.dstscript/mods_setup.lua
    dir=$(grep "workshop" "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Master/modoverrides.lua" | cut -d '"' -f 2 | cut -d '-' -f 2)
    for modid in $dir
    do
        if [[ $(grep "$modid" -c "$HOME/.dstscript/mods_setup.lua") = 0 && "$modid" != "donotdelete" ]] ;then     
            echo "ServerModSetup(\"$modid\")" >> "$HOME/.dstscript/mods_setup.lua"
        fi
    done  
}

closeserver()
{   
    if [[ $(screen -ls | grep -c "DST_Master") = 0 && $(screen -ls | grep -c "DST_Caves") = 0 ]]; then

        echo "${DST_now}: 服务器未开启！"
    fi
    if [[ $(screen -ls | grep -c "DST_Master") > 0 || $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
        if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then
            screen -S "DST_Master" -p 0 -X stuff "c_save()$(printf \\r)"
            sleep 5
            screen -S "DST_Master" -p 0 -X stuff "c_shutdown()$(printf \\r)"
        fi
        if [[ $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
            screen -S "DST_Caves" -p 0 -X stuff "c_save()$(printf \\r)"
            sleep 5
            screen -S "DST_Caves" -p 0 -X stuff "c_shutdown()$(printf \\r)"
        fi
        sleep 10
        if [[ $(screen -ls | grep -c "DST_AUTOUPDATE") > 0 ]]; then
            pid=$(screen -ls | grep "DST_AUTOUPDATE" | cut -d"." -f1 | tr -cd "[0-9]")
            kill $pid
        fi

        echo "${DST_now}: 服务器已关闭！"   
        exchange "server" "false"        
    fi
}

savelog()
{
    if [ -f "${DST_conf_basedir}/${DST_conf_dirname}/${cluster}/Master/server_chat_log.txt" ]; then

        echo "${DST_now}: 保存服务器聊天日志。。。"
        echo "以下内容备份于 ${DST_now}" >> "$DST_script_filepath/server_chat_log.save.txt"
        grep "^" "${DST_conf_basedir}/${DST_conf_dirname}/${cluster}/Master/server_chat_log.txt" | cut -f 2-20 -d' ' >> "$DST_script_filepath/server_chat_log.save.txt"
    fi        
}

settoken()
{
    echo -e "\e[92m是否使用预设服务器令牌：1.是 2.否 \e[0m"
    read isreset
    case $isreset in     
        1)
        echo "pds-g^KU_6yNrwFkC^9WDPAGhDM9eN6y2v8UUjEL3oDLdvIkt2AuDQB2mgaGE=" > "${DST_conf_basedir}/${DST_conf_dirname}/${cluster}/cluster_token.txt" ;;
        2)
        echo -e "\e[92m请输入你的服务器令牌：\e[0m"
        read token
        echo "$token" > "${DST_conf_basedir}/${DST_conf_dirname}/${cluster}/cluster_token.txt" ;;
    esac
    echo "服务器令牌设置完毕！"
}

setcluster()
{
    steam_group_admins="false"
    steam_group_id=0
    steam_group_only="false"
    game_mode="survival"
    max_player=6
    pvp="false"
    pause_when_empty="true"
    vote_enabled="true"
    cluster_intention="cooperative"
    cluster_description="The Server is created by GoforDream's Script!"
    cluster_name="GoforDream's World"
    cluster_password=""
    whitelist_slots=0
    master_ip=127.0.0.1
    while :
    do

    case $cmd in    clear
    echo -e "\e[33m===================================服务器设置===================================\e[0m"
    echo -e "\e[92m     当前存档：$cluster\e[0m"
    echo -e "\e[92m     [1] 房间名称：$cluster_name\e[0m"
    echo -e "\e[92m     [2] 房间简介：$cluster_description\e[0m"
    echo -e "\e[92m     [3] 游戏风格：$cluster_intention    \e[0m"
    echo -e "\e[92m     [4] 游戏模式：$game_mode\e[0m"
    echo -e "\e[92m     [5] 群组ID：$steam_group_id            \e[0m"
    echo -e "\e[92m     [6] 官员设为管理员：$steam_group_admins\e[0m"
    echo -e "\e[92m     [7] 仅组员可进：$steam_group_only\e[0m"
    echo -e "\e[92m     [8] 无人暂停：$pause_when_empty \e[0m"
    echo -e "\e[92m     [9] 开启投票：$vote_enabled       \e[0m"
    echo -e "\e[92m     [10] 开启PVP：$pvp\e[0m"
    echo -e "\e[92m     [11] 预留房间位置个数：$whitelist_slots\e[0m"
    echo -e "\e[92m     [12] 主世界IP(多服务器必须修改此项)：$master_ip\e[0m"
    echo -e "\e[92m     [13] 房间密码：$cluster_password\e[0m"
    echo -e "\e[92m     [14] 最大玩家人数：$max_player\e[0m"
    echo -e "\e[33m================================================================================\e[0m"
    echo -e "\e[92m请选择你要更改的选项(修改完毕输入数字 0 确认修改并退出)：\e[0m\c"
    read cmd
        0)
        writecluster
        break
        ;;
        1)
        echo -e "\e[92m请输入服务器名字：\e[0m\c"
        read cluster_name
        ;;
        2)
        echo -e "\e[92m请输入服务器介：\e[0m\c"
        read cluster_description
        ;;
        3)
        echo -e "\e[92m请选择游戏风格？1.休闲 2.合作 3.竞赛 4.疯狂：\e[0m\c"
        read intent
        case $intent in
            1)
            cluster_intention="social"
            ;;
            2)
            cluster_intention="cooperative"
            ;;
            3)
            cluster_intention="competitive"
            ;;
            4)
            cluster_intention="madness"
            ;;
        esac
        ;;
        4)
        echo -e "\e[92m请选择游戏模式？1.无尽 2.生存 3.荒野：\e[0m\c"
        read choosemode
        case $choosemode in
            1)
            game_mode="endless"
            ;;
            2)
            game_mode="survival"
            ;;
            3)
            game_mode="wilderness"
            ;;
        esac
        ;;
        5)
        echo -e "\e[92m请输入Steam群组ID:\e[0m\c"
        read steam_group_id
        ;;
        6)
        echo -e "\e[92m群组官员是否设为管理员?1.是 2.否：\e[0m\c"
        read isadmin
        case $isadmin in
            1)
            steam_group_admins="true"
            ;;
            2)
            steam_group_admins="false"
            ;;
        esac
        ;;
        7)
        echo -e "\e[92m服务器是否设为仅Steam群组成员可进？1.是 2.否：\e[0m\c"
        read isonly
        case $isonly in
            1)
            steam_group_only="true"
            ;;
            2)
            steam_group_only="false"
            ;;
        esac
        ;;
        8)
        echo -e "\e[92m是否开启无人暂停？1.是 2.否：\e[0m\c"
        read if
        case $if in
            1)
            pause_when_empty="true"
            ;;
            2)
            pause_when_empty="false"
            ;;
        esac
        ;;
        9)
        echo -e "\e[92m是否开启投票？1.是 2.否：\e[0m\c"
        read if
        case $if in
            1)
            vote_enabled="true"
            ;;
            2)
            vote_enabled="false"
            ;;
        esac
        ;;
        10)
        echo -e "\e[92m是否开启PVP？1.是 2.否：\e[0m\c"
        read if
        case $if in
            1)
            pvp="true"
            ;;
            2)
            pvp="false"
            ;;
        esac
        ;;
        11)
        echo -e "\e[92m请输入预留的服务器玩家位置个数(设置后请在后续步骤添加白名单，否则无效):\e[0m\c"
        read whitelist_slots
        ;;
        12)
        echo -e "\e[92m请输入主世界IP：\e[0m\c"
        read master_ip
        ;;
        13)
        echo -e "\e[92m请输入房间密码：\e[0m\c"
        read cluster_password
        ;;
        14)
        echo -e "\e[92m请输入最大玩家人数：\e[0m\c"
        read max_player
        ;;
    esac
    done
}

writecluster()
{
    echo "[STEAM]
steam_group_admins = $steam_group_admins
steam_group_id = $steam_group_id
steam_group_only = $steam_group_only


[GAMEPLAY]
game_mode = $game_mode
max_players = $max_player
pvp = $pvp
pause_when_empty = $pause_when_empty
vote_enabled = $vote_enabled


[NETWORK]
lan_only_cluster = false
cluster_intention = $cluster_intention
cluster_description = $cluster_description
cluster_name = $cluster_name
offline_cluster = false
cluster_password = $cluster_password
whitelist_slots = $whitelist_slots
autosaver_enabled = true
tick_rate = 15


[MISC]
max_snapshots = 6
console_enabled = true


[SHARD]
shard_enabled = true
bind_ip = 0.0.0.0
master_ip = $master_ip
master_port = 10888
cluster_key = GoforFun


" > $DST_conf_basedir/$DST_conf_dirname/$cluster/cluster.ini
    clear
    myscriptname
    echo -e "\e[92m服务器设置完成！\e[0m"
}

setserverini()
{
    if [ ! -d "${DST_conf_basedir}/${DST_conf_dirname}/${cluster}/Master" ];then 
        mkdir -p ${DST_conf_basedir}/${DST_conf_dirname}/${cluster}/Master
        echo "[NETWORK]
server_port = 11111


[SHARD]
is_master = true
name = Master
id = 1


[ACCOUNT]
encode_user_path = true


[STEAM]
master_server_port = 27016
authentication_port = 8766" > "${DST_conf_basedir}/${DST_conf_dirname}/${cluster}/Master/server.ini"            
    fi
    if [ ! -d "${DST_conf_basedir}/${DST_conf_dirname}/${cluster}/Caves" ];then 
        mkdir -p ${DST_conf_basedir}/${DST_conf_dirname}/${cluster}/Caves
        echo "[NETWORK]
server_port = 22222


[SHARD]
is_master = false
name = Caves
id = 2


[ACCOUNT]
encode_user_path = true


[STEAM]
master_server_port = 27017
authentication_port = 8767" > "${DST_conf_basedir}/${DST_conf_dirname}/${cluster}/Caves/server.ini"
    fi
}

startserver()
{
    if [ ! -d "${DST_conf_basedir}/${DST_conf_dirname}" ]
    then 
        mkdir -p ${DST_conf_basedir}/${DST_conf_dirname}
    fi
    echo -e "\e[92m是否新建存档：1.是 2.否(配置房间时会同时配置地上和洞穴,所以不开的直接默认就好)\e[0m"
    read isnew
    case $isnew in
        1)
        echo -e "\e[92m请输入存档名称：（不要包含中文）\e[0m"
        read cluster
        cluster=$cluster
        exchange "cluster_name" "$cluster"
        if [ ! -d "${DST_conf_basedir}/${DST_conf_dirname}/${cluster}" ]
        then 
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
        exchange "cluster_name" "$cluster"    
        ;;
    esac
    echo -e "\e[92m是否允许强制关服，如果允许，你可以设置服务器在某个时间端强制关闭"
    echo -e "\e[92m超过这个时间段后自动开启：（24小时制） 1.是   2.否\e[0m"
    read force
    case $force in  
        1)
        allow_force_shutdown="true"
        echo -e "\e[92m请设置你要在几点之后关闭服务器：\e[0m"
        read min_hour
        echo -e "\e[92m请设置你要在几点之后开启服务器：\e[0m"
        read max_hour
        ;;
        2)
        allow_force_shutdown="false";;
    esac
    exchange "allow_force_shutdown" "$allow_force_shutdown"
    exchange "min_hour" "$min_hour"
    exchange "max_hour" "$max_hour"
    savelog    
    check_update
    if [[ ! -f ${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Master/modoverrides.lua ]]; then
        modadd
        listallmod
        addmod
    fi
    setupmod
    myscriptname
    cp "$HOME/.dstscript/mods_setup.lua" "$DST_game_path/mods/dedicated_server_mods_setup.lua"    
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

serverrestart()
{
    myscriptname
    setupmod
    cp "$DST_script_filepath/mods_setup.lua" "$DST_game_path/mods/dedicated_server_mods_setup.lua"    
    cd "${DST_game_path}/bin"
    Master=$(getconfig "Master")
    Caves=$(getconfig "Caves")
    if [[ "$Master" != "" && "$Master" == "1" ]]; then    

        echo "${DST_now}: 正在重启地上服务器。。。" 
        screen -dmS "DST_Master" /bin/sh -c "$DST_bin_cmd -conf_dir $DST_conf_dirname -cluster $cluster -shard Master"
    fi
    sleep 5
    if [[ "$Caves" != "" && "$Caves" == "1" ]]; then    

        echo "${DST_now}: 正在重启洞穴服务器。。。" 
        screen -dmS "DST_Caves" /bin/sh -c "$DST_bin_cmd -conf_dir $DST_conf_dirname -cluster $cluster -shard Caves"
    fi
    exchange "server" "true"
}

check_update()
{ 
    DST_now=$(date +"%F %T")
    echo "${DST_now}：启动前检查服务端是否有更新。。。请稍候。。。"
    gamebeta=$(getconfig "gbeta")
    if [[ "$gamebeta" == "Public" ]]; then
        new_ver=$(curl -s https://forums.kleientertainment.com/game-updates/dst/ | grep -B 1 'Release</span>' | head -n 1 | tr -cd "[0-9]")
    else
        new_ver=$(curl -s https://forums.kleientertainment.com/game-updates/dst/ | grep -B 2 'Test</span>' | head -n 1 | tr -cd "[0-9]")
    fi
    cur_ver=$(cat $DST_game_path/version.txt)
    if [[ "$new_ver" != "" && "$cur_ver" != "" && "$new_ver" != "$cur_ver" ]]; then

        echo "${DST_now}：游戏服务端有更新!"
        update_game            
    else

        echo "${DST_now}: 游戏服务端暂无更新，请进行下一步操作！"    
    fi
}

update_shutdown()
{   
    DST_now=$(date +"%F %T")
    echo "${DST_now}：准备关服，正在发送更新公告。。。"
    sleep 10
    if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then                                            
        screen -S "DST_Master" -p 0 -X stuff "c_announce(\"感谢你在本服务器玩耍，服务器将于一分钟后关闭进行更新，预计耗时三分钟！\")$(printf \\r)"
    fi
    sleep 30    
    if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then
        screen -S "DST_Master" -p 0 -X stuff "c_save()$(printf \\r)"
        sleep 5
        screen -S "DST_Master" -p 0 -X stuff "c_shutdown()$(printf \\r)"
    fi
    if [[ $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
        screen -S "DST_Caves" -p 0 -X stuff "c_save()$(printf \\r)"
        sleep 5
        screen -S "DST_Caves" -p 0 -X stuff "c_shutdown()$(printf \\r)"
    fi
    sleep 10
    if [[ $(screen -ls | grep -c "DST_Master") = 0 && $(screen -ls | grep -c "DST_Caves") = 0 ]]; then

        echo "${DST_now}：服务器已关闭。"
    fi
}

auto_update {    
    DST_now=$(date +"%F %T")
    echo "${DST_now}：服务器自动更新检查进程正在运行。。。"   
    if [ -f $DST_script_filepath/cur_modlist.txt ]; then
        getpresentcluster
        for i in $(grep "workshop" "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Master/modoverrides.lua" | cut -d '"' -f 2 | cut -d '-' -f 2)
        do
            if [[ "$i" != "" && "$i" != "donotdelete" ]]; then
                if [[ $(grep "$i" -c "$DST_script_filepath/cur_modlist.txt") != 0 ]]; then
                    old_post_date=$(grep "$i" "$DST_script_filepath/cur_modlist.txt" | cut -d "*" -f3)
                    curl -s "https://steamcommunity.com/sharedfiles/filedetails/?id=$i" > "$DST_script_filepath/temp.tmp"
                    new_post_date=$(cat "$DST_script_filepath/temp.tmp" | grep "detailsStatRight" | tail -n 1 | cut -d">" -f2 | cut -d"<" -f1)
                    mod_name=$(cat "$DST_script_filepath/temp.tmp" | grep "workshopItemTitle" | cut -d">" -f2 | cut -d"<" -f1)
                    if [[ "$old_post_date" != "" && "$new_post_date" != "" && "$old_post_date" != "$new_post_date" ]]; then
                
                        echo "${DST_now}：启用的模组 $mod_name(ID:$i) 有更新！"
                        DST_has_mods_update=true
                        break
                    else 
                        DST_has_mods_update=false
                    fi                        
                fi
            fi
        done
    else
        DST_has_mods_update=false
    fi
    echo "----curmodlist-----" > $DST_script_filepath/cur_modlist.txt
    for i in $(grep "workshop" "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Master/modoverrides.lua" | cut -d '"' -f 2 | cut -d '-' -f 2)
    do
        if [[ "$i" != "" && "$i" != "donotdelete" ]]; then
            curl -s "https://steamcommunity.com/sharedfiles/filedetails/?id=$i" > "$DST_script_filepath/temp.tmp"
            new_post_date=$(cat "$DST_script_filepath/temp.tmp" | grep "detailsStatRight" | tail -n 1 | cut -d">" -f2 | cut -d"<" -f1)
            mod_name=$(cat "$DST_script_filepath/temp.tmp" | grep "workshopItemTitle" | cut -d">" -f2 | cut -d"<" -f1)
            echo "$i*$mod_name*$new_post_date" >> "$DST_script_filepath/cur_modlist.txt"
        fi
    done    
    if [[ "$DST_has_mods_update" == false ]]; then 

        echo "${DST_now}：启用的模组没有更新！"
    fi
    gamebeta=$(getconfig "gbeta")
    if [[ "$gamebeta" == "Public" ]]; then
        new_ver=$(curl -s https://forums.kleientertainment.com/game-updates/dst/ | grep -B 1 'Release</span>' | head -n 1 | tr -cd "[0-9]")
    else
        new_ver=$(curl -s https://forums.kleientertainment.com/game-updates/dst/ | grep -B 2 'Test</span>' | head -n 1 | tr -cd "[0-9]")
    fi
    cur_ver=$(cat $DST_game_path/version.txt)
    if [[ "$new_ver" != "" && "$cur_ver" != "" && "$new_ver" != "$cur_ver" ]]; then

        DST_has_game_update=true
        echo "${DST_now}：游戏服务端有更新!"
    else
        DST_has_game_update=false

        echo "${DST_now}：游戏服务端没有更新!"    
    fi
    if [[ "$DST_has_game_update" == false && "$DST_has_mods_update" == true ]]; then 
        update_shutdown
    fi    
    if [[ "$DST_has_game_update" == true ]]; then 
        update_shutdown
        update_game
    fi
}

update_game()
{
    cd $HOME
    DST_now=$(date +"%F %T")
    echo "${DST_now}: 更新游戏服务端!"
    cd $HOME/steamcmd
    ./steamcmd.sh +login anonymous +force_install_dir "${DST_game_path}" +app_update 343050 validate +quit
    cd $HOME
    DST_now=$(date +"%F %T")
    echo "${DST_now}: 更新完成!"
}

processkeep {
    DST_now=$(date +"%F %T")
    Master=$(getconfig "Master")
    Caves=$(getconfig "Caves")
    DST_Caves=true
    DST_Master=true
    number=""
    echo "${DST_now}：服务器进程保持开启检查正在运行。。。"
    if [[ "$Master" != "" && "$Master" == "1" ]]; then    
        if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then
            allplayersnumber=$( date +%s%3N )
            screen -S "DST_Master" -p 0 -X stuff "print(\"AllPlayersNumber \" .. (table.getn(TheNet:GetClientTable())-1) .. \" $allplayersnumber\")$(printf \\r)"
            sleep 3
            number=$( grep "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Master/server_log.txt" -e "$allplayersnumber" | cut -f3 -d ' ' | tail -n +2 )
            if [[ "$number" != "" ]]; then
                states="且状态正常！"
            else
                DST_Master=false
                states="但状态异常！"
            fi    
    
            echo "${DST_now}: 地上服务器已开启，$states"             
        else
    
            echo "${DST_now}: 地上服务器未开启!"
            DST_Master=false
        fi
    fi
    if [[ "$Caves" != "" && "$Caves" == "1" ]]; then    
        if [[ $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
            allplayersnumber=$( date +%s%3N )
            screen -S "DST_Caves" -p 0 -X stuff "print(\"AllPlayersNumber \" .. (table.getn(TheNet:GetClientTable())-1) .. \" $allplayersnumber\")$(printf \\r)"
            sleep 3
            number=$( grep "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Caves/server_log.txt" -e "$allplayersnumber" | cut -f3 -d ' ' | tail -n +2 )
            if [[ "$number" != "" ]]; then
                states="且状态正常！"
            else
                DST_Caves=false
                states="但状态异常！"
            fi
    
            echo "${DST_now}: 洞穴服务器已开启，$states"
        else
    
            echo "${DST_now}: 洞穴服务器未开启!"
            DST_Caves=false
        fi
    fi
    if [[ "$DST_Master" == false || "$DST_Caves" == false ]]; then
        masterpid=$(screen -ls | grep "DST_Master" | cut -d"." -f1 | tr -cd "[0-9]")
        cavespid=$(screen -ls | grep "DST_Caves" | cut -d"." -f1 | tr -cd "[0-9]")
        if [[ "$masterpid" != "" ]]; then
            kill $masterpid
        fi
        if [[ "$cavespid" != "" ]]; then
            kill $cavespid
        fi

        echo "${DST_now}: 服务器将自动重启！"
        savelog
        sleep 5        
        serverrestart
        sleep 30
        startcheck
        cd $HOME
    fi            
}        

startcheck()
{
    masterserverlog_path="${DST_conf_basedir}/${DST_conf_dirname}/${cluster}/Master/server_log.txt"
    cavesserverlog_path="${DST_conf_basedir}/${DST_conf_dirname}/${cluster}/Caves/server_log.txt"
    if [[ -f "$masterserverlog_path" ]];then
        while :
        do    
            if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then
                if [[ $(grep "Sim paused" -c "$masterserverlog_path") > 0 || $(grep "New incoming connection" -c "$masterserverlog_path") > 0 ]]; then
            
                    echo "${DST_now}: 地上服务器开启成功！"
                    break
                fi
                if [[ $(grep "Your Server Will Not Start" -c "$masterserverlog_path") > 0 ]]; then
            
                    echo "${DST_now}: 地上服务器开启未成功，请执行关闭服务器命令后再次尝试，并注意令牌是否成功设置且有效。"
                    break
                fi
            else
        
                echo "${DST_now}: 地上服务器未配置或异常闪退，请查看服务器日志，解决问题后重试！"
                break
            fi    
        done
    fi 
    if [[ -f "$cavesserverlog_path" ]]; then
        while :
        do    
            if [[ $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
                if [[ $(grep "Sim paused" -c "$cavesserverlog_path") > 0 || $(grep "Sim unpaused" -c "$cavesserverlog_path") > 0 || $(grep "New incoming connection" -c "$cavesserverlog_path") > 0 || $(grep "[Shard] Slave LUA is now ready!" -c "$cavesserverlog_path") > 0 ]]; then
            
                    echo "${DST_now}: 洞穴服务器开启成功！"
                    break
                fi
                if [[ $(grep "Your Server Will Not Start" -c "$cavesserverlog_path") > 0 ]]; then
            
                    echo "${DST_now}: 洞穴服务器开启未成功，请执行关闭服务器命令后再次尝试，并注意令牌是否成功设置且有效。"
                    break
                fi
            else 
        
                echo "${DST_now}: 洞穴服务器未配置或异常闪退，请查看服务器日志，解决问题后重试！"
                break
            fi        
        done
    fi        
}

checkserver()
{    
    if [[ $(screen -ls | grep -c "DST_Master") > 0 || $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
        echo -e "\e[92m即将跳转游戏服务器窗口，要退回本界面，在游戏服务器窗口按 ctrl+a+d 再执行脚本即可。\e[0m"
        sleep 3
        if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then
            screen -r DST_Master
        fi
        if [[ $(screen -ls | grep -c "DST_Master") = 0 && $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
            screen -r DST_Caves
        fi
    else

        echo "${DST_now}: 游戏服务器未开启！"
        menu
    fi
}

exitshell()
{
    exit
}


# 写入地上世界设置文件 leveldataoverride.lua
setmasterlevel()
{
    echo "return {
  desc=\"The World is created by GoforFun's script.\",
  hideminimap=false,
  id=\"SURVIVAL_TOGETHER\",
  location=\"forest\",
  max_playlist_position=999,
  min_playlist_position=0,
  name=\"GoforDream's Forest\",
  numrandom_set_pieces=8,
  ordered_story_setpieces={ \"Sculptures_1\", \"Maxwell5\" },
  override_level_string=false,
  overrides={
    alternatehunt=\"$alternatehunt\",
    angrybees=\"$angrybees\",
    antliontribute=\"$antliontribute\",
    autumn=\"$autumn\",
    bearger=\"$bearger\",
    beefalo=\"$beefalo\",
    beefaloheat=\"$beefaloheat\",
    bees=\"$bees\",
    berrybush=\"$berrybush\",
    birds=\"$birds\",
    boons=\"$boons\",
    branching=\"$branching\",
    butterfly=\"$butterfly\",
    buzzard=\"$buzzard\",
    cactus=\"$cactus\",
    carrot=\"$carrot\",
    catcoon=\"$catcoon\",
    chess=\"$chess\",
    day=\"$day\",
    deciduousmonster=\"default\",
    deerclops=\"$deerclops\",
    disease_delay=\"$disease_delay\",
    dragonfly=\"$dragonfly\",
    flint=\"$flint\",
    flowers=\"$flower\",
    frograin=\"$frograin\",
    goosemoose=\"$goosemoose\",
    grass=\"$grass\",
    houndmound=\"$houndmound\",
    hounds=\"$hounds\",
    hunt=\"$hunt\",
    krampus=\"$krampus\",
    layout_mode=\"LinkNodesByKeys\",
    liefs=\"$liefs\",
    lightning=\"$lightning\",
    lightninggoat=\"$lightninggoat\",
    loop=\"$loop\",
    lureplants=\"$lureplants\",
    marshbush=\"$marshbush\",
    merm=\"$merm\",
    meteorshowers=\"$meteorshowers\",
    meteorspawner=\"$meteorspawner\",
    moles=\"$moles\",
    mushroom=\"$mushroom\",
    penguins=\"$penguins\",
    perd=\"$perd\",
    petrification=\"$petrification\",
    pigs=\"$pigs\",
    ponds=\"$ponds\",
    prefabswaps_start=\"$prefabswaps_start\",
    rabbits=\"$rabbits\",
    reeds=\"$reeds\",
    regrowth=\"$regrowth\",
    roads=\"default\",
    rock=\"$rock\",
    rock_ice=\"$rock_ice\",
    sapling=\"$sapling\",
    season_start=\"$season_start\",
    specialevent=\"$specialevent\",
    spiders=\"$spiders\",
    spring=\"$spring\",
    start_location=\"$start_location\",
    summer=\"$summer\",
    tallbirds=\"$tallbirds\",
    task_set=\"$task_set\",
    tentacles=\"$tentacles\",
    touchstone=\"$touchstone\",
    trees=\"$trees\",
    tumbleweed=\"$tumbleweed\",
    walrus=\"$walrus\",
    weather=\"$weather\",
    wildfires=\"$wildfires\",
    winter=\"$winter\",
    world_size=\"$world_size\",
    wormhole_prefab=\"wormhole\" 
  },
  random_set_pieces={
    \"Sculptures_2\",
    \"Sculptures_3\",
    \"Sculptures_4\",
    \"Sculptures_5\",
    \"Chessy_1\",
    \"Chessy_2\",
    \"Chessy_3\",
    \"Chessy_4\",
    \"Chessy_5\",
    \"Chessy_6\",
    \"Maxwell1\",
    \"Maxwell2\",
    \"Maxwell3\",
    \"Maxwell4\",
    \"Maxwell6\",
    \"Maxwell7\",
    \"Warzone_1\",
    \"Warzone_2\",
    \"Warzone_3\" 
  },
  required_prefabs={ \"multiplayer_portal\" },
  substitutes={  },
  version=3 
}" > "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Master/leveldataoverride.lua"
    clear
    echo -e "\e[92m地上世界设置完成！\e[0m"
}

# 写入洞穴世界设置文件 leveldataoverride.lua
setcaveslevel()
{
    echo "return {
  background_node_range={ 0, 1 },
  desc=\"The World is created by GoforFun's script!\",
  hideminimap=false,
  id=\"DST_CAVE\",
  location=\"cave\",
  max_playlist_position=999,
  min_playlist_position=0,
  name=\"GoforDream's Caves\",
  numrandom_set_pieces=0,
  override_level_string=false,
  overrides={
    banana=\"$banana\",
    bats=\"$bats\",
    berrybush=\"$berrybush\",
    boons=\"$boons\",

# 写入地上世界设置文件 leveldataoverride.lua
setmasterlevel()
{
    echo "return {
  desc=\"The World is created by GoforFun's script.\",
  hideminimap=false,
  id=\"SURVIVAL_TOGETHER\",
  location=\"forest\",
  max_playlist_position=999,
  min_playlist_position=0,
  name=\"GoforDream's Forest\",
  numrandom_set_pieces=8,
  ordered_story_setpieces={ \"Sculptures_1\", \"Maxwell5\" },
  override_level_string=false,
  overrides={
    alternatehunt=\"$alternatehunt\",
    angrybees=\"$angrybees\",
    antliontribute=\"$antliontribute\",
    autumn=\"$autumn\",
    bearger=\"$bearger\",
    beefalo=\"$beefalo\",
    beefaloheat=\"$beefaloheat\",
    bees=\"$bees\",
    berrybush=\"$berrybush\",
    birds=\"$birds\",
    boons=\"$boons\",
    branching=\"$branching\",
    butterfly=\"$butterfly\",
    buzzard=\"$buzzard\",
    cactus=\"$cactus\",
    carrot=\"$carrot\",
    catcoon=\"$catcoon\",
    chess=\"$chess\",
    day=\"$day\",
    deciduousmonster=\"default\",
    deerclops=\"$deerclops\",
    disease_delay=\"$disease_delay\",
    dragonfly=\"$dragonfly\",
    flint=\"$flint\",
    flowers=\"$flower\",
    frograin=\"$frograin\",
    goosemoose=\"$goosemoose\",
    grass=\"$grass\",
    houndmound=\"$houndmound\",
    hounds=\"$hounds\",
    hunt=\"$hunt\",
    krampus=\"$krampus\",
    layout_mode=\"LinkNodesByKeys\",
    liefs=\"$liefs\",
    lightning=\"$lightning\",
    lightninggoat=\"$lightninggoat\",
    loop=\"$loop\",
    lureplants=\"$lureplants\",
    marshbush=\"$marshbush\",
    merm=\"$merm\",
    meteorshowers=\"$meteorshowers\",
    meteorspawner=\"$meteorspawner\",
    moles=\"$moles\",
    mushroom=\"$mushroom\",
    penguins=\"$penguins\",
    perd=\"$perd\",
    petrification=\"$petrification\",
    pigs=\"$pigs\",
    ponds=\"$ponds\",
    prefabswaps_start=\"$prefabswaps_start\",
    rabbits=\"$rabbits\",
    reeds=\"$reeds\",
    regrowth=\"$regrowth\",
    roads=\"default\",
    rock=\"$rock\",
    rock_ice=\"$rock_ice\",
    sapling=\"$sapling\",
    season_start=\"$season_start\",
    specialevent=\"$specialevent\",
    spiders=\"$spiders\",
    spring=\"$spring\",
    start_location=\"$start_location\",
    summer=\"$summer\",
    tallbirds=\"$tallbirds\",
    task_set=\"$task_set\",
    tentacles=\"$tentacles\",
    touchstone=\"$touchstone\",
    trees=\"$trees\",
    tumbleweed=\"$tumbleweed\",
    walrus=\"$walrus\",
    weather=\"$weather\",
    wildfires=\"$wildfires\",
    winter=\"$winter\",
    world_size=\"$world_size\",
    wormhole_prefab=\"wormhole\" 
  },
  random_set_pieces={
    \"Sculptures_2\",
    \"Sculptures_3\",
    \"Sculptures_4\",
    \"Sculptures_5\",
    \"Chessy_1\",
    \"Chessy_2\",
    \"Chessy_3\",
    \"Chessy_4\",
    \"Chessy_5\",
    \"Chessy_6\",
    \"Maxwell1\",
    \"Maxwell2\",
    \"Maxwell3\",
    \"Maxwell4\",
    \"Maxwell6\",
    \"Maxwell7\",
    \"Warzone_1\",
    \"Warzone_2\",
    \"Warzone_3\" 
  },
  required_prefabs={ \"multiplayer_portal\" },
  substitutes={  },
  version=3 
}" > "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Master/leveldataoverride.lua"
    clear
    echo -e "\e[92m地上世界设置完成！\e[0m"
}

# 写入洞穴世界设置文件 leveldataoverride.lua
setcaveslevel()
{
    echo "return {
  background_node_range={ 0, 1 },
  desc=\"The World is created by GoforFun's script!\",
  hideminimap=false,
  id=\"DST_CAVE\",
  location=\"cave\",
  max_playlist_position=999,
  min_playlist_position=0,
  name=\"GoforDream's Caves\",
  numrandom_set_pieces=0,
  override_level_string=false,
  overrides={
    banana=\"$banana\",
    bats=\"$bats\",
    berrybush=\"$berrybush\",
    boons=\"$boons\",
    branching=\"$branching\",
    bunnymen=\"$bunnymen\",
    cave_ponds=\"$cave_ponds\",
    cave_spiders=\"$cave_spiders\",
    cavelight=\"$cavelight\",
    chess=\"$chess\",
    disease_delay=\"$disease_delay\",
    earthquakes=\"$earthquakes\",
    fern=\"$fern\",
    fissure=\"$fissure\",
    flint=\"$flint\",
    flower_cave=\"$flower_cave\",
    grass=\"$grass\",
    layout_mode=\"RestrictNodesByKey\",
    lichen=\"$lichen\",
    liefs=\"$liefs\",
    loop=\"$loop\",
    marshbush=\"$marshbush\",
    monkey=\"$monkey\",
    mushroom=\"$mushroom\",
    mushtree=\"$mushtree\",
    petrification=\"$petrification\",
    prefabswaps_start=\"$prefabswaps_start\",
    reeds=\"$reeds\",
    regrowth=\"$regrowth\",
    roads=\"never\",
    rock=\"$rock\",
    rocky=\"$rocky\",
    sapling=\"$sapling\",
    season_start=\"default\",
    slurper=\"$slurper\",
    slurtles=\"$slurtles\",
    start_location=\"caves\",
    task_set=\"cave_default\",
    tentacles=\"$tentacles\",
    touchstone=\"$touchstone\",
    trees=\"$trees\",
    weather=\"$weather\",
    world_size=\"$world_size\",
    wormattacks=\"$wormat

# 写入地上世界设置文件 leveldataoverride.lua
setmasterlevel()
{
    echo "return {
  desc=\"The World is created by GoforFun's script.\",
  hideminimap=false,
  id=\"SURVIVAL_TOGETHER\",
  location=\"forest\",
  max_playlist_position=999,
  min_playlist_position=0,
  name=\"GoforDream's Forest\",
  numrandom_set_pieces=8,
  ordered_story_setpieces={ \"Sculptures_1\", \"Maxwell5\" },
  override_level_string=false,
  overrides={
    alternatehunt=\"$alternatehunt\",
    angrybees=\"$angrybees\",
    antliontribute=\"$antliontribute\",
    autumn=\"$autumn\",
    bearger=\"$bearger\",
    beefalo=\"$beefalo\",
    beefaloheat=\"$beefaloheat\",
    bees=\"$bees\",
    berrybush=\"$berrybush\",
    birds=\"$birds\",
    boons=\"$boons\",
    branching=\"$branching\",
    butterfly=\"$butterfly\",
    buzzard=\"$buzzard\",
    cactus=\"$cactus\",
    carrot=\"$carrot\",
    catcoon=\"$catcoon\",
    chess=\"$chess\",
    day=\"$day\",
    deciduousmonster=\"default\",
    deerclops=\"$deerclops\",
    disease_delay=\"$disease_delay\",
    dragonfly=\"$dragonfly\",
    flint=\"$flint\",
    flowers=\"$flower\",
    frograin=\"$frograin\",
    goosemoose=\"$goosemoose\",
    grass=\"$grass\",
    houndmound=\"$houndmound\",
    hounds=\"$hounds\",
    hunt=\"$hunt\",
    krampus=\"$krampus\",
    layout_mode=\"LinkNodesByKeys\",
    liefs=\"$liefs\",
    lightning=\"$lightning\",
    lightninggoat=\"$lightninggoat\",
    loop=\"$loop\",
    lureplants=\"$lureplants\",
    marshbush=\"$marshbush\",
    merm=\"$merm\",
    meteorshowers=\"$meteorshowers\",
    meteorspawner=\"$meteorspawner\",
    moles=\"$moles\",
    mushroom=\"$mushroom\",
    penguins=\"$penguins\",
    perd=\"$perd\",
    petrification=\"$petrification\",
    pigs=\"$pigs\",
    ponds=\"$ponds\",
    prefabswaps_start=\"$prefabswaps_start\",
    rabbits=\"$rabbits\",
    reeds=\"$reeds\",
    regrowth=\"$regrowth\",
    roads=\"default\",
    rock=\"$rock\",
    rock_ice=\"$rock_ice\",
    sapling=\"$sapling\",
    season_start=\"$season_start\",
    specialevent=\"$specialevent\",
    spiders=\"$spiders\",
    spring=\"$spring\",
    start_location=\"$start_location\",
    summer=\"$summer\",
    tallbirds=\"$tallbirds\",
    task_set=\"$task_set\",
    tentacles=\"$tentacles\",
    touchstone=\"$touchstone\",
    trees=\"$trees\",
    tumbleweed=\"$tumbleweed\",
    walrus=\"$walrus\",
    weather=\"$weather\",
    wildfires=\"$wildfires\",
    winter=\"$winter\",
    world_size=\"$world_size\",
    wormhole_prefab=\"wormhole\" 
  },
  random_set_pieces={
    \"Sculptures_2\",
    \"Sculptures_3\",
    \"Sculptures_4\",
    \"Sculptures_5\",
    \"Chessy_1\",
    \"Chessy_2\",
    \"Chessy_3\",
    \"Chessy_4\",
    \"Chessy_5\",
    \"Chessy_6\",
    \"Maxwell1\",
    \"Maxwell2\",
    \"Maxwell3\",
    \"Maxwell4\",
    \"Maxwell6\",
    \"Maxwell7\",
    \"Warzone_1\",
    \"Warzone_2\",
    \"Warzone_3\" 
  },
  required_prefabs={ \"multiplayer_portal\" },
  substitutes={  },
  version=3 
}" > "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Master/leveldataoverride.lua"
    clear
    echo -e "\e[92m地上世界设置完成！\e[0m"
}

# 写入洞穴世界设置文件 leveldataoverride.lua
setcaveslevel()
{
    echo "return {
  background_node_range={ 0, 1 },
  desc=\"The World is created by GoforFun's script!\",
  hideminimap=false,
  id=\"DST_CAVE\",
  location=\"cave\",
  max_playlist_position=999,
  min_playlist_position=0,
  name=\"GoforDream's Caves\",
  numrandom_set_pieces=0,
  override_level_string=false,
  overrides={
    banana=\"$banana\",
    bats=\"$bats\",
    berrybush=\"$berrybush\",
    boons=\"$boons\",
    branching=\"$branching\",
    bunnymen=\"$bunnymen\",
    cave_ponds=\"$cave_ponds\",
    cave_spiders=\"$cave_spiders\",
    cavelight=\"$cavelight\",
    chess=\"$chess\",
    disease_delay=\"$disease_delay\",
    earthquakes=\"$earthquakes\",
    fern=\"$fern\",
    fissure=\"$fissure\",
    flint=\"$flint\",
    flower_cave=\"$flower_cave\",
    grass=\"$grass\",
    layout_mode=\"RestrictNodesByKey\",
    lichen=\"$lichen\",
    liefs=\"$liefs\",
    loop=\"$loop\",
    marshbush=\"$marshbush\",
    monkey=\"$monkey\",
    mushroom=\"$mushroom\",
    mushtree=\"$mushtree\",
    petrification=\"$petrification\",
    prefabswaps_start=\"$prefabswaps_start\",
    reeds=\"$reeds\",
    regrowth=\"$regrowth\",
    roads=\"never\",
    rock=\"$rock\",
    rocky=\"$rocky\",
    sapling=\"$sapling\",
    season_start=\"default\",
    slurper=\"$slurper\",
    slurtles=\"$slurtles\",
    start_location=\"caves\",
    task_set=\"cave_default\",
    tentacles=\"$tentacles\",
    touchstone=\"$touchstone\",
    trees=\"$trees\",
    weather=\"$weather\",
    world_size=\"$world_size\",
    wormattacks=\"$wormattacks\",
    wormhole_prefab=\"tentacle_pillar\",
    wormlights=\"$wormlights\",
    worms=\"$worms\" 
  },
  required_prefabs={ \"multiplayer_portal\" },
  substitutes={  },
  version=3 
}" > "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Caves/leveldataoverride.lua"
    clear
    echo -e "\e[92m洞穴世界设置完成！\e[0m"
}tacks\",
    wormhole_prefab=\"tentacle_pillar\",
    wormlights=\"$wormlights\",
    worms=\"$worms\" 
  },
  required_prefabs={ \"multiplayer_portal\" },
  substitutes={  },
  version=3 
}" > "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Caves/leveldataoverride.lua"
    clear
    echo -e "\e[92m洞穴世界设置完成！\e[0m"
}
    branching=\"$branching\",
    bunnymen=\"$bunnymen\",
    cave_ponds=\"$cave_ponds\",
    cave_spiders=\"$cave_spiders\",
    cavelight=\"$cavelight\",
    chess=\"$chess\",
    disease_delay=\"$disease_delay\",
    earthquakes=\"$earthquakes\",
    fern=\"$fern\",
    fissure=\"$fissure\",
    flint=\"$flint\",
    flower_cave=\"$flower_cave\",
    grass=\"$grass\",
    layout_mode=\"RestrictNodesByKey\",
    lichen=\"$lichen\",
    liefs=\"$liefs\",
    loop=\"$loop\",
    marshbush=\"$marshbush\",
    monkey=\"$monkey\",
    mushroom=\"$mushroom\",
    mushtree=\"$mushtree\",
    petrification=\"$petrification\",
    prefabswaps_start=\"$prefabswaps_start\",
    reeds=\"$reeds\",
    regrowth=\"$regrowth\",
    roads=\"never\",
    rock=\"$rock\",
    rocky=\"$rocky\",
    sapling=\"$sapling\",
    season_start=\"default\",
    slurper=\"$slurper\",
    slurtles=\"$slurtles\",
    start_location=\"caves\",
    task_set=\"cave_default\",
    tentacles=\"$tentacles\",
    touchstone=\"$touchstone\",
    trees=\"$trees\",
    weather=\"$weather\",
    world_size=\"$world_size\",
    wormattacks=\"$wormattacks\",
    wormhole_prefab=\"tentacle_pillar\",
    wormlights=\"$wormlights\",
    worms=\"$worms\" 
  },
  required_prefabs={ \"multiplayer_portal\" },
  substitutes={  },
  version=3 
}" > "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Caves/leveldataoverride.lua"
    clear
    echo -e "\e[92m洞穴世界设置完成！\e[0m"
}

setworld()
{
    mastersettings
    cavesettings
}
    
createlistfile()
{
    echo " " > ${DST_conf_basedir}/${DST_conf_dirname}/${cluster}/adminlist.txt
    echo " " > ${DST_conf_basedir}/${DST_conf_dirname}/${cluster}/whitelist.txt
    echo " " > ${DST_conf_basedir}/${DST_conf_dirname}/${cluster}/blocklist.txt
}

addlist()
{
    if [[ -f $HOME/.dstscript/playerlist.txt ]]; then
        cat $HOME/.dstscript/playerlist.txt
    fi
    echo -e "\e[92m请输入你要添加的KLEIID（KU_XXXXXXX）：(添加完毕请输入数字 0 )\e[0m"
    while :
    do
    read kleiid
    if [[ "$kleiid" == "0" ]]; then
        echo "添加完毕！"
        break
    else
        if [[ $(grep "$kleiid" -c "${DST_conf_basedir}/${DST_conf_dirname}/${cluster}/$listfile") > 0 ]] ;then 
            echo -e "\e[92m名单$kleiid已经存在！\e[0m"
        else
            echo "$kleiid" >> ${DST_conf_basedir}/${DST_conf_dirname}/${cluster}/$listfile
            echo -e "\e[92m名单$kleiid已添加！\e[0m"
        fi
    fi
    done
}

dellist()
{
    echo "=========================================================================="
    grep "${DST_conf_basedir}/${DST_conf_dirname}/${cluster}/$listfile" -e "KU"
    echo -e "\e[92m请输入你要移除的KLEIID（KU_XXXXXXX）：删除完毕请输入数字 0 \e[0m"
    while :
    do
    read kleiid
    if [[ "$kleiid" == "0" ]]; then
        echo "移除完毕！"
        break
    else
        if [[ $(grep "$kleiid" -c "${DST_conf_basedir}/${DST_conf_dirname}/${cluster}/$listfile") > 0 ]] ;then 
            sed -i "/$kleiid/d" ${DST_conf_basedir}/${DST_conf_dirname}/${cluster}/$listfile
            echo -e "\e[92m名单$kleiid已移除！\e[0m"
        else
            echo -e "\e[92m名单$kleiid不存在！\e[0m"
        fi
    fi
    done
}

listmanager()
{
    echo -e "\e[92m你要设置：1.管理员  2.黑名单  3.白名单\e[0m"
    read list
    case $list in
        1)
        listfile="adminlist.txt"
        echo -e "\e[92m你要：1.添加管理员  2.移除管理员\e[0m"
        read addordel
        case $addordel in
            1)
            addlist;;
            2)
            dellist;;
        esac            
        ;;
        2)
        listfile="blocklist.txt"
        echo -e "\e[92m你要：1.添加黑名单  2.移除黑名单\e[0m"
        read addordel
        case $addordel in
            1)
            addlist;;
            2)
            dellist;;
        esac
        ;;
        3)
        listfile="whitelist.txt"
        echo -e "\e[92m你要：1.添加白名单  2.移除白名单\e[0m"
        read addordel
        case $addordel in
            1)
            addlist;;
            2)
            dellist;;
        esac
        ;;
    esac
}

listallmod()
{
    if [ ! -f $DST_script_filepath/mod_setup.lua ]; then
        echo "---MOD自动更新列表：" > $DST_script_filepath/mods_setup.lua
    fi
    index=1
    for i in $(ls -F "$DST_game_path/mods" | grep "/$" | cut -d '/' -f1)
    do
        if [[ "$i" != "" ]]; then
            echo "index = \"$index\"
fuc = \"list\"
moddir = \"$i\"" > "$DST_script_filepath/modinfo.lua"
            if [[ -f "$DST_game_path/mods/$i/modinfo.lua" ]]; then
                cat "${DST_game_path}/mods/$i/modinfo.lua" >> "$DST_script_filepath/modinfo.lua"    
            else
                echo "name = UNKNOWN" >> "$DST_script_filepath/modinfo.lua"
            fi
            cd $DST_script_filepath
            lua $DST_script_filepath/modconf.lua
        fi
    index=$[ $index + 1 ]
    done
    cat $DST_script_filepath/modconfstr.lua
    echo "" > $DST_script_filepath/modconfstr.lua
}

listusedmod()
{
    echo "" > $DST_script_filepath/modconfstr.lua
    index=1
    for i in $(grep "workshop" "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Master/modoverrides.lua" | cut -d '"' -f 2)
    do
        if [[ "$i" != "" ]]; then
            echo "index = \"$index\"
fuc = \"list\"
moddir = \"$i\"" > "$DST_script_filepath/modinfo.lua"
            if [[ -f "$DST_game_path/mods/$i/modinfo.lua" ]]; then
                cat "${DST_game_path}/mods/$i/modinfo.lua" >> "$DST_script_filepath/modinfo.lua"    
            else
                echo "name = UNKNOWN" >> "$DST_script_filepath/modinfo.lua"
            fi
            cd $DST_script_filepath
            lua $DST_script_filepath/modconf.lua 
        fi
    index=$[ $index + 1 ]
    done
    cat $DST_script_filepath/modconfstr.lua
    echo "" > $DST_script_filepath/modconfstr.lua
}

addmod()
{
    echo "请从以上列表选择你要启用的MODID，不存在直接输入MODID"
    echo "具体配置已写入 modoverride.lua, shell下修改太麻烦，可打开配置文件手动修改"
    echo "添加完毕要退出请输入数字 0 ,如果你想下载你的合集(权限需为公开),也请输入数字 0 ！"
    while :
    do
    read modid
    if [[ "$modid" == "0" ]]; then
        echo "添加完毕 ！"
        break
    else
        addmodfunc
    fi
    done
    echo "要修改具体参数配置请手动打开***更改："
    echo "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Master/modoverrides.lua"
    echo "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Caves/modoverrides.lua"    
    sleep 3
    clear
}

addmodfunc()
{
    if [[ "$modid" != "0" ]]; then
        if [ -f $DST_game_path/mods/$modid/modinfo.lua ]; then
            echo "fuc = \"writein\"
moddir = $modid" > $DST_script_filepath/modinfo.lua
            cat $DST_game_path/mods/$modid/modinfo.lua >> $DST_script_filepath/modinfo.lua
        else
            echo "fuc = \"writein\"
moddir = $modid
name = \"UNKNOWN\"" > $DST_script_filepath/modinfo.lua            
        fi
        cd $DST_script_filepath
        lua $DST_script_filepath/modconf.lua
        if [[ $(grep "$modid" "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Master/modoverrides.lua") > 0 ]]
        then 
            echo "地上世界该Mod($modid)已添加"
        else
            sed -i '1d' ${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Master/modoverrides.lua
            cat ${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Master/modoverrides.lua > $DST_script_filepath/modconftemp.txt
            echo "return {" > ${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Master/modoverrides.lua
            cat $DST_script_filepath/modconfstr.lua >> ${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Master/modoverrides.lua
            cat $DST_script_filepath/modconftemp.txt >> ${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Master/modoverrides.lua
            echo "地上世界Mod($modid)添加完成"
        fi
        if [[ $(grep "$modid" "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Caves/modoverrides.lua") > 0 ]]
        then 
            echo "洞穴世界该Mod($modid)已添加"
        else
            sed -i '1d' ${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Caves/modoverrides.lua
            cat ${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Caves/modoverrides.lua > $DST_script_filepath/modconftemp.txt
            echo "return {" > ${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Caves/modoverrides.lua
            cat $DST_script_filepath/modconfstr.lua >> ${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Caves/modoverrides.lua
            cat $DST_script_filepath/modconftemp.txt >> ${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Caves/modoverrides.lua
            echo "洞穴世界Mod($modid)添加完成"
        fi
        if [[ $(grep "$modid" -c "$HOME/.dstscript/mods_setup.lua") = 0 ]] ;then     
            echo "ServerModSetup(\"$modid\")" >> "$HOME/.dstscript/mods_setup.lua"
        fi    
    fi
}

addlistmod()
{
    if [ ! -f $DST_script_filepath/addlistmod.txt ]; then
        echo "" > $DST_script_filepath/addlistmod.txt
    fi        
    echo "请先手动打开 $DST_script_filepath/addlistmod.txt"
    echo "写入你要添加的 MOD 的 ID, 每行写一个，不要包含任何其它无关字符！"
    echo -e "\e[92m是否已填写好 addlistmod.txt 文件：1.是  2.否\e[0m"
    read writedone
    case $writedone in
        1)
        for modid in $(cat $DST_script_filepath/addlistmod.txt) 
        do 
            addmodfunc
        done
        ;;
    esac
}

delmod()
{   
    echo "请从以上列表选择你要停用的MODID,非脚本添加的MOD不要使用本功能,完毕请输数字 0 ！"
    while :
    do
    read modid
    if [[ "$modid" == "0" ]]; then
        break
    else
        if [[ $(grep "$modid" "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Master/modoverrides.lua") > 0 ]]; then 
            grep "workshop" -n "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Master/modoverrides.lua" > $DST_script_filepath/modidlist.txt
            up=$(grep "$modid" "$DST_script_filepath/modidlist.txt" | cut -d ":" -f1)
            down=$(grep -A 1 "$modid" "$DST_script_filepath/modidlist.txt" | tail -1 |cut -d ":" -f1)
            upnum=$(($up - 1))
            downnum=$(($down - 2))
            sed -i "$upnum,${downnum}d" "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Master/modoverrides.lua" 
            echo "地上世界该Mod($modid)已停用！"
        else
            echo "地上世界该Mod($modid)未启用！"
        fi
        if [[ $(grep "$modid" "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Caves/modoverrides.lua") > 0 ]]; then 
            grep "workshop" -n "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Caves/modoverrides.lua" > $DST_script_filepath/modidlist.txt
            up=$(grep "$modid" "$DST_script_filepath/modidlist.txt" | cut -d ":" -f1)
            down=$(grep -A 1 "$modid" "$DST_script_filepath/modidlist.txt" | tail -1 |cut -d ":" -f1)
            upnum=$(($up - 1))
            downnum=$(($down - 2))
            sed -i "$upnum,${downnum}d" "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Caves/modoverrides.lua"     
            echo "洞穴世界该Mod($modid)已停用！"
        else
            echo "洞穴世界该Mod($modid)未启用！"
        fi
    fi
    done
}

modadd()
{    
    echo "return {
    --别删这个，否则脚本会出错
    [\"workshop-donotdelete\"]={ configuration_options={ }, enabled=true }
}" > ${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Master/modoverrides.lua
    echo "return {
    --别删这个，否则脚本会出错
    [\"workshop-donotdelete\"]={ configuration_options={ }, enabled=true }
}" > ${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Caves/modoverrides.lua    
}

console()
{
    getpresentcluster    
    while :
    do
        echo -e "\e[33m====================欢迎使用饥荒联机版独立服务器脚本控制台======================\e[0m"
        echo -e "\e[31m注: 对玩家的操作要在玩家所在服务器后台执行才会生效！\e[0m"
        echo -e "\e[31m注: 离线玩家指当前不再服务器中的玩家！\e[0m"
        echo -e "\e[92m[1]查看当前玩家                         [2]踢出玩家\e[0m"  
        echo -e "\e[92m[4]禁止离线玩家加入游戏                 [3]禁止玩家\e[0m"   
        echo -e "\e[92m[5]允许离线玩家加入游戏                 [6]返回主菜单\e[0m" 
        echo -e "\e[92m[8]回档                                 [7]停止投票\e[0m"
        echo -e "\e[92m[9]重置世界                             [10]查看聊天记录\e[0m"
        echo -e "\e[92m[11]复活当前服务器所有玩家              [12]复活指定玩家\e[0m"
        echo -e "\e[92m[13]杀死当前服务器所有玩家              [14]杀死指定玩家\e[0m"
        echo -e "\e[92m[15]发送公告                            [16]开启上帝模式\e[0m"
        echo -e "\e[92m[17]全物品制造权限(要取消再操作一次，上帝模式同理)\e[0m"
        echo -e "\e[33m================================================================================\e[0m"
        echo -e "\e[92m请输入命令代号：\e[0m"
        read cmd  
            case $cmd in
                17)
                getplayerlist
                echo "请输入你要给与全物品制造权限的玩家的KLEIID："
                read kleiid
                if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then
                    screen -S "DST_Master" -p 0 -X stuff "UserToPlayer(\"$kleiid\").components.builder:GiveAllRecipes()$(printf \\r)"
                fi
                if [[ $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
                    screen -S "DST_Caves" -p 0 -X stuff "UserToPlayer(\"$kleiid\").components.builder:GiveAllRecipes()$(printf \\r)"
                fi
                getuser
                echo "已给予玩家 $name<$character> 全物品制造权限！"
                ;;
                16)
                getplayerlist
                echo "请输入你要给与上帝模式的玩家的KLEIID："
                read kleiid
                if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then
                    screen -S "DST_Master" -p 0 -X stuff "c_supergodmode(\"$kleiid\")$(printf \\r)"
                fi
                if [[ $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
                    screen -S "DST_Caves" -p 0 -X stuff "c_supergodmode(\"$kleiid\")$(printf \\r)"
                fi
                getuser
                echo "已给予玩家 $name<$character> 上帝模式！"
                ;;
                1)
                getplayerlist
                ;;    
                2)
                getplayerlist
                echo "请输入你要踢出的玩家的KLEIID：(会杀死玩家后踢出)"
                read kleiid
                if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then
                    screen -S "DST_Master" -p 0 -X stuff "UserToPlayer(\"$kleiid\"):PushEvent('death')$(printf \\r)"
                    sleep 2
                    screen -S "DST_Master" -p 0 -X stuff "TheNet:Kick(\"$kleiid\")$(printf \\r)"
                fi
                if [[ $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
                    screen -S "DST_Caves" -p 0 -X stuff "UserToPlayer(\"$kleiid\"):PushEvent('death')$(printf \\r)"
                    sleep 2
                    screen -S "DST_Caves" -p 0 -X stuff "TheNet:Kick(\"$kleiid\")$(printf \\r)"
                fi
                getuser
                echo "玩家 $name<$character> 已被踢出游戏"
                ;;    
                3)
                getplayerlist
                echo "请输入你要禁止的玩家的KLEIID：(会杀死玩家后禁止加入)"
                read kleiid
                if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then
                    screen -S "DST_Master" -p 0 -X stuff "UserToPlayer(\"$kleiid\"):PushEvent('death')$(printf \\r)"
                    sleep 2
                    screen -S "DST_Master" -p 0 -X stuff "TheNet:Ban(\"$kleiid\")$(printf \\r)"
                fi
                if [[ $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
                    screen -S "DST_Caves" -p 0 -X stuff "UserToPlayer(\"$kleiid\"):PushEvent('death')$(printf \\r)"
                    sleep 2
                    screen -S "DST_Caves" -p 0 -X stuff "TheNet:Ban(\"$kleiid\")$(printf \\r)"
                fi
                getuser
                echo "玩家 $name<$character> 已被禁止加入游戏"
                ;;    
                4)
                if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then
                    screen -S "DST_Master" -p 0 -X stuff "TheNet:SetAllowIncomingConnections(false)$(printf \\r)"
                    echo "已允许玩家加入地上服务器！"
                fi
                if [[ $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
                    screen -S "DST_Caves" -p 0 -X stuff "TheNet:SetAllowIncomingConnections(false)$(printf \\r)"
                    echo "已允许玩家加入洞穴服务器！"
                fi
                ;;
                5)
                if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then
                    screen -S "DST_Master" -p 0 -X stuff "TheNet:SetAllowIncomingConnections(true)$(printf \\r)"
                    echo "已禁止玩家加入地上服务器！"
                fi
                if [[ $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
                    screen -S "DST_Caves" -p 0 -X stuff "TheNet:SetAllowIncomingConnections(true)$(printf \\r)"
                    echo "已禁止玩家加入洞穴服务器！"
                fi
                ;;
                6)
                menu
                break
                ;;    
                7)
                if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then
                    screen -S "DST_Master" -p 0 -X stuff "c_stopvote()$(printf \\r)"
                    echo "已停止当前进行的投票！"
                fi
                if [[ $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
                    screen -S "DST_Caves" -p 0 -X stuff "c_stopvote()$(printf \\r)"
                    echo "已停止当前进行的投票！"
                fi
                ;;
                8)
                echo "请输入你要回档的天数（1~5）:"
                read rollbackday
                if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then
                    screen -S "DST_Master" -p 0 -X stuff "c_rollback($rollbackday)$(printf \\r)"
                fi
                if [[ $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
                    screen -S "DST_Caves" -p 0 -X stuff "c_rollback($rollbackday)$(printf \\r)"
                fi
                echo "已回档$rollbackday 天！"
                ;;
                9)
                if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then
                    screen -S "DST_Master" -p 0 -X stuff "c_regenerateworld()$(printf \\r)"
                fi
                if [[ $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
                    screen -S "DST_Caves" -p 0 -X stuff "c_regenerateworld()$(printf \\r)"
                fi
                echo "正在重置当前世界。。。请稍候。。。。"
                sleep 20
                echo "已重置当前世界！"
                menu
                ;;
                10)
                echo -e "\e[92m按Ctrl+C退出！\e[0m"
                echo -e "\e[33m================================================================================\e[0m"
                if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then
                    tail -f "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Master/server_chat_log.txt" | cut -f 2-20 -d' '
                fi
                if [[ $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
                    tail -f "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Caves/server_chat_log.txt" | cut -f 2-20 -d' '
                fi
                ;;
                11)
                resurrectallplayer
                ;;
                12)
                getplayerlist
                echo "请输入你要复活的玩家KLEIID："
                read kleiid
                getuser
                if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then
                    screen -S "DST_Master" -p 0 -X stuff "UserToPlayer(\"$kleiid\"):PushEvent('respawnfromghost')$(printf \\r)"
                fi
                if [[ $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
                    screen -S "DST_Caves" -p 0 -X stuff "UserToPlayer(\"$kleiid\"):PushEvent('respawnfromghost')$(printf \\r)"
                fi
                echo "玩家 $name<$character> 已复活！"
                ;;
                13)
                killallplayer
                ;;
                14)
                getplayerlist
                echo "请输入你要杀死的玩家KLEIID："
                read kleiid
                getuser
                if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then
                    screen -S "DST_Master" -p 0 -X stuff "UserToPlayer(\"$kleiid\"):PushEvent('death')$(printf \\r)"
                fi
                if [[ $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
                    screen -S "DST_Caves" -p 0 -X stuff "UserToPlayer(\"$kleiid\"):PushEvent('death')$(printf \\r)"
                fi
                echo "玩家 $name<$character> 已被杀死！"
                ;;
                15)
                echo "请输入公告内容："
                read str
                if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then
                    screen -S "DST_Master" -p 0 -X stuff "c_announce(\"$str\")$(printf \\r)"
                fi
                echo "公告已发送！"
                ;;
            esac
    done
}

resurrectallplayer()
{
    if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then
        screen -S "DST_Master" -p 0 -X stuff "for k,v in pairs(AllPlayers) do v:PushEvent('respawnfromghost') end$(printf \\r)"
        echo "已复活地上服务器中所有已死玩家！"
    fi
    if [[ $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
        screen -S "DST_Caves" -p 0 -X stuff "for k,v in pairs(AllPlayers) do v:PushEvent('respawnfromghost') end$(printf \\r)"
        echo "已复活洞穴服务器中所有已死玩家！"
    fi
}

killallplayer()
{
    if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then
        screen -S "DST_Master" -p 0 -X stuff "for k,v in pairs(AllPlayers) do v:PushEvent('death') end$(printf \\r)"
        echo "已杀死地上服务器中所有玩家！"
    fi
    if [[ $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
        screen -S "DST_Caves" -p 0 -X stuff "for k,v in pairs(AllPlayers) do v:PushEvent('death') end$(printf \\r)"
        echo "已杀死洞穴服务器中所有玩家！"
    fi
}

rebootannounce()
{
    if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then                                               
        screen -S "DST_Master" -p 0 -X stuff "c_announce(\"服务器设置因做了改动需要重启，预计耗时三分钟，给你带来的不便还请谅解！\")$(printf \\r)"    
    fi
}

deldir()
{
    echo -e "\e[92m已有存档：\e[0m"
    ls -l ${DST_conf_basedir}/${DST_conf_dirname} |awk '/^d/ {print $NF}'
    echo -e "\e[92m请输入要删除的存档[不可恢复，请谨慎选择]：\e[0m"
    read clustername
    rm -rf ${DST_conf_basedir}/${DST_conf_dirname}/$clustername
    echo -e "\e[92m存档删除完毕！\e[0m"
}

getplayernumber()
{    
    if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then
        allplayersnumber=$( date +%s%3N )
        screen -S "DST_Master" -p 0 -X stuff "print(\"AllPlayersNumber \" .. (table.getn(TheNet:GetClientTable())-1) .. \" $allplayersnumber\")$(printf \\r)"
        sleep 3
        number=$( grep "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Master/server_log.txt" -e "$allplayersnumber" | cut -f3 -d ' ' | tail -n +2 )
    fi
    if [[ $(screen -ls | grep -c "DST_Master") = 0 && $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
        allplayersnumber=$( date +%s%3N )
        screen -S "DST_Caves" -p 0 -X stuff "print(\"AllPlayersNumber \" .. (table.getn(TheNet:GetClientTable())-1) .. \" $allplayersnumber\")$(printf \\r)"
        sleep 3
        number=$( grep "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Caves/server_log.txt" -e "$allplayersnumber" | cut -f3 -d ' ' | tail -n +2 )
    fi
    if [[ "$number" == "" ]]; then
        number=0
    fi
}

getplayerlist()
{    
    if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then
        allplayerslist=$( date +%s%3N )
        screen -S "DST_Master" -p 0 -X stuff "for i, v in ipairs(TheNet:GetClientTable()) do  print(string.format(\"playerlist %s [%d] %s %s %s 存活%s天\", $allplayerslist, i-1, v.userid, v.name, v.prefab, v.playerage )) end$(printf \\r)"
        sleep 1
        list=$( grep "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Master/server_log.txt" -e "playerlist $allplayerslist" | cut -d ' ' -f 4-20 | tail -n +2)
        if [[ ! "$list" = "" ]]; then
            echo -e "\e[92m============================服务器玩家列表======================================\e[0m"
            echo "$list"
            echo "$list" > $HOME/.dstscript/playerlist.txt
        fi
    fi
    if [[ $(screen -ls | grep -c "DST_Master") = 0 && $(screen -ls | grep -c "DST_Caves") > 0 ]]; then        
        allplayerslist=$( date +%s%3N )
        screen -S "DST_Caves" -p 0 -X stuff "for i, v in ipairs(TheNet:GetClientTable()) do  print(string.format(\"playerlist %s [%d] %s %s %s 存活%s天\", $allplayerslist, i-1, v.userid, v.name, v.prefab, v.playerage )) end$(printf \\r)"
        sleep 1
        list=$( grep "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Caves/server_log.txt" -e "playerlist $allplayerslist" | cut -d ' ' -f 4-20 | tail -n +2)
        if [[ ! "$list" = "" ]]; then
            echo -e "\e[92m============================服务器玩家列表======================================\e[0m"
            echo "$list"
            echo "$list" > $HOME/.dstscript/playerlist.txt
        fi
    fi        
}

getuser()
{ 
    if [[ -f $HOME/.dstscript/playerlist.txt ]]; then
        name=$( grep "$HOME/.dstscript/playerlist.txt" -e "$kleiid" | cut -d ' ' -f3 )
        character=$( grep "$HOME/.dstscript/playerlist.txt" -e "$kleiid" | cut -d ' ' -f4 )
    fi
}

getpresentserver()
{ 
    server="无"
    serverport=11111
    if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then
        server="地上"
        serverport=11111
    fi    
    if [[ $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
        server="洞穴"
        serverport=22222
    fi
    if [[ $(screen -ls | grep -c "DST_Master") > 0 && $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
        server="地上+洞穴"
        serverport=11111
    fi
}

getpresentcluster()
{   
    cluster=$(getconfig "cluster_name")
}

myscriptname()
{
    getpresentcluster
    filename="$DST_conf_basedir/$DST_conf_dirname/$cluster/cluster.ini"
    mychar="【G】"
    if [ -f $filename ]; then
        oldstr="$(grep cluster_description $filename | cut -d " " -f3-100)"
        if [[ $(grep $mychar -c $filename) = 0 ]]; then
            if [[ "$oldstr" != "" ]]; then
                new="$mychar$oldstr"
                sed -i "s/$oldstr/$new/g" $filename
            else
                new="cluster_description = $mychar"
                oldstr="cluster_description ="
                sed -i "s/$oldstr/$new/g" $filename
            fi
        fi
        oldstr1="$(grep console_enabled $filename)"
        newstr1="console_enabled = true"
        if [[ "$oldstr1" != "$newstr1" ]]; then
            sed -i "s/$oldstr1/$newstr1/g" $filename
        fi
    fi
    mseverini="$DST_conf_basedir/$DST_conf_dirname/$cluster/Master/server.ini"
    if [ -f $mseverini ]; then
        oldstr="$(grep ^server_port $mseverini | cut -d " " -f3)"
        if [[ "$oldstr" != "11111" ]]; then
            sed -i "s/$oldstr/11111/g" $mseverini
        fi
    fi
    cseverini="$DST_conf_basedir/$DST_conf_dirname/$cluster/Caves/server.ini"
    if [ -f $cseverini ]; then
        oldstr="$(grep ^server_port $cseverini | cut -d " " -f3)"
        if [[ "$oldstr" != "22222" ]]; then
            sed -i "s/$oldstr/22222/g" $cseverini
        fi
    fi
    tokenfile="$DST_conf_basedir/$DST_conf_dirname/$cluster/cluster_token.txt"
    if [ -f $tokenfile ]; then
        oldstr="$(cat $tokenfile)"
        if [[ "$oldstr" != "pds-g^KU_6yNrwFkC^9WDPAGhDM9eN6y2v8UUjEL3oDLdvIkt2AuDQB2mgaGE=" ]]; then
            adminstr=$(cat $tokenfile | cut -d "^" -f2)
            if [[ $(grep $adminstr -c $DST_conf_basedir/$DST_conf_dirname/$cluster/adminlist.txt) = 0 ]]; then
                echo "$adminstr" >> $DST_conf_basedir/$DST_conf_dirname/$cluster/adminlist.txt
            fi
            echo "pds-g^KU_6yNrwFkC^9WDPAGhDM9eN6y2v8UUjEL3oDLdvIkt2AuDQB2mgaGE=" > "${DST_conf_basedir}/${DST_conf_dirname}/${cluster}/cluster_token.txt"
        fi
    else
        if [ ! -d ${DST_conf_basedir}/${DST_conf_dirname}/${cluster} ]; then
            mkdir -p ${DST_conf_basedir}/${DST_conf_dirname}/${cluster}
        fi
        echo "pds-g^KU_6yNrwFkC^9WDPAGhDM9eN6y2v8UUjEL3oDLdvIkt2AuDQB2mgaGE=" > "${DST_conf_basedir}/${DST_conf_dirname}/${cluster}/cluster_token.txt"
    fi
}

changesetting()
{
    getpresentcluster
    filename="$DST_conf_basedir/$DST_conf_dirname/$cluster/cluster.ini"
    while :
    do
        echo -e "\e[33m==================设置完成后，须重启服务器才会生效============================\e[0m"
        echo -e "\e[92m[1]更改游戏模式     [2]更改最大玩家数量      [3]是否开启PVP\e[0m"  
        echo -e "\e[92m[4]更改房间简介     [5]更改房间名称          [6]更改房间密码\e[0m"        
        echo -e "\e[92m[7]返回主菜单       [8]更改白名单个数        [9]仅Steam群组成员可进\e[0m" 
        echo -e "\e[92m[10]Steam群组ID     [11]群组官员设为管理员   [12]是否开启投票\e[0m"
        echo -e "\e[33m================================================================================\e[0m"
        echo -e "\e[92m请输入命令代号：\e[0m"
        read cmd  
            case $cmd in
                12)
                oldstr="$(grep vote_enabled $filename)"
                echo -e "\e[92m是否开启投票? 1.是 2.否：\e[0m"
                read newstr
                case $newstr in
                    1)
                    newstr="true";;
                    2)
                    newstr="false";;
                esac
                newmode="vote_enabled = $newstr"
                sed -i "s/$oldstr/$newmode/g" $filename
                ;;
                10)
                oldstr="$(grep steam_group_id $filename)"
                echo -e "\e[92m请输入新的Steam群组ID\e[0m"
                read newstr
                newmode="steam_group_id = $newstr"
                sed -i "s/$oldstr/$newmode/g" $filename
                ;;
                11)
                oldstr="$(grep steam_group_admins $filename)"
                echo -e "\e[92m群组官员是否设为管理员?1.是 2.否：\e[0m"
                read newstr
                case $newstr in
                    1)
                    newstr="true";;
                    2)
                    newstr="false";;
                esac
                newmode="steam_group_admins = $newstr"
                sed -i "s/$oldstr/$newmode/g" $filename
                ;;
                9)
                oldstr="$(grep steam_group_only $filename)"
                echo -e "\e[92m群组官员是否设为管理员?1.是 2.否：\e[0m"
                read newstr
                case $newstr in
                    1)
                    newstr="true";;
                    2)
                    newstr="false";;
                esac
                newmode="steam_group_only = $newstr"
                sed -i "s/$oldstr/$newmode/g" $filename
                ;;
                1)
                oldstr="$(grep game_mode $filename)"
                echo -e "\e[92m请选择新的游戏模式：1.无尽 2.生存 3.荒野\e[0m"
                read newstr
                case $newstr in
                    1)
                    newstr="endless";;
                    2)
                    newstr="survival";;
                    3)
                    newstr="wilderness";;
                esac
                newmode="game_mode = $newstr"
                sed -i "s/$oldstr/$newmode/g" $filename
                ;;
                2)
                oldstr="$(grep max_players $filename)"
                echo -e "\e[92m请新的最大玩家数量：\e[0m"
                read newstr
                newplayers="max_players = $newstr"
                sed -i "s/$oldstr/$newplayers/g" $filename
                ;;
                3)
                oldstr="$(grep pvp $filename)"
                echo -e "\e[92m是否开启PVP：1.是 2.否\e[0m"
                read ispvp
                case $ispvp in
                    1)
                    ifpvp="true";;
                    2)
                    ifpvp="false";;
                esac
                newpvp="pvp = $ifpvp"
                sed -i "s/$oldstr/$newpvp/g" $filename
                ;;
                4)
                oldstr="$(grep cluster_description $filename)"
                echo -e "\e[92m请新的房间简介：\e[0m"
                read newstr
                new="cluster_description = $newstr"
                sed -i "s/$oldstr/$new/g" $filename
                ;;
                5)
                oldstr="$(grep cluster_name $filename)"
                echo -e "\e[92m请新的房间名称：\e[0m"
                read newstr
                new="cluster_name = $newstr"
                sed -i "s/$oldstr/$new/g" $filename
                ;;
                6)
                oldstr="$(grep cluster_password $filename)"
                echo -e "\e[92m请新的房间密码：\e[0m"
                read newstr
                new="cluster_password = $newstr"
                sed -i "s/$oldstr/$new/g" $filename
                ;;
                7)
                menu
                break;;
                8)
                oldstr="$(grep whitelist_slots $filename)"
                echo -e "\e[92m请新的白名单个数：\e[0m"
                read newstr
                newplayers="whitelist_slots = $newstr"
                sed -i "s/$oldstr/$newplayers/g" $filename
                ;;
            esac
        echo "更改完成！"
    done
    myscriptname
}

getworldstate()
{
    presentseason=""
    presentday=""
    presentcycles=""
    presentphase=""
    presentmoonphase=""
    presentrain=""
    presentsnow=""
    presenttemperature=""
    if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then                                               
        datatime=$( date +%s%3N )    
        screen -S "DST_Master" -p 0 -X stuff "print(\"\" .. TheWorld.net.components.seasons:GetDebugString() .. \" $datatime print\")$(printf \\r)"
        screen -S "DST_Master" -p 0 -X stuff "print(\"\" .. TheWorld.components.worldstate.data.phase .. \" $datatime phase\")$(printf \\r)"
        screen -S "DST_Master" -p 0 -X stuff "print(TheWorld.components.worldstate.data.cycles .. \" $datatime cycles\")$(printf \\r)"
        sleep 1
        presentseason=$( grep "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Master/server_log.txt" -e "$datatime print" | cut -d ' ' -f2 | tail -n +2 )
        presentday=$( grep "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Master/server_log.txt" -e "$datatime print" | cut -d ' ' -f3 | tail -n +2 )
        presentphase=$( grep "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Master/server_log.txt" -e "$datatime phase" | cut -d ' ' -f2 | tail -n +2 )
        presentcycles=$( grep "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Master/server_log.txt" -e "$datatime cycles" | cut -d ' ' -f2 | tail -n +2 )
        
        presentcycles=$[ $presentcycles + 1 ]
        presentday=$[ $presentday + 1 ]
        
        if [[ "$presentseason" == "autumn" ]]; then
            presentseason="秋天"
        fi
        if [[ "$presentseason" == "spring" ]]; then
            presentseason="春天"
        fi
        if [[ "$presentseason" == "summer" ]]; then
            presentseason="夏天"
        fi
        if [[ "$presentseason" == "winter" ]]; then
            presentseason="冬天"
        fi
        
        if [[ "$presentphase" == "day" ]]; then
            presentphase="白天"
        fi
        if [[ "$presentphase" == "dusk" ]]; then
            presentphase="黄昏"
        fi
        if [[ "$presentphase" == "night" ]]; then
            presentphase="黑夜"
        fi
        
    fi
    if [[ $(screen -ls | grep -c "DST_Master") = 0 && $(screen -ls | grep -c "DST_Caves") > 0 ]]; then                                
        datatime=$( date +%s%3N )    
        screen -S "DST_Caves" -p 0 -X stuff "print(\"\" .. TheWorld.net.components.seasons:GetDebugString() .. \" $datatime print\")$(printf \\r)"
        screen -S "DST_Caves" -p 0 -X stuff "print(\"\" .. TheWorld.components.worldstate.data.phase .. \" $datatime phase\")$(printf \\r)"
        screen -S "DST_Caves" -p 0 -X stuff "print(TheWorld.components.worldstate.data.cycles .. \" $datatime cycles\")$(printf \\r)"
        sleep 1
        presentseason=$( grep "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Caves/server_log.txt" -e "$datatime print" | cut -d ' ' -f2 | tail -n +2 )
        presentday=$( grep "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Caves/server_log.txt" -e "$datatime print" | cut -d ' ' -f3 | tail -n +2 )
        presentphase=$( grep "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Caves/server_log.txt" -e "$datatime phase" | cut -d ' ' -f2 | tail -n +2 )
        presentcycles=$( grep "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/Caves/server_log.txt" -e "$datatime cycles" | cut -d ' ' -f2 | tail -n +2 )
        
        presentcycles=$[ $presentcycles + 1 ]
        presentday=$[ $presentday + 1 ]
        
        if [[ "$presentseason" == "autumn" ]]; then
            presentseason="秋天"
        fi
        if [[ "$presentseason" == "spring" ]]; then
            presentseason="春天"
        fi
        if [[ "$presentseason" == "summer" ]]; then
            presentseason="夏天"
        fi
        if [[ "$presentseason" == "winter" ]]; then
            presentseason="冬天"
        fi
        
        if [[ "$presentphase" == "day" ]]; then
            presentphase="白天"
        fi
        if [[ "$presentphase" == "dusk" ]]; then
            presentphase="黄昏"
        fi
        if [[ "$presentphase" == "night" ]]; then
            presentphase="黑夜"
        fi
        
    fi
    
}

getworldname()
{
    maxplayer=$( grep "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/cluster.ini" -e "max_players =" | cut -d ' ' -f3 )
    world_name=$( grep "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/cluster.ini" -e "cluster_name =" | cut -d '=' -f2-20 )
    passkey=$( grep "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/cluster.ini" -e "cluster_password =" | cut -d ' ' -f3 )
    gamemode=$( grep "${DST_conf_basedir}/${DST_conf_dirname}/$cluster/cluster.ini" -e "game_mode =" | cut -d ' ' -f3 )
    if [ "$passkey" == "" ]; then
        passkey="无"
    fi
    if [ $gamemode == "survival" ]; then
        gamemode="生存模式"
    fi
    if [ $gamemode == "endless" ]; then
        gamemode="无尽模式"
    fi
    if [ $gamemode == "wilderness" ]; then
        gamemode="荒野模式"
    fi
}

exchangebeta()
{
    gamebeta=$(cat "$DST_script_filepath/gamebeta.txt" | grep "GameVersion" | cut -d"=" -f2)
    if [[ "$gamebeta" == "Public" ]]; then
        echo -e "请输入进入测试版本的代码：\c"
        read code
        echo "GameVersion=Beta
BetaCode=$code" > $DST_script_filepath/gamebeta.txt
        rm -rf $DST_game_path/bin
        rm -rf $DST_game_path/data
        rm -rf $DST_game_path/steamapps
        rm -f $DST_game_path/dontstarve.xpm
        rm -f $DST_game_path/version.txt
        update_game
    else
        echo "当前已是测试版，无需转换！"
    fi
}

check()
{
    if [ $(getconfig "cluster_name") != null ]; then
        if ! find_screen "DST_AUTOUPDATE" >/dev/null; then
            echo ""
            #cd $HOME
            #screen -dmS "DST_AUTOUPDATE" /bin/bash -c "$0 auto_update_process"
        fi
    fi
}

announce()
{
    if ! find_screen "DST_ANNOUNCE" >/dev/null; then
        cd $HOME
        screen -dmS "DST_ANNOUNCE" /bin/bash -c "$0 announcesystem"
    fi
}

menu()
{       
    #script_update_check
    while :
    do  
        # canannounce=$(getconfig "announce")
        # if [[ "$canannounce" == "true" ]]; then
            # anstr="关闭自动公告"
        # else
            # anstr="开启自动公告"
        # fi
        # myhelp
        DST_script_version=$(getconfig "cur_script_ver")
        gbeta=$(getconfig "gbeta")
        clientip=$(curl -s http://members.3322.org/dyndns/getip)
        usernum=$(curl -s ftp://wqlinblog.cn/dstscript/script_usernum.txt)
        if [[ "$clientip" == "" ]]; then
            clientip="unknown"
        fi
        getpresentcluster
        getserverversion
        getpresentserver
        echo -e "\e[33m================欢迎使用饥荒联机版独立服务器脚本[Linux-Steam]===================\e[0m"
        echo -e "\e[92m脚本版本: $DST_script_version   游戏服务端版本: $gbeta($DST_server_version)   已统计的用户数量：$usernum\e[0m"
        echo -e "\e[31m存档目录：$DST_conf_basedir/${DST_conf_dirname}\e[0m"
        echo -e "\e[31mMOD 安装目录：$DST_game_path/mods\e[0m"
        echo -e "\e[92m本云服务器公网IP: $clientip 直连代码：c_connect(\"$clientip\", $serverport)\e[0m"
        echo -e "\e[33m[18]版本转换\e[0m"
        echo -e "\e[33m[13]刷新服务器信息         [15]在线反馈             [16]作者有话说\e[0m"
        echo -e "\e[92m[1]启动服务器              [2]关闭服务器            [3]重启服务器\e[0m"  
        echo -e "\e[92m[4]查看游戏服务器状态      [5]添加或移除MOD         [6]设置管理员和黑、白名单\e[0m"
        echo -e "\e[92m[7]控制台                  [8]查看自动更新进程      [9]退出本脚本\e[0m"
        echo -e "\e[92m[10]删除存档               [12]更改房间设置         [14]自动公告\e[0m"
        echo -e "\e[92m=============================世界信息===========================================\e[0m"
        getworldstate
        getplayernumber        
        echo -e "\e[33m当前服务器开启的世界：$server  当前存档槽：$cluster\e[0m"
        if [[ $(screen -ls | grep -c "DST_Master") > 0 || $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
            check
            getworldname
            echo -e "\e[33m当前是世界第 $presentcycles 天 $presentseason的第 $presentday 天 $presentphase  游戏模式: $gamemode\e[0m"
            echo -e "\e[31m房间名:$world_name 密码: $passkey 人数: $number/$maxplayer\e[0m"
        fi
        getplayerlist
        echo -e "\e[33m================================================================================\e[0m"
        echo -e "\e[92m请输入命令代号：\e[0m"
        read cmd  
            case $cmd in
                # 18)
                # echo "请选择你要转换的版本：1.正式版  2.测试版  3.更改测试代码"
                # read vercode
                # case $vercode in
                    # 1)
                    # exchangpublic;;
                    # 2)
                    # exchangebeta;;
                    # 3)
                    # exchangecode;;
                # esac
                # ;;
                # 17)
                # echo "请选择：1.启用我的MOD  2.停用我的MOD"
                # read vercode
                # case $vercode in
                    # 1)
                    # downloadmymod;;
                    # 2)
                    # delmymod;;
                # esac
                # ;;
                16)
                echo -e "\e[33m================================================================================\e[0m"
                echo "# STEAM 平台饥荒联机版傻瓜式开服脚本，支持Linux发行版系统Ubuntu、CentOS 7.x"
                echo "# 功能简介：一键式安装服务器环境，傻瓜式配置，支持控制台，服务端和模组自动更新"
                echo "# 作者信息：STEAM@GoforDream  百度贴吧@大逗比呀小逗比  Email@15927142072@163.com"
                echo "# 如果某项功能不正常，可删除$DST_script_filepath文件夹后重新运行脚本！" 
                echo "********************************************************************************"
                echo "********************************************************************************"
                echo "# 按回车键返回主界面>>>"
                read back
                ;;
                15)
                online_feedback
                ;;
                14)
                # if [[ "$anstr" = "开启自动公告" ]]; then
                    # exchange "announce" "true"
                # else
                    # exchange "announce" "false"
                # fi
                # if [[ $(screen -ls | grep -c "DST_ANNOUNCE") > 0 ]]; then
                    # screen -r "DST_ANNOUNCE"
                # fi
                announce
                if [[ $(screen -ls | grep -c "DST_ANNOUNCE") > 0 ]]; then
                    screen -r "DST_ANNOUNCE"
                else 
            
                    echo "${DST_now}: 自动公告进程未正常开启，请在稍后查看！"
                    menu
                fi
                ;;
                13)
                menu
                ;;
                1)                
                if [[ $(screen -ls | grep -c "DST_Master") > 0 || $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
                    echo "将会关闭当前开启的服务器是否继续？ 1.是  2.否"
                    read ifcontinue
                    if [[ "$ifcontinue" == "2" ]]; then
                        menu
                    else
                
                        echo "${DST_now}: 正在关闭当前服务器。。。。。"
                        closeserver
                    fi
                fi
                startserver
                break;;
                2)closeserver
                ;;
                3)rebootannounce
                closeserver
                savelog
                cd $HOME/.dstscript                
                serverrestart
                sleep 30
                startcheck
                check
                menu
                break;;
                4)checkserver
                break;;    
                5)echo -e "\e[92m设置完成后，须重启服务器才会生效。\e[0m"
                echo -e "\e[92m你要：1.添加Mod  2.移除Mod   3.批量添加Mod   4.移除所有Mod\e[0m"
                read modad
                case $modad in
                    1)
                    listallmod
                    addmod;;
                    2)
                    listusedmod
                    delmod;;
                    3)
                    addlistmod
                    ;;
                    4)
                    modadd
                    ;;
                esac
                menu
                break;;
                6)echo -e "\e[92m设置完成后，须重启服务器才会生效。\e[0m"
                listmanager
                menu
                break;;    
                7)
                if [[ $(screen -ls | grep -c "DST_Master") > 0 || $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
                    console
                else
                    echo "服务器未开启！"
                fi                
                ;;    
                8)
                if [[ $(screen -ls | grep -c "DST_AUTOUPDATE") > 0 ]]; then
                    screen -r "DST_AUTOUPDATE"
                else 
            
                    echo "${DST_now}: 自动更新进程未正常开启，请在稍后查看！"
                    check
                    menu
                fi
                ;;    
                9)
                exitshell
                break;;    
                10)
                deldir
                menu
                break;;    
                12)
                changesetting
                break;;            
            esac
    done
}

force_shutdown {
    allow_force_shutdown=$(getconfig "allow_force_shutdown")
    if [[ "$allow_force_shutdown" == "true" ]]; then
        min_hour=$(getconfig "min_hour")
        max_hour=$(getconfig "max_hour")
        restart_min_hour=$min_hour
        restart_max_hour=$[$min_hour + 1]
        if [ $max_hour -le $min_hour ]; then 
            max_hour=$[ $max_hour + 24 ]
        fi
        restart_wait_hour=$[$max_hour - $min_hour]
        shutdownsleeptime=$[$restart_wait_hour*3600] 
        time_to_restart_min_hour=$(( ($(date -d "${restart_min_hour}:00" +%s) - $(date +%s) + (86400)) % (86400) ))
        time_to_restart_max_hour=$(( ($(date -d "${restart_max_hour}:00" +%s) - $(date +%s) + (86400)) % (86400) ))
        if [ $time_to_restart_max_hour -le $time_to_restart_min_hour ]; then 
            if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then                                            
                screen -S "DST_Master" -p 0 -X stuff "c_announce(\"感谢你在本服务器玩耍，现在已超过 $min_hour 点，服务器自动关闭系统已启动！\")$(printf \\r)"
                sleep 3
                screen -S "DST_Master" -p 0 -X stuff "c_announce(\"服务器将于一分钟后关闭， $max_hour 点后自动开启，欢迎你再次来玩！\")$(printf \\r)"            
            fi
            sleep 30
            if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then
                screen -S "DST_Master" -p 0 -X stuff "c_save()$(printf \\r)"
                sleep 5
                screen -S "DST_Master" -p 0 -X stuff "c_shutdown()$(printf \\r)"
            fi
            if [[ $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
                screen -S "DST_Caves" -p 0 -X stuff "c_save()$(printf \\r)"
                sleep 5
                screen -S "DST_Caves" -p 0 -X stuff "c_shutdown()$(printf \\r)"
            fi        
    
            echo "$DST_now: 自动关服系统启动，服务器已关闭！$restart_wait_hour 小时后开启！" 
            sleep $shutdownsleeptime
        fi 
    fi
}

clear_log {
    clear_min_hour=3
    clear_max_hour=4
    time_to_clear_min_hour=$(( ($(date -d "${clear_min_hour}:00" +%s) - $(date +%s) + (86400)) % (86400) ))
    time_to_clear_max_hour=$(( ($(date -d "${clear_max_hour}:00" +%s) - $(date +%s) + (86400)) % (86400) ))
    if [ $time_to_clear_max_hour -le $time_to_clear_min_hour ]; then         

        echo "$DST_now: 日常清零服务器运行日志。。。" 
        echo "" > $DST_script_filepath/script_log.txt
    fi    
}

backup {
    # backup cluster
    if [ ! -d $DST_conf_basedir/backup ]; then
        mkdir -p $DST_conf_basedir/backup
    fi
    dt=$(date +"%F_%T")
    dts=$(date +"%s")
    cur_cluster=$(getconfig "cluster_name")
    if [[ "$cur_cluster" != "null" ]]; then
        cd $DST_conf_basedir
        cp -rf $DST_conf_dirname/$cur_cluster backup/${cur_cluster}_${dt}_$dts
        cd $HOME

        echo "$DST_now: $cur_cluster 存档备份完成！" 
    fi
    sleep 30
    backuplistnum=$(ls $DST_conf_basedir/backup | grep -c "$cur_cluster")
    if [ $backuplistnum -gt 10 ]; then
        dellist=$(ls $DST_conf_basedir/backup | grep "$cur_cluster" | cut -d"_" -f4 | sort -rn)
        index=1
        for i in $dellist 
        do
            if [ $index -gt 10 ]; then
                deldirname=$(ls $DST_conf_basedir/backup | grep "$cur_cluster.*$i")
                rm -rf $DST_conf_basedir/backup/$deldirname
        
                echo "$DST_now: 删除多余存档 $deldirname ！"
            fi
            index=$[$index+1]
        done
    fi
}

announcesystem {
    if [ -f $DST_script_filepath/announcelist.txt ]; then
        announcelist=$(grep "$DST_script_filepath/announcelist.txt" -e "^@" | cut -d "@" -f2)
        for announcement in $announcelist
        do
        if [[ $(screen -ls | grep -c "DST_Master") > 0 ]]; then                                            
            screen -S "DST_Master" -p 0 -X stuff "c_announce(\"$announcement\")$(printf \\r)"            
        fi
        sleep 10
        done
    else
        echo "---- 发送间隔，单位秒
period=600

---- 公告内容，每行一条，行首@开头，不要包含空格
---- 示例
@欢迎来到本服务器玩耍！" > $DST_script_filepath/announcelist.txt
        echo "你未填写公告内容，你在文件 $DST_script_filepath/announcelist.txt 内填写！"
    fi    
}
    
if [ "$1" == "announcesystem" ]; then
    while :
    do
        clear       
        echo -e "\e[33m欢迎使用饥荒联机版独立服务器脚本[Linux-Steam]\e[0m"
        echo "自动公告系统已启动，按 Ctrl +a +d 退出界面保持后台运行！"
        echo "自动公告系统已启动，按 Ctrl +c 退出界面并停止发送公告！"
        echo "你可以随时在 $DST_script_filepath/announcelist.txt 文件里修改公告内容和发送间隔 ！"
        sleep 10
        # canannounce=$(getconfig "announce")
        # if [[ "$canannounce" == "true" ]]; then
            announcesystem
        # fi
        announcesleep=$(grep "$DST_script_filepath/announcelist.txt" -e "^period" | cut -d "=" -f2)
        sleep $announcesleep
    done
    exit
fi

if [ "$1" == "auto_update_process" ]; then
    while :
    do
        clear
        clear_log        
        echo -e "\e[33m欢迎使用饥荒联机版独立服务器脚本[Linux-Steam]\e[0m"
        echo "按Ctrl+a+d可以退出本界面！"
        # serveropen=$(getconfig "server")
        # if [[ "$serveropen" == "false" ]]; then
            # echo "服务器为关闭状态！"
        # else
        backup
        auto_update
        sleep 30
        force_shutdown
        sleep 30
        processkeep
        # fi

        updatesleeptime=$(getconfig "updatesleeptime")
        ust=$[$updatesleeptime*60]
        echo -e "\e[31m${DST_now}: $updatesleeptime 分钟后进行下一次循环检查！\e[0m" 
        sleep $ust
    done
    exit
fi

    if [ $(getconfig "cluster_name") != null ]; then
        if ! find_screen "DST_AUTOUPDATE" >/dev/null; then
            cd $HOME
            screen -dmS "DST_AUTOUPDATE" /bin/bash -c "$0 auto_update_process"
        fi
    fi

menu

# New menu
while :
    do
        clientip=$(curl -s http://members.3322.org/dyndns/getip)
        getpresentcluster
        getserverversion
        getpresentserver
        echo -e "\e[33m========= 欢迎使用饥荒联机版($DST_server_version)独立服务器脚本[Linux-Steam] By GoforDream =========\e[0m"
        echo -e "\e[31m存档目录：$DST_conf_basedir/${DST_conf_dirname}\e[0m"
        echo -e "\e[31mMOD 安装目录：$DST_game_path/mods\e[0m"
        echo -e "\e[92m本云服务器公网IP: $clientip 直连代码：c_connect(\"$clientip\", $serverport)\e[0m"
        echo -e "\e[33m[13]刷新服务器信息         [15]在线反馈             [16]作者有话说\e[0m"
        echo -e "\e[92m[1]启动服务器              [2]关闭服务器            [3]重启服务器\e[0m"  
        echo -e "\e[92m[4]查看游戏服务器状态      [5]添加或移除MOD         [6]设置管理员和黑、白名单\e[0m"
        echo -e "\e[92m[7]控制台                  [8]查看自动更新进程      [9]退出本脚本\e[0m"
        echo -e "\e[92m[10]删除存档               [12]更改房间设置         [14]自动公告\e[0m"
        echo -e "\e[92m=============================世界信息===========================================\e[0m"
        getworldstate
        getplayernumber        
        echo -e "\e[33m当前服务器开启的世界：$server  当前存档槽：$cluster\e[0m"
        if [[ $(screen -ls | grep -c "DST_Master") > 0 || $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
            check
            getworldname
            echo -e "\e[33m当前是世界第 $presentcycles 天 $presentseason的第 $presentday 天 $presentphase  游戏模式: $gamemode\e[0m"
            echo -e "\e[31m房间名:$world_name 密码: $passkey 人数: $number/$maxplayer\e[0m"
        fi
        getplayerlist
        echo -e "\e[33m================================================================================\e[0m"
        echo -e "\e[92m请输入命令代号：\e[0m"
        read cmd  
            case $cmd in
                # 18)
                # echo "请选择你要转换的版本：1.正式版  2.测试版  3.更改测试代码"
                # read vercode
                # case $vercode in
                    # 1)
                    # exchangpublic;;
                    # 2)
                    # exchangebeta;;
                    # 3)
                    # exchangecode;;
                # esac
                # ;;
                # 17)
                # echo "请选择：1.启用我的MOD  2.停用我的MOD"
                # read vercode
                # case $vercode in
                    # 1)
                    # downloadmymod;;
                    # 2)
                    # delmymod;;
                # esac
                # ;;
                16)
                echo -e "\e[33m================================================================================\e[0m"
                echo "# STEAM 平台饥荒联机版傻瓜式开服脚本，支持Linux发行版系统Ubuntu、CentOS 7.x"
                echo "# 功能简介：一键式安装服务器环境，傻瓜式配置，支持控制台，服务端和模组自动更新"
                echo "# 作者信息：STEAM@GoforDream  百度贴吧@大逗比呀小逗比  Email@15927142072@163.com"
                echo "# 如果某项功能不正常，可删除$DST_script_filepath文件夹后重新运行脚本！" 
                echo "********************************************************************************"
                echo "********************************************************************************"
                echo "# 按回车键返回主界面>>>"
                read back
                ;;
                15)
                online_feedback
                ;;
                14)
                # if [[ "$anstr" = "开启自动公告" ]]; then
                    # exchange "announce" "true"
                # else
                    # exchange "announce" "false"
                # fi
                # if [[ $(screen -ls | grep -c "DST_ANNOUNCE") > 0 ]]; then
                    # screen -r "DST_ANNOUNCE"
                # fi
                announce
                if [[ $(screen -ls | grep -c "DST_ANNOUNCE") > 0 ]]; then
                    screen -r "DST_ANNOUNCE"
                else 
            
                    echo "${DST_now}: 自动公告进程未正常开启，请在稍后查看！"
                    menu
                fi
                ;;
                13)
                menu
                ;;
                1)                
                if [[ $(screen -ls | grep -c "DST_Master") > 0 || $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
                    echo "将会关闭当前开启的服务器是否继续？ 1.是  2.否"
                    read ifcontinue
                    if [[ "$ifcontinue" == "2" ]]; then
                        menu
                    else
                
                        echo "${DST_now}: 正在关闭当前服务器。。。。。"
                        closeserver
                    fi
                fi
                startserver
                break;;
                2)closeserver
                ;;
                3)rebootannounce
                closeserver
                savelog
                cd $HOME/.dstscript                
                serverrestart
                sleep 30
                startcheck
                check
                menu
                break;;
                4)checkserver
                break;;    
                5)echo -e "\e[92m设置完成后，须重启服务器才会生效。\e[0m"
                echo -e "\e[92m你要：1.添加Mod  2.移除Mod   3.批量添加Mod   4.移除所有Mod\e[0m"
                read modad
                case $modad in
                    1)
                    listallmod
                    addmod;;
                    2)
                    listusedmod
                    delmod;;
                    3)
                    addlistmod
                    ;;
                    4)
                    modadd
                    ;;
                esac
                menu
                break;;
                6)echo -e "\e[92m设置完成后，须重启服务器才会生效。\e[0m"
                listmanager
                menu
                break;;    
                7)
                if [[ $(screen -ls | grep -c "DST_Master") > 0 || $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
                    console
                else
                    echo "服务器未开启！"
                fi                
                ;;    
                8)
                if [[ $(screen -ls | grep -c "DST_AUTOUPDATE") > 0 ]]; then
                    screen -r "DST_AUTOUPDATE"
                else 
            
                    echo "${DST_now}: 自动更新进程未正常开启，请在稍后查看！"
                    check
                    menu
                fi
                ;;    
                9)
                exitshell
                break;;    
                10)
                deldir
                menu
                break;;    
                12)
                changesetting
                break;;            
            esac
    done
}
