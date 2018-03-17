#
#!/bin/bash
#
source "$HOME/dst/shell/configure.sh"
source "$HOME/dst/shell/myfunc.sh"
while :
do
    read -p "你要修改 1.地上 2.洞穴 世界配置？：" wc
    case $wc in
        1) configure_file="$HOME/dst/data/masterleveldata"
           data_file="$HOME/.klei/DoNotStarveTogether/$cluster/Master/leveldataoverride.lua"
           break;;
        2) configure_file="$HOME/dst/data/cavesleveldata"
           data_file="$HOME/.klei/DoNotStarveTogether/$cluster/Caves/leveldataoverride.lua"
           break;;
        *) error "输入有误请重新输入。";;
    esac
done
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
               echo -e "\e[92m$index.${changelist[$[$i + 1]]}    \e[0m\c"leveldataoverride.lua
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
