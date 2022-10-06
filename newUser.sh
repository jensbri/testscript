#!/bin/bash

# Name of the group everybody is in
group_name='research'
shared_folder='/data' # do we have to check that they do not already use /data?

function display_help {
    echo ""
    echo "Usage $0 [-h] <username> <public_ssh_key_file>"
    echo "  <username>: Name of the user to be created, e.g. jche159"
    echo "  <public_ssh_key_file>: Path to the public SSH key file, matching the private key <username> is going to use to log into the VM"
    # how do they pass that keyfile on? Do they potentialy have to create one in the first place?
    echo "  -h: print this help message"
    echo ""
}

# Check arguments passed in through the command-line
if [ "$#" -lt "1" ]; then
    echo "WARNING: No command-line argument provided"
    display_help
    exit 1
elif [ "$#" -eq "1" ] && [ "$1" == "-h" ]; then
    display_help
    exit 0
elif [ "$#" -eq "2" ]; then
    user_name=$1
    pub_ssh_key_file=$2
    if [ ! -f "${pub_ssh_key_file}" ]; then
        echo "Public SSH key file '${pub_ssh_key_file}' does not exist."
        echo "Exiting..."
      exit 1
    fi
elif [ "$#" -gt "2" ]; then
    echo "WARNING: More than 2 command-line arguments provided"
    display_help
    exit 1
else
    echo "WARNING: Unexpected error"
    exit 1
fi

# Create group if it does not already exists
if [ $(getent group "${group_name}") ]; then
    echo "Group ${group_name} already exists."
else
    echo "Group ${group_name} does not yet exist. Creating..."
    sudo groupadd ${group_name}
fi

# Create user if it does not already exists
if [ $(getent passwd "${user_name}") ]; then
    echo "User ${user_name} already exists."
else
    echo "User ${user_name} does not yet already. Creating..."
    sudo useradd --base-dir /home --shell /bin/bash ${user_name}
    authz_key_file="/home/${user_name}/.ssh/authorized_keys"
    sudo mkdir -p /home/${user_name}/.ssh
    sudo touch ${authz_key_file}
    cat "${pub_ssh_key_file}" | sudo tee --append ${authz_key_file}
    sudo chmod 600 ${authz_key_file}
    sudo chmod 700 /home/${user_name}
    sudo chown -R ${user_name}: /home/${user_name}
    sudo usermod -a -G ${group_name} ${user_name}
    echo "${user_name}	ALL=(ALL) NOPASSWD: ALL" | sudo tee --append /etc/sudoers
fi

# Create shared folder if it does not exist yet
if [ ! -d ${shared_folder} ]; then
 sudo mkdir ${shared_folder}
fi

# install dependency package
sudo dpkg -l acl > /dev/null
if [ "$?" -gt "0" ]; then
    sudo apt-get install acl
fi

sudo chown -R root:${group_name} ${shared_folder}
# set SETGID bit to ensure files and folders are always created with the right group id
sudo chmod -R g+s ${shared_folder}
# set ACLs to ensure that the group has always the right permissions on files and folders
sudo setfacl -Rm group:${group_name}:rwx ${shared_folder}
sudo setfacl -Rm default:group:${group_name}:rwx ${shared_folder}

