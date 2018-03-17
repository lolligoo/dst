#
#!/bin/bash
#
source "$HOME/dst/shell/configure.sh"
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

cat "../data/masterstart" > $dst_base_dir/$cluster/Master/leveldataoverride.lua
getin "../data/masterleveldata" "75" "Master"
cat "../data/masterend" >> $dst_base_dir/$cluster/Master/leveldataoverride.lua

cat "../data/cavesstart" > $dst_base_dir/$cluster/Caves/leveldataoverride.lua
getin "../data/cavesleveldata" "45" "Caves"
cat "../data/cavesend" >> $dst_base_dir/$cluster/Caves/leveldataoverride.lua
