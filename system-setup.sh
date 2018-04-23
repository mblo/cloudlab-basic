#!/usr/bin/env bash
# Script for setting up the cluster after initial booting and configuration by
# CloudLab.

# Get the absolute path of this script on the system.
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

exec > >(tee "$SCRIPTPATH/system.log") 2>&1

# Echo all the args so we can see how this script was invoked in the logs.
echo -e "\n===== SCRIPT PARAMETERS ====="
echo $@
echo

# === Parameters decided by profile.py ===
# RCNFS partition that will be exported via NFS and used as a shared home
# directory for cluster users.
NODE_LOCAL_STORAGE_DIR=$1
# Account in which various software should be setup.
USERNAME=$2
# Number of worker machines in the cluster.
NUM_WORKER=$3
# Number of aggregation switches in the cluster.
NUM_AGG=$4

# === Paarameters decided by this script. ===
# Directory where the NFS partition will be mounted on NFS clients


# Other variables
KERNEL_RELEASE=`uname -r`
UBUNTU_RELEASE=`lsb_release --release | awk '{print $2}'`
NODES_TXT="hosts.txt"

# === Here goes configuration that's performed on every boot. ===

# nothing to do

# Check if we've already complete setup before. If so, the buck stops here.
# Everything above will be executed on every boot. Everything below this will be
# executed on the first boot only. Therefore any soft state that's reset after a
# reboot should be set above. If the soft state can only be set after setup,
# then it should go inside this if statement.
if [ -f /local/setup_done ]
then
  echo "setup already done"
  exit 0
fi

# === Here goes configuration that happens once on the first boot. ===

chown "$USERNAME:$USERNAME" "$NODE_LOCAL_STORAGE_DIR"

# === Software dependencies that need to be installed. ===
# Common utilities
echo -e "\n===== INSTALLING COMMON UTILITIES ====="
apt-get update
apt-get --assume-yes install vim htop python2.7 python-requests openjdk-8-jre ack-grep python-minimal whois

# create new admin user
useradd -p `mkpasswd "test"` -d /home/"$USERNAME" -m -g users -s /bin/bash "$USERNAME"
passwd -d $USERNAME
gpasswd -a $USERNAME root

# === Configuration settings for all machines ===
# Make vim the default editor.
cat >> /etc/profile.d/etc.sh <<EOM
export EDITOR=vim
EOM
chmod ugo+x /etc/profile.d/etc.sh

# Disable user prompting for sshing to new hosts.
cat >> /etc/ssh/ssh_config <<EOM
    StrictHostKeyChecking no
EOM

# Change default shell to bash for all users on all machines
echo -e "\n===== CHANGE USERS SHELL TO BASH ====="
for user in $(ls /home/)
do
  chsh -s /bin/bash $user
done

echo -e "\n===== SETTING UP SSH BETWEEN NODES ====="
ssh_dir=/home/$USERNAME/.ssh
mkdir "$ssh_dir"
/usr/bin/geni-get key > $ssh_dir/id_rsa
ssh-keygen -y -f $ssh_dir/id_rsa > $ssh_dir/id_rsa.pub
cat $ssh_dir/id_rsa.pub >> $ssh_dir/authorized_keys
chown $USERNAME: $ssh_dir/id_rsa
chmod 600 $ssh_dir/id_rsa
chown $USERNAME: $ssh_dir/authorized_keys
chmod 644 $ssh_dir/authorized_keys

# Add machines to /etc/hosts
echo -e "\n===== ADDING HOSTS TO /ETC/HOSTS ====="
hostArray=("jumphost" "expctrl")
for i in $(seq 1 $NUM_WORKER)
do
  host=$(printf "worker%02d" $i)
  hostArray=("${hostArray[@]}" "$host")
done

for host in ${hostArray[@]}
do
  while ! nc -z -v -w5 $host 22
  do
    sleep 1
    echo "Waiting for $host to come up..."
  done
  # ctrlip localip hostname
  if [ "$host" == "jumphost"]
  then
    continue
  fi
  echo $(getent hosts $host | awk '{ print $1 ; exit }')" "$(getent hosts $host | awk '{ print $1 ; exit }')" $host"  >> /home/$USERNAME/$NODES_TXT
done


# jumphost specific configuration.
if [ $(hostname --short) == "jumphost" ]
then

  echo -e "\n===== SETTING UP AUTOMATIC TMUX ON JUMPHOST ====="
  # Make tmux start automatically when logging into rcmaster
  cat >> /etc/profile.d/etc.sh <<EOM

if [[ -z "\$TMUX" ]] && [ "\$SSH_CONNECTION" != "" ]
then
  tmux attach-session -t ssh_tmux || tmux new-session -s ssh_tmux
fi
EOM
fi

# Mark that setup has finished. This script is actually run again after a
# reboot, so we need to mark that we've already setup this machine and catch
# this flag after a reboot to prevent ourselves from re-running everything.
touch /local/setup_done

echo -e "\n===== SYSTEM SETUP COMPLETE ====="
