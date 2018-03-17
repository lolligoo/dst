#
#!/bin/bash
#
source "$HOME/dst/shell/configure.sh"
# 屏幕输出规则
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

startserver(){
    screen -dmS "$1" /bin/bash -c "$dst_cmd_line -conf_dir DoNotStarveTogether -cluster $cluster -shard $1"
}

serverstatus(){
    if find_screen "$1"; then
        checknumber=$( date +%s%3N )
        screen -S "$1" -p 0 -X stuff "print(\"AllPlayersNumber \" .. (table.getn(TheNet:GetClientTable())-1) .. \" $checknumber\")$(printf \\r)"
        sleep 10
        number=$( grep "$dst_/$cluster/$1/server_log.txt" -e "$checknumber" | cut -f3 -d ' ' | tail -n +2 )
        if [[ "$number" != "" ]]; then
            return 0
        else
            return 1
        fi
    fi
}
