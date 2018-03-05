#
#!/bin/bash
#
configure_file="cavesleveldata.conf"
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
echo -e "\e[92m请选择你要更改的选项(修改完毕输入数字 0 确认修改并退出)：\e[0m\c"
read cmd
# 后续错误输入判断
changelist=($(sed -n "${cmd}p" $configure_file))
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
sed -i "${cmd}c $changestr" $configure_file