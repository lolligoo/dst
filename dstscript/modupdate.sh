#!/bin/bash
#
# Auto update DST server mod.
############ATTENTION######################################################
# Need to use steamcmd to login your steam acount on your server once first.
############ATTENTION######################################################
#
# Set your steamcmd path here.
steamcmd_path="$HOME/steamcmd"
# Set your DST server mod installed path here.  
mod_install_path="/home/ubuntu/Steam/steamapps/common/DSTServer/mods"
# Set your enabled mod list file path here. while your write mod setup configure like SetupMod("xxxxxxxxxx")
mod_list_file="$HOME/.dstscript/mods_setup.lua"
# Set your Steam username here.
steam_username="linweiqing2016"
# Do not change.
mod_download_path="$HOME/Steam/steamapps/workshop/content/322330"
modupdate_required=()
#
# output rules
#
info(){ time=$(date "+%T"); echo -e "\e[92m[$time Info] \e[0m$1"; }
warming(){ time=$(date "+%T"); echo -e "\e[33m[$time Warming] \e[0m$1"; }
error(){ time=$(date "+%T"); echo -e "\e[31m[$time Error] \e[0m$1";}
#
# whether connection available
#
pingc(){
    ping -c 3 -i 0.2 -W 3 $1 &> /dev/null
    if [ $? -eq 0 ]; then
        info "$1 connection is available."
    else
        warming "$1 connection isn't available."
        info "Editing your server hosts...if no work, try to best to do sth. Good luck to you."
        sudo chmod 666 /etc/hosts
        echo "# Steam community
104.125.0.135 steamcommunity.com
72.246.103.24 cdn.steamcommunity.com
" >> /etc/hosts
        chmod 655 /etc/hosts
        info "Done! Run the script again. if no work, try your best to do sth. Good luck to you."
        exit
    fi
}
checkping(){
    list="steamcommunity.com"
    for i in $list; do
        pingc "$i"
    done
}
#
# Ckeck whether mod update required. 
#
check_mod_update(){
    info "Ckecking mod update..."
    index=0
    for i in $(grep "^ServerModSetup" "$mod_list_file" | cut -d '"' -f 2)
    do
        info_str="Nothing to do"
        if [[ $i != ""  ]]; then
            curl -s "https://steamcommunity.com/sharedfiles/filedetails/?id=$i" > /tmp/dstmod.tmp
            new_ver=$(cat /tmp/dstmod.tmp | grep '">Version'|cut -d "V" -f2|cut -d "<" -f1|cut -d ":" -f2-10)
            mod_name=$(cat /tmp/dstmod.tmp | grep "workshopItemTitle" | cut -d">" -f2 | cut -d"<" -f1)
            if [ ! -f $mod_install_path/workshop-$i/modinfo.lua ]; then
                modupdate_required[$index]=$i
                info_str="New install"
                signal="$new_ver"
            else
                ver_str=$(grep "^version" $mod_install_path/workshop-$i/modinfo.lua)
                if [ $(echo $ver_str|grep -c '"') -gt 0 ]; then
                    old_ver=$(echo $ver_str|cut -d '"' -f2)
                else
                    old_ver=$(echo $ver_str|cut -d "'" -f2)
                fi
            fi
            if [[ "$old_ver" != "" && "$new_ver" != "" && "$old_ver" != "$new_ver" ]]; then
                info_str="Update required"
                modupdate_required[$index]=$i
                signal="$old_ver==>$new_ver"
            elif [[ "$old_ver" != "" && "$new_ver" != "" && "$old_ver" == "$new_ver" ]]; then
                signal="$old_ver"
            fi
        fi
        info "$info_str for mod $mod_name($i)($signal)"
        index=$[$index + 1]
    done
}
#
# Use steamcmd to update mod.
#
downloadmod(){
    for i in "${modupdate_required[@]}"
    #for i in $(grep "^ServerModSetup" "$mod_list_file" | cut -d '"' -f 2)
    do
    cd $steamcmd_path
    info "Downloading mod $i"
    ./steamcmd.sh +login anonymous +workshop_download_item 322330 $i +quit >/dev/null 2>&1
    info "Installing mod $i"
    if [ -d $mod_install_path/workshop-$i ]; then
        rm -rf $mod_install_path/workshop-$i/*
    else
        mkdir -p $mod_install_path/workshop-$i
    fi
    cd $mod_install_path/workshop-$i
    if [ -s $mod_download_path/$i/*.bin ]; then
    cp $mod_download_path/$i/*.bin $i.zip
    unzip $i.zip >/dev/null 2>&1
    rm -rf $i.zip
    fi
    cd $HOME
    info "Mod $i installed."
    done
    info "All mod already up-to-date."
}
checkping
check_mod_update
downloadmod
