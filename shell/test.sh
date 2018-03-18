#
#!/bin/bash
#
while :
do
    echo -e "\e[92m=============【存档槽：$cluster】===============\e[0m"
    index=1
    cat $HOME/MyCode/Shell/dst/data/clusterdata | while read line
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
        *) changelist=($(sed -n "${cmd}p" $HOME/MyCode/Shell/dst/data/clusterdata))
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
           sed -i "${cmd}c $changestr" $HOME/MyCode/Shell/dst/data/clusterdata;;
    esac
done
