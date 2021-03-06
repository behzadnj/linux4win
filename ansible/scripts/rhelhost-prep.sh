#!/bin/bash
(

set -x

RHN_ACCOUNT=THEACCOUNT
RHN_PASSWORD=THEPASSWORD

#preps the first cockpit server
useradd rhel
echo "linux4winPass2020" | passwd rhel --stdin
usermod -aG wheel rhel
echo "rhel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/rhel
chmod 0440 /etc/sudoers.d/rhel

#cockpit update / firewalld fix
dnf update dnf subscription-manager polkit -y

#install enable and open firewall for cockpit
yum install firewalld cockpit-composer cockpit bash-completion -y
systemctl enable --now firewalld
systemctl enable --now cockpit.socket
setenforce 0
firewall-cmd --add-service=cockpit
firewall-cmd --add-service=cockpit --permanent
setenforce 1

#prep for assign3,4
sed -i  -e 's/PasswordAuthentication no/PasswordAuthentication yes/1' /etc/ssh/sshd_config
systemctl restart sshd

#protect ourselfs from network outages
LOOP=0
while true; do
        ping -c1 subscription.rhn.redhat.com >/dev/null
        if [ "$?" -eq 0 ]; then
                echo "We can reach Red Hat Network"
                break
        else
                LOOP=$(expr $LOOP +1)
                if [ "$LOOP" -eq 120 ]; then
                        echo "We've waited for 2 minutes... exiting."
                        exit 1
                fi
        fi
done

subscription-manager register --username=$RHN_ACCOUNT --password=$RHN_PASSWORD --force --auto-attach
if [ "$?" -ne 0 ]; then
        sleep 5
        subscription-manager register --username=$RHN_ACCOUNT --password=$RHN_PASSWORD --force --auto-attach
        if [ "$?" -ne 0 ]; then
                sleep 5
                subscription-manager register --username=$RHN_ACCOUNT --password=$RHN_PASSWORD --force --auto-attach
                if [ "$?" -eq 0 ]; then
                        rm -f /etc/yum.repos.d/*rhui*
                else
                        echo "I tried 3 times, I'm giving up."
                        exit 1
                fi
        else
                rm -f /etc/yum.repos.d/*rhui*
        fi
else
        rm -f /etc/yum.repos.d/*rhui*
fi

) >/tmp/user-data.log 2>&1

# fix for corrupt rpm db
rpmdb --rebuilddb

#comment out for debug
rm -rf /var/lib/cloud/instance
rm -f /tmp/user-data.log
