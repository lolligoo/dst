#
#!/bin/bash
#
source "configure.sh"
source "myfunc.sh"

update_game(){
    ./steamcmd/steamcmd.sh +login anonymous +force_install_dir $dst_game_dir +app_update 343050 validate +quit
}

info "检查服务端是否有更新。。。请稍候。。。"
curl -s https://forums.kleientertainment.com/game-updates/dst/ > ../data/dsttmp
new_ver1=$(cat ../data/dsttmp | grep -B 1 'Release</span>' | head -n 1 | tr -cd "[0-9]")
new_ver2=$(cat ../data/dsttmp | grep -B 1 'Release</span>' | head -n 2 | tail -n 1 | tr -cd "[0-9]")
if [ $new_ver1 -gt $new_ver2 ]; then
    new_ver=$new_ver1
else
    new_ver=$new_ver2
fi
if [ ! -f $dst_game_dir/version.txt ]; then
    cur_ver=000000
else
    cur_ver=$(cat $dst_game_dir/version.txt)
fi
if [ $new_ver -gt $cur_ver ]; then
    info "游戏服务端有更新! 开始更新。。。"
    update_game
    info "更新完毕！请重启服务器！"
else
    info "游戏服务端无更新可用！"
fi
