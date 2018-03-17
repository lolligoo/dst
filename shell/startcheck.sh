#
#!/bin/bash
#
source "$HOME/dst/shell/configure.sh"
source "$HOME/dst/shell/myfunc.sh"
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
