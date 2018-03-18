#
#!/bin/bash
#
#####################################################################
# Author:  STEAM@GoforDream http://steamcommunity.com/id/gofordream/#
# Lisence: MIT                                                      #
# Date:    2018-01-19 22:25:25                                      #
#####################################################################
# 全局变量
dst_base_dir="$HOME/.klei/DoNotStarveTogether"
dst_game_dir="$HOME/DSTServer"
dst_cmd_line="./dontstarve_dedicated_server_nullrenderer"
dst_conf_file="$HOME/dst/data/serverdata"
dst_chat_file="$HOME/dst/data/serverchatdata"
dst_conf_file="$HOME/dst/data/serverini"
dst_tmp_file="$HOME/dst/data/dsttmp"
dst_token_file="$HOME/dst/data/clustertoken"
dst_cluster_file="$HOME/dst/data/clusterdata"
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
    cd $dst_game_dir/bin
    screen -dmS "$1" /bin/bash -c "$dst_cmd_line -conf_dir DoNotStarveTogether -cluster $cluster -shard $1"
    cd $HOME
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
    if find_screen "Master"; then
        warming "将关闭已开启的服务器，继续请输入 1："
        read cmd
        if [ $cmd -eq 1 ]; then
            close_server
        else
            info "操作中断"
            exit
        fi
    fi
    cp $HOME/dst/data/mods_setup.lua $dst_game_dir/mods/dedicated_server_mods_setup.lua
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
    if find_screen "Master"; then
        screen -S "Master" -p 0 -X stuff "c_announce(\"服务器调整维护即将关闭！预计用时五分钟。\")$(printf \\r)"
        sleep 5
        screen -S "Master" -p 0 -X stuff "c_save()$(printf \\r)"
        sleep 25
        info "服务器已关闭！"
    else
        info "服务器未开启！"
    fi
    sudo killall screen
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
    warming "MOD和名单管理分别单独做一个选项，请配好此项后再另外操作！"
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
    defaultmodadd
    info "新存档创建完成！"
}
addlist()
{
    echo -e "\e[92m请输入你要添加的KLEIID（KU_XXXXXXX）：(添加完毕请输入数字 0 )\e[0m"
    while :
    do
    read kleiid
    if [[ "$kleiid" == "0" ]]; then
        echo "添加完毕！"
        break
    else
        if [[ $(grep "$kleiid" -c "$dst_base_dir/$cluster/$listfile") > 0 ]]; then
            echo -e "\e[92m名单$kleiid已经存在！\e[0m"
        else
            echo "$kleiid" >> $dst_base_dir/$cluster/$listfile
            echo -e "\e[92m名单$kleiid已添加！\e[0m"
        fi
    fi
    done
}
dellist()
{
    echo "=========================================================================="
    grep "$dst_base_dir/$cluster/$listfile" -e "KU"
    echo -e "\e[92m请输入你要移除的KLEIID（KU_XXXXXXX）：删除完毕请输入数字 0 \e[0m"
    while :
    do
    read kleiid
    if [[ "$kleiid" == "0" ]]; then
        echo "移除完毕！"
        break
    else
        if [[ $(grep "$kleiid" -c "$dst_base_dir/$cluster/$listfile") > 0 ]]; then
            sed -i "/$kleiid/d" $dst_base_dir/$cluster/$listfile
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
    if [ ! -f $HOME/dst/data/mod_setup.lua ]; then
        echo "---MOD自动更新列表：" > $HOME/dst/data/mods_setup.lua
    fi
    for i in $(ls -F "$dst_game_dir/mods" | grep "/$" | cut -d '/' -f1| cut -d "-" -f2)
    do
        if [[ "$i" != "" ]]; then
            echo "fuc = \"list\"
modid = \"$i\"" > "$HOME/dst/data/modinfo.lua"
            if [[ -f "$dst_game_dir/mods/workshop-$i/modinfo.lua" ]]; then
                cat "${dst_game_dir}/mods/workshop-$i/modinfo.lua" >> "$HOME/dst/data/modinfo.lua"
            else
                echo "name = UNKNOWN" >> "$HOME/dst/data/modinfo.lua"
            fi
            cd $HOME/dst/data
            lua $HOME/dst/data/modconf.lua
            cd $HOME
        fi
    done
    cat $HOME/dst/data/modconfstr.lua
    echo "" > $HOME/dst/data/modconfstr.lua
}
listusedmod()
{
    echo "" > $HOME/dst/data/modconfstr.lua
    for i in $(grep "workshop" "$dst_base_dir/$cluster/Master/modoverrides.lua" | cut -d '"' -f2| cut -d "-" -f2)
    do
        if [[ "$i" != "" ]]; then
            echo "fuc = \"list\"
modid = \"$i\"" > "$HOME/dst/data/modinfo.lua"
            if [[ -f "$dst_game_dir/mods/workshop-$i/modinfo.lua" ]]; then
                cat "${dst_game_dir}/mods/workshop-$i/modinfo.lua" >> "$HOME/dst/data/modinfo.lua"
            else
                echo "name = UNKNOWN" >> "$HOME/dst/data/modinfo.lua"
            fi
            cd $HOME/dst/data
            lua $HOME/dst/data/modconf.lua
        fi
    done
    cat $HOME/dst/data/modconfstr.lua
    echo "" > $HOME/dst/data/modconfstr.lua
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
    echo "$dst_base_dir/$cluster/Master/modoverrides.lua"
    echo "$dst_base_dir/$cluster/Caves/modoverrides.lua"
    sleep 3
    clear
}
addmodfunc()
{
    if [[ "$modid" != "0" ]]; then
        if [ -f $dst_game_dir/mods/workshop-$modid/modinfo.lua ]; then
            echo "fuc = \"writein\"
modid = $modid" > $HOME/dst/data/modinfo.lua
            cat $dst_game_dir/mods/workshop-$modid/modinfo.lua >> $HOME/dst/data/modinfo.lua
        else
            echo "fuc = \"writein\"
modid = $modid
name = \"UNKNOWN\"" > $HOME/dst/data/modinfo.lua
        fi
        cd $HOME/dst/data
        lua $HOME/dst/data/modconf.lua
        if [[ $(grep "$modid" "$dst_base_dir/$cluster/Master/modoverrides.lua") > 0 ]]
        then
            echo "地上世界该Mod($modid)已添加"
        else
            sed -i '1d' $dst_base_dir/$cluster/Master/modoverrides.lua
            cat $dst_base_dir/$cluster/Master/modoverrides.lua > $HOME/dst/data/modconftemp.txt
            echo "return {" > $dst_base_dir/$cluster/Master/modoverrides.lua
            cat $HOME/dst/data/modconfstr.lua >> $dst_base_dir/$cluster/Master/modoverrides.lua
            cat $HOME/dst/data/modconftemp.txt >> $dst_base_dir/$cluster/Master/modoverrides.lua
            echo "地上世界Mod($modid)添加完成"
        fi
        if [[ $(grep "$modid" "$dst_base_dir/$cluster/Caves/modoverrides.lua") > 0 ]]
        then
            echo "洞穴世界该Mod($modid)已添加"
        else
            sed -i '1d' $dst_base_dir/$cluster/Caves/modoverrides.lua
            cat $dst_base_dir/$cluster/Caves/modoverrides.lua > $HOME/dst/data/modconftemp.txt
            echo "return {" > $dst_base_dir/$cluster/Caves/modoverrides.lua
            cat $HOME/dst/data/modconfstr.lua >> $dst_base_dir/$cluster/Caves/modoverrides.lua
            cat $HOME/dst/data/modconftemp.txt >> $dst_base_dir/$cluster/Caves/modoverrides.lua
            echo "洞穴世界Mod($modid)添加完成"
        fi
        if [[ $(grep "$modid" -c "$HOME/dst/data/mods_setup.lua") = 0 ]] ;then
            echo "ServerModSetup(\"$modid\")" >> "$HOME/dst/data/mods_setup.lua"
        fi
    fi
}
addlistmod()
{
    if [ ! -f $HOME/dst/data/addlistmod.txt ]; then
        echo "" > $HOME/dst/data/addlistmod.txt
    fi
    echo "请先手动打开 $HOME/dst/data/addlistmod.txt"
    echo "写入你要添加的 MOD 的 ID, 每行写一个，不要包含任何其它无关字符！"
    echo -e "\e[92m是否已填写好 addlistmod.txt 文件：1.是  2.否\e[0m"
    read writedone
    case $writedone in
        1)
        for modid in $(cat $HOME/dst/data/addlistmod.txt)
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
        if [[ $(grep "$modid" "$dst_base_dir/$cluster/Master/modoverrides.lua") > 0 ]]; then
            grep "workshop" -n "$dst_base_dir/$cluster/Master/modoverrides.lua" > $HOME/dst/data/modidlist.txt
            up=$(grep "$modid" "$HOME/dst/data/modidlist.txt" | cut -d ":" -f1)
            down=$(grep -A 1 "$modid" "$HOME/dst/data/modidlist.txt" | tail -1 |cut -d ":" -f1)
            upnum=$(($up - 1))
            downnum=$(($down - 2))
            sed -i "$upnum,${downnum}d" "$dst_base_dir/$cluster/Master/modoverrides.lua"
            echo "地上世界该Mod($modid)已停用！"
        else
            echo "地上世界该Mod($modid)未启用！"
        fi
        if [[ $(grep "$modid" "$dst_base_dir/$cluster/Caves/modoverrides.lua") > 0 ]]; then
            grep "workshop" -n "$dst_base_dir/$cluster/Caves/modoverrides.lua" > $HOME/dst/data/modidlist.txt
            up=$(grep "$modid" "$HOME/dst/data/modidlist.txt" | cut -d ":" -f1)
            down=$(grep -A 1 "$modid" "$HOME/dst/data/modidlist.txt" | tail -1 |cut -d ":" -f1)
            upnum=$(($up - 1))
            downnum=$(($down - 2))
            sed -i "$upnum,${downnum}d" "$dst_base_dir/$cluster/Caves/modoverrides.lua"
            echo "洞穴世界该Mod($modid)已停用！"
        else
            echo "洞穴世界该Mod($modid)未启用！"
        fi
    fi
    done
}
modmanager(){
    read -p "你要 1.添加mod  2.删除mod :" mc
    case $mc in
        1) listallmod
           addmod;;
        2) listusedmod
           delmod;;
        *) break;;
    esac
}
defaultmodadd(){
    echo "return {
    --别删这个，否则脚本会出错
    [\"workshop-donotdelete\"]={ configuration_options={ }, enabled=true }
}" > $dst_base_dir/$cluster/Master/modoverrides.lua
    echo "return {
    --别删这个，否则脚本会出错
    [\"workshop-donotdelete\"]={ configuration_options={ }, enabled=true }
}" > $dst_base_dir/$cluster/Caves/modoverrides.lua
}
setcluster(){
    while :
    do
        echo -e "\e[92m=============【存档槽：$cluster】===============\e[0m"
        index=1
        cat $dst_cluster_file | while read line
        do
            ss=($line)
            if [ "${ss[4]}" != "readonly" ]; then
                if [ "${ss[4]}" == "choose" ]; then
                    for ((i=5;i<${#ss[*]};i++))
                    do
                        if [ "${ss[$i]}" == "${ss[1]}" ]; then
                            value=${ss[$i+1]}
                        fi
                    done
                else
                    value=${ss[1]}
                fi
                echo -e "\e[33m    [$index] ${ss[2]}：$value\e[0m"
            fi
            index=$[$index + 1]
        done
        echo -e "\e[92m===============================================\e[0m"
        read -p "请选择你要更改的选项(修改完毕输入数字 0 确认修改并退出)：" cmd
        case $cmd in
            0) info "更改已保存！"
               break;;
            *) changelist=($(sed -n "${cmd}p" $dst_cluster_file))
               echo ${changelist[4]}
               if [ "${changelist[4]}" = "choose" ]; then
                   echo -e "\e[92m请选择${changelist[2]}： \e[0m\c"
                   index=1
                   for ((i=5;i<${#changelist[*]};i=$i+2))
                   do
                       echo -e "\e[92m$index.${changelist[$[$i + 1]]}    \e[0m\c"
                       index=$[$index + 1]
                   done
                   echo -e "\e[92m: \e[0m\c"
                   read changelistindex
                   listnum=$[$changelistindex - 1]*2
                   changelist[1]=${changelist[$[$listnum + 5]]}
               else
                   echo -e "\e[92m请输入${changelist[2]}(请不要输入空格)：\e[0m\c"
                   read changestr
                   changelist[1]=$changestr
               fi
               changestr="${changelist[@]}"
               sed -i "${cmd}c $changestr" $dst_cluster_file;;
        esac
    done
    type=([GAMEPLAY] [NETWORK] [MISC] [SHARD])
    for ((i=0;i<${#type[*]};i++))
    do
        echo "${type[i]}" >> $dst_base_dir/$cluster/cluster.ini
        cat $dst_cluster_file | while read lc
        do
            lcstr=($lc)
            if [ "${lcstr[3]}" == "${type[i]}" ]; then
                if [ "${lcstr[1]}" == "无" ]; then
                    lcstr[1]=""
                fi
                echo "${lcstr[0]}=${lcstr[1]}" >> $dst_base_dir/$cluster/cluster.ini
            fi
        done
        echo "" >> $dst_base_dir/$cluster/cluster.ini
    done
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
    cat $dst_token_file > $dst_base_dir/$cluster/cluster_token.txt
}
setserverini(){
    cat $HOME/dst/data/masterini > $dst_base_dir/$cluster/Master/server.ini
    cat $HOME/dst/data/cavesini > $dst_base_dir/$cluster/Caves/server.ini
}
setlistfile(){
    cat $HOME/dst/data/alist > $dst_base_dir/$cluster/adminlist.txt
    cat $HOME/dst/data/blist > $dst_base_dir/$cluster/blocklist.txt
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
    getin "$HOME/dst/data/cavesleveldata" "46" "Caves"
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
getcurserver(){
    if find_screen "Master"; then master="地上"; fi
    if find_screen "Caves"; then caves="洞穴"; fi
    server="$master $caves"
    if [ "$server" == " " ]; then server="无"; fi
}
# main code
while :
do
    info "加载中。。。请稍后。。。"
    clientip=$(curl -s http://members.3322.org/dyndns/getip)
    cluster=$(getconfig "cluster")
    if [ -f $dst_game_dir/version.txt ]; then
        dst_game_version=$(cat $dst_game_dir/version.txt)
    else
        dst_game_version="请先安装服务端"
    fi
    if checkgameupdate; then need_update="需要更新"; else need_update="已是最新版"; fi
    clear
    echo -e "\e[33m========= 欢迎使用饥荒联机版独立服务器脚本[Linux-Steam] By GoforDream =========\e[0m"
    echo -e "\e[31m游戏服务端版本：$dst_game_version($need_update)\e[0m"
    echo -e "\e[31m存档目录：$dst_base_dir\e[0m"
    echo -e "\e[31mMOD 安装目录：$dst_game_dir/mods\e[0m"
    echo -e "\e[92m本服务器直连代码：c_connect(\"$clientip\", 11111)\e[0m"
    echo -e "\e[92m[1]安装/更新服务端         [2]创建新存档\e[0m"
    echo -e "\e[92m[3]启动服务器              [4]关闭服务器            [5]重启服务器\e[0m"
    echo -e "\e[92m[6]MOD管理                 [7]名单管理              [8]更新脚本\e[0m"
    echo -e "\e[92m=============================世界信息===========================================\e[0m"
    getcurserver
    echo -e "\e[33m当前服务器开启的世界：$server  当前存档槽：$cluster\e[0m"
    echo -e "\e[33m================================================================================\e[0m"
    read -p "请输入命令代号：" cmd
    case $cmd in
        1) update_game;;
        2) newcluster;;
        3) start_server;;
        4) close_server;;
        5) restart_server;;
        6) modmanager;;
        7) listmanager;;
        8) cd dst
           git pull
           cd;;
        *) error "无此命令请重新输入！";;
    esac
done
