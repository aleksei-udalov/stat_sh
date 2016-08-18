#!/bin/sh

SSH_PORT=27344
ADDR_TO_PING=google.com

# Must be used in pipe. Gets addresses from stdin and returns it to stdout
# Each address must be on a new line
# Address that equal to $REMOTE_ADDR marked with label 'It's you'
mark_its_you() {
        while read addr
        do
                if [ $addr == $REMOTE_ADDR ]
                then
                        echo $addr \<sup\>\<small\>It\'s you\</small\>\</sup\>
                else
                        echo $addr
                fi
        done
}

# returns 1 if there is establishd connection to ssh port
we_has_connection_to_ssh_port()
{
        netstat -tn      |
        tr '\:' ' '      |
        awk '{print $5}' |
        grep '^'$SSH_PORT > /dev/null
        return $((!$?))
}

# prints list remote ip connected to ssh port
print_ip_connected_to_ssh_port()
{
        echo "SSH clients:"
        netstat -tn      | # get all tcp connections
        tr '\:' ' '        | # remove :
        awk '{print$5,$6}' | # get local port & remote addr only
        grep '^'$SSH_PORT  | # filter where local port = ssh port
        awk '{print $2}'   | # get remote ip only
        # uniq               |
        sort               |
        mark_its_you       | # add 'its you' label
        sed ':a;N;$!ba;s/\n/, /g' # remove \n and add commas
}

# returns 1 if inet is down
inet_is_down()
{
        ping $ADDR_TO_PING -c 1 -W 2 > /dev/null
}

# return 1 if dummy overlay not mounted
dummy_overlay_not_mounted()
{
        if [ $(mount | grep -c 'bin\|etc\|lib\|sbin\|usr\|www') -ne 6 ]
        then
                return 1
        fi
        return 0
}

print_external_addresses()
{
        ifconfig l2tp-vpn |
        grep 'inet addr'  |
        tr '\:' ' '       |
        awk '{print $3}'
        ifconfig eth0.2   |
        grep 'inet addr'  |
        tr '\:' ' '       |
        awk '{print $3}'
}

# Show list computers in local network
print_list_local_computers ()
{
        cat /proc/net/arp | # get arp cache
        grep  br-lan      | # grep needed interface
        awk '{print $1, toupper($4)}'  | # get ip and mac
        sort              |
        while read ip mac
        do
                ping $ip -c 1 -W 1 > /dev/null
                if [ $? -ne 0 ]
                then
                        continue
                fi
                iwinfo wlan0 assoclist |
                grep $mac > /dev/null
                if [ $? -eq 0 ]
                then
                        # http://p.yusukekamiyamane.com
                        echo -n '<img src=../wifi.png align=top alt="Connected via wifi"> '
                else
                        echo -n '<img src=../ethernet.png align=top alt="Connected via ethernet"> '
                fi
                # Print address and computer name
                echo $ip |
                mark_its_you  |
                tr '\n' ' '
                nslookup $ip |
                tail -1           |
                awk '{print $4}'
        done
}

print_memory_info()
{
        cat /proc/meminfo |
        grep 'MemFree\|MemAvailable'
        df -h    |
        grep mnt |
        awk '{print ("Flash: ") $4 (" of ") $2}'
}

process_warning()
{
        $1
        if [ $? -ne 0 ]
        then
                echo '<div class="warn">Warning: '
                $2
                echo '</div> <br>'
        fi
}

process_spoilered()
{
        echo '<div class="spoiler">'
        echo '<div class="subhead">'$1'</div>'
        echo '<input type="checkbox" ><div class="box">'
        echo -n '<div class="rec">'
        $2
        echo '</div></div>'
}

cat header.html
cat page.template |
while read line
do
        if [ -z "$line" ]
        then
                continue
        fi
        if [ ${line:0:1} == "#" ]
        then
                continue
        fi
        if [ "$line" == "warning" ]
        then
                read condition
                read command
                process_warning "$condition" "$command"
                continue
        fi
        if [ "$line" == "spoilered" ]
        then
                read subheader
                read command
                process_spoilered "$subheader" "$command"
                continue
        fi
        subheader=$line
        read command
        echo -n '<div class="subhead">'$subheader'</div><div class="rec">'
        $command
        echo '</div>'
done
echo '</body></html>'


exit 0


