#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error: ${plain}You must run this script as root!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
else
    echo -e "${red}System version not detected, please contact the script author!${plain}\n" && exit 1
fi

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Please use CentOS 7 or higher version of the system!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or higher version of the system!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Please use Debian 8 or higher version of the system!${plain}\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -rp "$1 [default $2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -rp "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Whether to restart Aiko-Server" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Press Enter to return to the main menu:${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontents.com/Github-Aiko/Aiko-Server-script/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    if [[ $# == 0 ]]; then
        echo && echo -n -e "Enter the specified version (default is the latest version): " && read version
    else
        version=$2
    fi
    bash <(curl -Ls https://raw.githubusercontents.com/Github-Aiko/Aiko-Server-script/master/install.sh) $version
    if [[ $? == 0 ]]; then
        echo -e "${green}The update is complete, Aiko-Server has been automatically restarted, please use Aiko-Server log to view the running log${plain}"
        exit
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

config() {
    echo "Aiko-Server will automatically attempt to restart after modifying the configuration"
    nano /etc/Aiko-Server/aiko.yml
    sleep 2
    check_status
    case $? in
        0)
            echo -e "Aiko-Server status: ${green}Running${plain}"
            ;;
        1)
            echo -e "Aiko-Server is not running or failed to automatically restart. Do you want to view the log file? [Y/n]" && echo
            read -e -rp "(default: y):" yn
            [[ -z ${yn} ]] && yn="y"
            if [[ ${yn} == [Yy] ]]; then
               show_log
            fi
            ;;
        2)
            echo -e "Aiko-Server status: ${red}Not installed${plain}"
    esac
}

uninstall() {
    confirm "Are you sure you want to uninstall Aiko-Server?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop Aiko-Server
    systemctl disable Aiko-Server
    rm /etc/systemd/system/Aiko-Server.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/Aiko-Server/ -rf
    rm /usr/local/Aiko-Server/ -rf

    echo ""
    echo -e "Uninstall successful. If you want to delete this script, run ${green}rm /usr/bin/Aiko-Server -f${plain} after exiting the script"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}Aiko-Server is already running, no need to start again. To restart, please select Restart${plain}"
    else
        systemctl start Aiko-Server
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}Aiko-Server started successfully, please use Aiko-Server log to view the running log${plain}"
        else
            echo -e "${red}Aiko-Server may have failed to start. Please check the log information later with Aiko-Server log${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    systemctl stop Aiko-Server
    sleep 2
    check_status
    if [[ $? == 1 ]]; then
        echo -e "${green}Aiko-Server has been stopped${plain}"
    else
        echo -e "${red}Aiko-Server failed to stop, may be because the stop time exceeds two seconds, please check the log information later${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart Aiko-Server
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}Aiko-Server restarted successfully, please use Aiko-Server log to view the running log${plain}"
    else
        echo -e "${red}Aiko-Server may have failed to start. Please check the log information later with Aiko-Server log${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status Aiko-Server --no-pager -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable Aiko-Server
    if [[ $? == 0 ]]; then
        echo -e "${green}Aiko-Server has been set to start automatically${plain}"
    else
        echo -e "${red}Failed to set Aiko-Server to start automatically${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable Aiko-Server
    if [[ $? == 0 ]]; then
        echo -e "${green}Aiko-Server has been set to not start automatically${plain}"
    else
        echo -e "${red}Failed to set Aiko-Server to not start automatically${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u Aiko-Server.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

install_bbr() {
    bash <(curl -L -s https://raw.githubusercontents.com/chiakge/Linux-NetSpeed/master/tcp.sh)
}

update_shell() {
    wget -O /usr/bin/Aiko-Server -N --no-check-certificate https://raw.githubusercontents.com/Github-Aiko/Aiko-Server-script/master/Aiko-Server.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}Failed to download script. Please check if the local machine can connect to Github${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/Aiko-Server
        echo -e "${green}Script upgrade completed. Please run the script again${plain}" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/Aiko-Server.service ]]; then
        return 2
    fi
    temp=$(systemctl status Aiko-Server | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled Aiko-Server)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}Aiko-Server is already installed. Please do not reinstall it${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}Please install Aiko-Server first${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "Aiko-Server status: ${green}Running${plain}"
            show_enable_status
            ;;
        1)
            echo -e "Aiko-Server status: ${yellow}Not running${plain}"
            show_enable_status
            ;;
        2)
            echo -e "Aiko-Server status: ${red}Not installed${plain}"
    esac
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Whether to start automatically: ${green}Yes${plain}"
    else
        echo -e "Whether to start automatically: ${red}No${plain}"
    fi
}

