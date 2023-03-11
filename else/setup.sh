#!/usr/bin/env bash

detect_os() {
    # Detect OS
    # $os_version variables aren't always in use, but are kept here for convenience
    if grep -qs "ubuntu" /etc/os-release; then
        os="ubuntu"
        os_version=$(grep 'VERSION_ID' /etc/os-release | cut -d '"' -f 2 | tr -d '.')
    elif [[ -e /etc/debian_version ]]; then
        os="debian"
        os_version=$(grep -oE '[0-9]+' /etc/debian_version | head -1)
    elif [[ -e /etc/almalinux-release || -e /etc/rocky-release || -e /etc/centos-release ]]; then
        os="centos"
        os_version=$(grep -shoE '[0-9]+' /etc/almalinux-release /etc/rocky-release /etc/centos-release | head -1)
    elif [[ -e /etc/fedora-release ]]; then
        os="fedora"
        os_version=$(grep -oE '[0-9]+' /etc/fedora-release | head -1)
    else
        echo "This installer seems to be running on an unsupported distribution.
    Supported distros are Ubuntu, Debian, AlmaLinux, Rocky Linux, CentOS and Fedora."
        exit
    fi
}
os_version() {
    if [[ "$os" == "ubuntu" && "$os_version" -lt 1804 ]]; then
        echo "Ubuntu 18.04 or higher is required to use this installer.
    This version of Ubuntu is too old and unsupported."
        exit
    fi

    if [[ "$os" == "debian" && "$os_version" -lt 9 ]]; then
        echo "Debian 9 or higher is required to use this installer.
    This version of Debian is too old and unsupported."
        exit
    fi

    if [[ "$os" == "centos" && "$os_version" -lt 7 ]]; then
        echo "CentOS 7 or higher is required to use this installer.
    This version of CentOS is too old and unsupported."
        exit
    fi
}
permissions() {

    # Detect environments where $PATH does not include the sbin directories
    if ! grep -q sbin <<< "$PATH"; then
        echo "$PATH does not include sbin. Try using "su -" instead of 'su'."
        exit
    fi

    if [[ "$EUID" -ne 0 ]]; then
        echo "This installer needs to be run with superuser privileges."
        echo -e "Run the script as root until the installation is complete, after that use it with normal privileges."
        exit
    fi
}
install_dependencies() {
    echo 'Install prerequisites (step 1)'
    if ! [[ $(command -v "$i") ]] ; then
        echo -e "Install PKG: $i"
        permissions

    #    echo -e "go not installed"
        if [[ "$os" = "debian" ]]; then

            apt-get update
            apt install -y python3-pip python3-venv redis git 

        elif [[ "$os" = "ubuntu" ]]; then
            apt-get update
            apt install -y python3-pip python3-venv redis git 

        elif [[ "$os" = "centos" ]]; then
            yum install -y python3-pip python3-venv redis git 
        else
            # Else, OS must be Fedora
            dnf install -y python3-pip python3-venv redis git 
        fi
    fi
    if [ $? == 0 ]; then
      echo 'Successfully installed'
    else
      echo 'An error occurred while installing the prerequisites'
      exit
    fi    

    echo 'start redis service'
    if command -v redis &> /dev/null; then
        systemctl enable --now  redis.service
    fi

    echo "Creating namizun directory (step 2)"
    mkdir -p /var/www/namizun && cd /var/www/namizun

    echo 'Pulling the repository (step 3)'
    git init
    git remote add origin https://github.com/arta-tm/namizun.git
    git pull origin master
    if [ $? != 0 ]; then
      echo 'could not clone the repository'
      exit
    fi

    echo 'Create virtual env (step 4)'
    python3 -m venv /var/www/namizun/venv
    if [ $? != 0 ]; then
      echo "VENV didn't created"
    fi

    echo 'Installing project dependencies (step 5)'
    cd /var/www/namizun && source /var/www/namizun/venv/bin/activate && pip install --upgrade pip && pip install wheel && pip install namizun_core/ namizun_menu/ && deactivate
    if [ $? != 0 ]; then
      echo "Dependencies doesn't installed correctly"
      exit
    fi

    echo 'Create namizun service (step 6)'
    ln -s /var/www/namizun/else/namizun.service /etc/systemd/system/
    if [ $? != 0 ]; then
      echo 'Creating service was failed'
      exit
    fi

    echo 'Reload services and start namizun.service (step 7)'
    systemctl daemon-reload
    sudo systemctl enable namizun.service
    sudo systemctl start namizun.service
    if [ $? != 0 ]; then
      echo "Namizun service didn't started"
      exit
    fi

    echo "make namizun as a command (step 8)"
    ln -s /var/www/namizun/else/namizun /usr/local/bin/ && chmod +x /usr/local/bin/namizun
    if [ $? != 0 ]; then
      echo "failed to add namizun to PATH environment variables"
      exit
    fi

}







detect_os
os_version
install_dependencies