#
#!/bin/bash
#
source "$HOME/dst/shell/configure.sh"
source "$HOME/dst/shell/myfunc.sh"

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
    info "保存服务器聊天日志>>$HOME/dst/data/serverchatdata"
    echo "以下内容备份于 $(date)" >> "$HOME/dst/data/serverchatdata"
    grep "^" "$dst_base_dir/$cluster/Master/server_chat_log.txt" | cut -f 2-20 -d' ' >> "$HOME/dst/data/serverchatdata"
fi