show_Aiko-Server_version() {
   echo -n "Aiko-Server version:"
    /usr/local/Aiko-Server/Aiko-Server -version
    echo ""
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}



generate_config_file() {
    echo -e "${yellow}Aiko-Server Configuration File Wizard${plain}"
    echo -e "${red}Please read the following notes:${plain}"
    echo -e "${red}1. This feature is currently in testing${plain}"
    echo -e "${red}2. The generated configuration file will be saved to /etc/Aiko-Server/aiko.yml${plain}"
    echo -e "${red}3. The original configuration file will be saved to /etc/Aiko-Server/aiko.yml.bak${plain}"
    echo -e "${red}4. TLS is not currently supported${plain}"
    read -rp "Do you want to continue generating the configuration file? (y/n)" generate_config_file_continue
    if [[ $generate_config_file_continue =~ "y"|"Y" ]]; then
        read -rp "Please enter the domain name of your server: " ApiHost
        read -rp "Please enter the panel API key: " ApiKey
        read -rp "Please enter the node ID: " NodeID
        echo -e "${yellow}Please select the node transport protocol, if not listed then it is not supported:${plain}"
        echo -e "${green}1. Shadowsocks${plain}"
        echo -e "${green}2. V2ray${plain}"
        echo -e "${green}3. Trojan${plain}"
        echo -e "${green}4. Hysteria${plain}"
        read -rp "Please enter the transport protocol (1-4, default 1): " NodeType
        case "$NodeType" in
            1 ) NodeType="Shadowsocks" ;;
            2 ) NodeType="V2ray" ;;
            3 ) NodeType="Trojan" ;;
            4 ) NoodeType="Hysteria" ;;
            * ) NodeType="V2ray" ;;
        esac
        echo -e "${yellow}Please select the Sniffing is Enable or Disable, Default is Disable :${plain}"
        echo -e "${green}1. Enable${plain}"
        echo -e "${green}2. Disable${plain}"
        read -rp "Please enter the Sniffing (1-2, default 2): " Sniffing
        case "$Sniffing" in
            1 ) Sniffing="false" ;;
            2 ) Sniffing="true" ;;
            * ) Sniffing="true" ;;
        esac
        cd /etc/Aiko-Server
        mv aiko.yml aiko.yml.bak
        cat <<EOF > /etc/Aiko-Server/aiko.yml
CoreConfig:
  Type: "xray" # Core type. if you need many cores, use " " to split
  XrayConfig:
    Log:
      Level: none # Log level: none, error, warning, info, debug
      AccessPath: # /etc/Aiko-Server/access.Log
      ErrorPath: # /etc/Aiko-Server/error.log
    DnsConfigPath: # /etc/Aiko-Server/dns.json # Path to dns config, check https://xtls.github.io/config/dns.html for help
    RouteConfigPath: # /etc/Aiko-Server/route.json # Path to route config, check https://xtls.github.io/config/routing.html for help
    InboundConfigPath: # /etc/Aiko-Server/custom_inbound.json # Path to custom inbound config, check https://xtls.github.io/config/inbound.html for help
    OutboundConfigPath: # /etc/Aiko-Server/custom_outbound.json # Path to custom outbound config, check https://xtls.github.io/config/outbound.html for help
    ConnectionConfig:
      Handshake: 4 # Handshake time limit, Second
      ConnIdle: 30 # Connection idle time limit, Second
      UplinkOnly: 2 # Time limit when the connection downstream is closed, Second
      DownlinkOnly: 4 # Time limit when the connection is closed after the uplink is closed, Second
      BufferSize: 64 # The internal cache size of each connection, kB
