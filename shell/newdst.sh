#
#!/bin/bash
#
#####################################################################
# Author:  STEAM@GoforDream http://steamcommunity.com/id/gofordream/#
# Lisence: MIT                                                      #
# Date:    2018-01-19 22:25:25                                      #
#####################################################################
# 全局变量
dst_base_dir="./.klei/DoNotStarveTogether"
dst_game_dir="./DSTServer"
dst_cmd_line="$dst_game_dir/bin/dontstarve_dedicated_server_nullrenderer"
dst_conf_file="./dst/data/serverdata"
dst_chat_file="./dst/data/serverchatdata"
dst_conf_file="./dst/data/serverini"
dst_tmp_file="./dst/data/dsttmp"
dst_token_file="./dst/data/culstertoken"
# 有用的函数
info(){ echo -e "\e[92m[$(date "+%T") 信息] \e[0m$1"; }
warming(){ echo -e "\e[33m[$(date "+%T") 警告] \e[0m$1"; }
error(){ echo -e "\e[31m[$(date "+%T") 错误] \e[0m$1";}
find_screen(){
    if [ $(screen -ls|grep -c "$1") -eq 0 ]; then
        return 1
    else
        return 0
    fi
}
getconfig() {
    if [[ $(grep "$1" -c $dst_conf_file) > 0 ]]; then
        grep "^$1" $dst_conf_file | cut -d"=" -f2
    fi
}
exchange() {
    if [[ $(grep "$1" -c $dst_conf_file) > 0 ]]; then
        oldstr="$(grep "^$1" $dst_conf_file)"
        new="$1=$2"
        sed -i "s/$oldstr/$new/g" $dst_conf_file
    fi
}
startcluster(){
    screen -dmS "$1" /bin/bash -c "$dst_cmd_line -conf_dir DoNotStarveTogether -cluster $cluster -shard $1"
}
serverstatus(){
    if find_screen "$1"; then
        checknumber=$( date +%s%3N )
        screen -S "$1" -p 0 -X stuff "print(\"AllPlayersNumber \" .. (table.getn(TheNet:GetClientTable())-1) .. \" $checknumber\")$(printf \\r)"
        sleep 10
        number=$( grep "$dst_base_dir/$cluster/$1/server_log.txt" -e "$checknumber" | cut -f3 -d ' ' | tail -n +2 )
        if [[ "$number" != "" ]]; then
            return 0
        else
            return 1
        fi
    fi
}
checkgameupdate(){
    curl -s https://forums.kleientertainment.com/game-updates/dst/ > $dst_tmp_file
    new_ver1=$(cat $dst_tmp_file | grep -B 1 'Release</span>' | head -n 1 | tr -cd "[0-9]")
    new_ver2=$(cat $dst_tmp_file | grep -B 1 'Release</span>' | head -n 2 | tail -n 1 | tr -cd "[0-9]")
    if [[ $new_ver1 -gt $new_ver2 ]]; then
        new_ver=$new_ver1
    else
        new_ver=$new_ver2
    fi
    if [ ! -f $dst_game_dir/version.txt ]; then
        cur_ver=0
    else
        cur_ver=$(cat $dst_game_dir/version.txt)
    fi
    if [[ $new_ver -gt $cur_ver ]]; then
        return 0
    else
        return 1
    fi
}
update_game(){
    info "安装/更新游戏服务端。。。"
    ./steamcmd/steamcmd.sh +login anonymous +force_install_dir $dst_game_dir +app_update 343050 validate +quit
    info "安装/更新完毕！"
}
startcheck(){
    a=1
    while :
    do
        if serverstatus "Master"; then
            info "地上服务器开启成功！"
            break
        fi
        a=$[$a + 1]
        if [ $a -gt 5 ]; then
            info "地上服务器开启失败！"
            break
        fi
        sleep 20
    done
    b=1
    while :
    do
        if serverstatus "Caves"; then
            info "洞穴服务器开启成功！"
            break
        fi
        a=$[$b + 1]
        if [ $b -gt 5 ]; then
            info "洞穴服务器开启失败！"
            break
        fi
        sleep 20
    done
}
start_server(){
    if [ find_screen "Master"; || find_screen "Caves"; ]; then
        warming "将关闭已开启的服务器，继续请输入 1："
        read cmd
        if [ $cmd -eq 1 ]; then
            close_server
        else
            info "操作中断"
            exit
        fi
    fi
    if [ -d $dst_base_dir/$cluster ]; then
        if [[ $(getconfig "master") == 1 ]]; then
            info "启动地上服务器。。。"
            startcluster "Master"
        fi
        if [[ $(getconfig "caves") == 1 ]]; then
            info "启动洞穴服务器。。。"
            startcluster "Caves"
        fi
        sleep 10
        startcheck
    else
        error "存档未创建，请先创建存档！"
        exit
    fi
}
close_server(){
    if find_screen "DST_Master"; then
        screen -S "DST_Master" -p 0 -X stuff "c_announce(\"服务器调整维护即将关闭！预计用时五分钟。\")$(printf \\r)"
        sleep 5
        screen -S "DST_Master" -p 0 -X stuff "c_save()$(printf \\r)"
        sleep 25
        sudo killall screen
        info "服务器已关闭！"
    else
        info "服务器未开启！"
    fi

    exchange "serveron" "1"

    if [ -f "$dst_base_dir/$cluster/Master/server_chat_log.txt" ]; then
        info "保存服务器聊天日志>>$dst_chat_file"
        echo "以下内容备份于 $(date)" >> "$dst_chat_file"
        grep "^" "$dst_base_dir/$cluster/Master/server_chat_log.txt" | cut -f 2-20 -d' ' >> "$dst_chat_file"
    fi
}
restart_server(){
    close_server
    start_server
}
newcluster(){
    warming "以下操作无错误检测，请认真按提示操作，失误请关闭脚本重来！"
    read -p "请输入存档名称：（不要包含中文和特殊字符)：" cluster
    exchange "cluster" "$cluster"
    mkdir -p $dst_base_dir/$cluster/Master
    mkdir -p $dst_base_dir/$cluster/Caves
    read -p " 请选择要开启的世界:1.地上(主世界) 2.洞穴(附从世界) 3.地上+洞穴(主世界+附从世界)：" shard
    case $shard in
        1) exchange "master" "1"
           exchange "caves" "0";;
        2) exchange "master" "0"
           exchange "caves" "1";;
        *) exchange "master" "1"
           exchange "caves" "1";;
    esac
    setcluster
    settoken
    setlistfile
    setserverini
    setworld
    setmod
    info "新存档创建完成！"
}
settoken(){
    info "默认服务器令牌：$(cat $dst_token_file)"
    read -p "是否更改？1.是 2.否" ch
    if [ $ch -eq 1 ]; then
        warming "请输入或粘贴你的令牌到此处，注意最后不要输入空格："
        read mytoken
        echo $mytoken > $dst_token_file
        info "已更改服务器默认令牌！"
    fi
    cat $dst_token_file > $dst_base_dir/$cluster/clustertoken.txt
}
setserverini(){
    cat $HOME/dst/data/masterini > $dst_base_dir/$cluster/Master/server.ini
    cat $HOME/dst/data/cavesini > $dst_base_dir/$cluster/Caves/server.ini
}
setlistfile(){
    cat $HOME/dst/data/alist > $dst_base_dir/$cluster/adminlist.txt
    cat $HOME/dst/data/blist > $dst_base_dir/$cluster/blacklist.txt
    cat $HOME/dst/data/wlist > $dst_base_dir/$cluster/whitelist.txt
}
setworld(){
    info "是否修改地上世界配置？：1.是 2.否（默认为上次配置）"
    read wc
    if [ $wc -eq 1 ]; then
        configure_file="$HOME/dst/data/masterleveldata"
        data_file="$dst_base_dir/$cluster/Master/leveldataoverride.lua"
        worldsettings
    fi
    info "是否修改洞穴世界配置？：1是 2.否（同上）"
    read cw
    if [ $cw -eq 1 ]; then
        configure_file="$HOME/dst/data/cavesleveldata"
        data_file="$dst_base_dir/$cluster/Caves/leveldataoverride.lua"
        worldsettings
    fi

    cat "$HOME/dst/data/masterstart" > $dst_base_dir/$cluster/Master/leveldataoverride.lua
    getin "$HOME/dst/data/masterleveldata" "75" "Master"
    cat "$HOME/dst/data/masterend" >> $dst_base_dir/$cluster/Master/leveldataoverride.lua

    cat "$HOME/dst/data/cavesstart" > $dst_base_dir/$cluster/Caves/leveldataoverride.lua
    getin "$HOME/dst/data/cavesleveldata" "45" "Caves"
    cat "$HOME/dst/data/cavesend" >> $dst_base_dir/$cluster/Caves/leveldataoverride.lua
}
getin(){
    index=1
    cat $1 | while read line
    do
        ss=($line)
        if [ $index -lt $2 ]; then
            char=","
        else
            char=""
        fi
        index=$[$index + 1]
        str="${ss[0]}=\"${ss[1]}\"$char"
        echo "    $str" >> $dst_base_dir/$cluster/$3/leveldataoverride.lua
    done
}
worldsettings(){
    while :
    do
        clear
        index=1
        linenum=1
        list=(environment source food animal monster)
        liststr=(
            ================================世界环境================================
            ==================================资源==================================
            ==================================食物==================================
            ==================================动物==================================
            ==================================怪物==================================
        )
        for ((j=0;j<${#list[*]};j++))
        do
            echo -e "\n\e[92m${liststr[$j]}\e[0m"
            cat $configure_file | while read line
            do
                ss=($line)
                if [ ${#ss[@]} -gt 4 ]; then
                    if [ $index -lt 4 ]; then
                        for ((i=4;i<${#ss[*]};i++))
                        do
                            if [ "${ss[$i]}" == "${ss[1]}" ]; then
                                value=${ss[$i+1]}
                            fi
                        done
                        if [ "${list[$j]}" == "${ss[2]}" ]; then
                            printf "%-21s\t" "[$linenum]${ss[3]}: $value"
                            index=$[$index + 1]
                        fi
                    else
                        printf "\n"
                        index=1
                    fi
                fi
                linenum=$[$linenum + 1]
            done
        done
        printf "\n"
        read -p "请选择你要更改的选项(修改完毕输入数字 0 确认修改并退出)：" cmd
        case $cmd in
            0) info "更改已保存！"
            break;;
            *) changelist=($(sed -n "${cmd}p" $configure_file))
               echo -e "\e[92m请选择${changelist[3]}： \e[0m\c"
               index=1
               for ((i=4;i<${#changelist[*]};i=$i+2))
               do
                   echo -e "\e[92m$index.${changelist[$[$i + 1]]}    \e[0m\c"
                   index=$[$index + 1]
               done
               echo -e "\e[92m: \e[0m\c"
               read changelistindex
               listnum=$[$changelistindex - 1]*2
               changelist[1]=${changelist[$[$listnum + 4]]}
               changestr="${changelist[@]}"
               sed -i "${cmd}c $changestr" $configure_file;;
        esac
    done
}
# main code
while :
do
    clientip=$(curl -s http://members.3322.org/dyndns/getip)
    cluster=$(getconfig "cluster")
    if [ -f $dst_game_dir/version.txt ]; then
        dst_game_version=$(cat $dst_game_dir/version.txt)
    else
        dst_game_version="请先安装服务端"
    fi
    if checkgameupdate; then need_update="需要更新"; else need_update="已是最新版"; fi
    echo -e "\e[33m====== 欢迎使用饥荒联机版独立服务器脚本[Linux-Steam] By GoforDream ======\e[0m"
    echo -e "\e[31m游戏服务端版本：$dst_game_version($need_update)\e[0m"
    echo -e "\e[31m存档目录：$dst_base_dir\e[0m"
    echo -e "\e[31mMOD 安装目录：$dst_game_dir/mods\e[0m"
    echo -e "\e[92m本服务器直连代码：c_connect(\"$clientip\", 11111)\e[0m"
    echo -e "\e[92m[1]安装/更新服务端         [2]创建新存档\e[0m"
    echo -e "\e[92m[3]启动服务器              [4]关闭服务器            [6]重启服务器\e[0m"
    echo -e "\e[92m[7]控制台                  [8]查看自动更新进程      [9]退出本脚本\e[0m"
    echo -e "\e[92m[10]删除存档               [12]更改房间设置         [14]自动公告\e[0m"
    echo -e "\e[92m=============================世界信息===========================================\e[0m"
    echo -e "\e[33m当前服务器开启的世界：$server  当前存档槽：$cluster\e[0m"
    if [[ $(screen -ls | grep -c "DST_Master") > 0 || $(screen -ls | grep -c "DST_Caves") > 0 ]]; then
        echo -e "\e[33m当前是世界第 $presentcycles 天 $presentseason的第 $presentday 天 $presentphase  游戏模式: $gamemode\e[0m"
        echo -e "\e[31m房间名:$world_name 密码: $passkey 人数: $number/$maxplayer\e[0m"
    fi
    echo -e "\e[33m================================================================================\e[0m"
    read -p "请输入命令代号：" cmd
    case $cmd in
        1) update_game;;
        2) newcluster;;
        3) start_server;;
        4) close_server;;
        5) restart_server;;
        *) error "无此命令请重新输入！";;
    esac
done
