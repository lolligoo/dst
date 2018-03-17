#
#!/bin/bash
#
# New menu
source "$HOME/dst/shell/configure.sh"
source "$HOME/dst/shell/myfunc.sh"
while :
do
    clientip=$(curl -s http://members.3322.org/dyndns/getip)
    if [ -f $dst_game_dir/version.txt ]; then
        dst_game_version=$(cat $dst_game_dir/version.txt)
    else
        dst_game_version="请先安装服务端"
    fi
    echo -e "\e[33m====== 欢迎使用饥荒联机版($DST_server_version)独立服务器脚本[Linux-Steam] By GoforDream ======\e[0m"
    echo -e "\e[31m存档目录：$dst_base_dir\e[0m"
    echo -e "\e[31mMOD 安装目录：$dst_game_dir/mods\e[0m"
    echo -e "\e[92m本云服务器公网IP: $clientip 直连代码：c_connect(\"$clientip\", 11111)\e[0m"
    echo -e "\e[92m[1]安装/更新服务端         [2]关闭服务器            [3]重启服务器\e[0m"  
    echo -e "\e[92m[4]查看游戏服务器状态      [5]添加或移除MOD         [6]设置管理员和黑、白名单\e[0m"
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
        *) error 无此命令请重新输入！;;
        1) ./gameupdate.sh;;
    esac
done