Nodes:
  - ApiConfig:
      ApiHost: "$ApiHost"
      ApiKey: "$ApiKey"
      NodeID: $NodeID
      NodeType: V2ray # Node type: V2ray, Shadowsocks, Trojan
      Timeout: 30 # Timeout for the api request
      RuleListPath: # /etc/Aiko-Server/rulelist Path to local rulelist file
    ControllerConfig:
      ListenIP: 0.0.0.0 # IP address you want to listen
      SendIP: 0.0.0.0 # IP address you want to send pacakage
      XrayOptions:
        EnableDNS: false # Use custom DNS config, Please ensure that you set the dns.json well
        DNSType: AsIs # AsIs, UseIP, UseIPv4, UseIPv6, DNS strategy
        EnableTFO: false # Enable TCP Fast Open
        EnableVless: false # Enable Vless for V2ray Type
        EnableXtls: false  # Enable xtls-rprx-vision, only vless
        EnableProxyProtocol: false # Only works for WebSocket and TCP
        EnableFallback: false # Only support for Trojan and Vless
        DisableSniffing: $Sniffing # Disable sniffing
        FallBackConfigs: # Support multiple fallbacks
          - SNI: # TLS SNI(Server Name Indication), Empty for any
            Alpn: # Alpn, Empty for any
            Path: # HTTP PATH, Empty for any
            Dest: 80 # Required, Destination of fallback, check https://xtls.github.io/config/features/fallback.html for details.
            ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for dsable
      HyOptions:
        Resolver: "udp://1.1.1.1:53" # DNS resolver address
        ResolvePreference: 64 # DNS IPv4/IPv6 preference. Available options: "64" (IPv6 first, fallback to IPv4), "46" (IPv4 first, fallback to IPv6), "6" (IPv6 only), "4" (IPv4 only)
        SendDevice: "eth0" # Bind device for outbound connections (usually requires root)
      LimitConfig:
        EnableRealtime: false # Check device limit on real time
        SpeedLimit: 0 # Mbps, Local settings will replace remote settings, 0 means disable
        DeviceLimit: 0 # Local settings will replace remote settings, 0 means disable
        ConnLimit: 0 # Connecting limit, only working for TCP, 0mean
        EnableIpRecorder: false # Enable online ip report
        IpRecorderConfig:
          Type: "Recorder" # Recorder type: Recorder, Redis
          RecorderConfig:
            Url: "http://127.0.0.1:123" # Report url
            Token: "123" # Report token
            Timeout: 10 # Report timeout, sec.
          RedisConfig:
            Address: "127.0.0.1:6379" # Redis address
            Password: "" # Redis password
            DB: 0 # Redis DB
            Expiry: 60 # redis expiry time, sec.
          Periodic: 60 # Report interval, sec.
          EnableIpSync: false # Enable online ip sync
        EnableDynamicSpeedLimit: false # Enable dynamic speed limit
        DynamicSpeedLimitConfig:
          Periodic: 60 # Time to check the user traffic , sec.
          Traffic: 0 # Traffic limit, MB
          SpeedLimit: 0 # Speed limit, Mbps
          ExpireTime: 0 # Time limit, sec.
      CertConfig:
        CertMode: dns # Option about how to get certificate: none, file, http, dns, reality. Choose "none" will forcedly disable the tls config.
        CertDomain: "node1.test.com" # Domain to cert
        CertFile: /etc/Aiko-Server/cert/node1.test.com.cert # Provided if the CertMode is file
        KeyFile: /etc/Aiko-Server/cert/node1.test.com.key
        Provider: alidns # DNS cert provider, Get the full support list here: https://go-acme.github.io/lego/dns/
        Email: test@me.com
        DNSEnv: # DNS ENV option used by DNS provider
          ALICLOUD_ACCESS_KEY: aaa
          ALICLOUD_SECRET_KEY: bbb
        RealityConfig: # This config like RealityObject for xray-core, please check https://xtls.github.io/config/transport.html#realityobject
          Dest: 80 # Same fallback dest
          Xver: 0 # Same fallback xver
          ServerNames:
            - "example.com"
            - "www.example.com"
          PrivateKey: "" # Private key for server
          MinClientVer: "" # Min client version
          MaxClientVer: "" # Max client version
          MaxTimeDiff: 0 # Max time difference, ms
          ShortIds: # Short ids
            - ""
            - "0123456789abcdef"
EOF
        echo -e "${green}Aiko-Server configuration file generated successfully, and Aiko-Server service is being restarted${plain}"
        restart 0
        before_show_menu
    else
        echo -e "${red}Aiko-Server configuration file generation cancelled${plain}"
        before_show_menu
    fi
}

