#!/usr/bin/sudo /bin/bash
c=1
while :
do
    if [ $(( c%50 )) = 0 ]; then
        echo $(( c/50 ))
    fi
    /usr/bin/loctag_inject 1200 6 500
    sleep 6
    let c++
done