# Open firewall ports
open_ports() {
    systemctl stop firewalld.service 2>/dev/null
    systemctl disable firewalld.service 2>/dev/null
    setenforce 0 2>/dev/null
    ufw disable 2>/dev/null
    iptables -P INPUT ACCEPT 2>/dev/null
    iptables -P FORWARD ACCEPT 2>/dev/null
    iptables -P OUTPUT ACCEPT 2>/dev/null
    iptables -t nat -F 2>/dev/null
    iptables -t mangle -F 2>/dev/null
    iptables -F 2>/dev/null
    iptables -X 2>/dev/null
    netfilter-persistent save 2>/dev/null
    echo -e "${green}All network ports on the VPS are now open!${plain}"
}

show_usage() {
    echo "Aiko-Server Management Script Usage: "
    echo "------------------------------------------"
    echo "Aiko-Server              - Show management menu (with more functions)"
    echo "Aiko-Server start        - Start Aiko-Server"
    echo "Aiko-Server stop         - Stop Aiko-Server"
    echo "Aiko-Server restart      - Restart Aiko-Server"
    echo "Aiko-Server status       - Check Aiko-Server status"
    echo "Aiko-Server enable       - Set Aiko-Server to start on boot"
    echo "Aiko-Server disable      - Disable Aiko-Server from starting on boot"
    echo "Aiko-Server log          - View Aiko-Server logs"
    echo "Aiko-Server generate     - Generate Aiko-Server configuration file"
    echo "Aiko-Server update       - Update Aiko-Server"
    echo "Aiko-Server update x.x.x - Install specific version of Aiko-Server"
    echo "Aiko-Server install      - Install Aiko-Server"
    echo "Aiko-Server uninstall    - Uninstall Aiko-Server"
    echo "Aiko-Server version      - Show Aiko-Server version"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}Aiko-Server Backend Management Script, ${plain}${red}not for docker${plain}
--- https://github.com/Github-Aiko/Aiko-Server ---
  ${green}0.${plain} Modify configuration
————————————————
  ${green}1.${plain} Install Aiko-Server
  ${green}2.${plain} Update Aiko-Server
  ${green}3.${plain} Uninstall Aiko-Server
————————————————
  ${green}4.${plain} Start Aiko-Server
  ${green}5.${plain} Stop Aiko-Server
  ${green}6.${plain} Restart Aiko-Server
  ${green}7.${plain} Check Aiko-Server status
  ${green}8.${plain} View Aiko-Server logs
————————————————
  ${green}9.${plain} Set Aiko-Server to start on boot
 ${green}10.${plain} Disable Aiko-Server from starting on boot
————————————————
 ${green}11.${plain} Install BBR (latest kernel) with one click
 ${green}12.${plain} Show Aiko-Server version
 ${green}13.${plain} Upgrade Aiko-Server maintenance script
 ${green}14.${plain} Generate Aiko-Server configuration file
 ${green}15.${plain} Open all network ports on VPS
 "
    show_status
    echo && read -rp "Please enter options [0-14]: " num

    case "${num}" in
        0) config ;;
        1) check_uninstall && install ;;
        2) check_install && update ;;
        3) check_install && uninstall ;;
        4) check_install && start ;;
        5) check_install && stop ;;
        6) check_install && restart ;;
        7) check_install && status ;;
        8) check_install && show_log ;;
        9) check_install && enable ;;
        10) check_install && disable ;;
        11) install_bbr ;;
        12) check_install && show_Aiko-Server_version ;;
        13) update_shell ;;
        14) generate_config_file ;;
        15) open_ports ;;
        *) echo -e "${red}Please enter the correct number [0-14]${plain}" ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0 ;;
        "stop") check_install 0 && stop 0 ;;
        "restart") check_install 0 && restart 0 ;;
        "status") check_install 0 && status 0 ;;
        "enable") check_install 0 && enable 0 ;;
        "disable") check_install 0 && disable 0 ;;
        "log") check_install 0 && show_log 0 ;;
        "update") check_install 0 && update 0 $2 ;;
        "config") config $* ;;
        "generate") generate_config_file ;;
        "install") check_uninstall 0 && install 0 ;;
        "uninstall") check_install 0 && uninstall 0 ;;
        "version") check_install 0 && show_Aiko-Server_version 0 ;;
        "update_shell") update_shell ;;
        *) show_usage
    esac
else
    show_menu
fi
