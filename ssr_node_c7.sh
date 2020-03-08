#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
cat << "EOF"                                                         
Author: squirrelmedia
Github: https://github.com/squirrelmedia/Airport-toolkit                                 
EOF
echo "适用于CentOS 7 x64的Shadowsocksr服务器安装脚本"
[ $(id -u) != "0" ] && { echo "错误：您必须是root用户才能运行此脚本！"; exit 1; }
ARG_NUM=$#
TEMP=`getopt -o hvV --long is_auto:,connection_method:,is_mu:,webapi_url:,webapi_token:,db_ip:,db_name:,db_user:,db_password:,node_id:-- "$@" 2>/dev/null`
[ $? != 0 ] && echo "错误：参数未知！" && exit 1
eval set -- "${TEMP}"
while :; do
  [ -z "$1" ] && break;
  case "$1" in
	--is_auto)
      is_auto=y; shift 1
      [ -d "/soft/shadowsocks" ] && { echo "Shadowsocksr服务器软件已经存在"; exit 1; }
      ;;
    --connection_method)
      connection_method=$2; shift 2
      [[ ! ${connection_method} =~ ^[1-2]$ ]] && { echo "错误的输入！ 请只输入数字1〜2"; exit 1; }
      ;;
    --is_mu)
      is_mu=y; shift 1
      ;;
    --webapi_url)
      webapi_url=$2; shift 2
      ;;
    --webapi_token)
      webapi_token=$2; shift 2
      ;;
    --db_ip)
      db_ip=$2; shift 2
      ;;
    --db_name)
      db_name=$2; shift 2
      ;;
    --db_user)
      db_user=$2; shift 2
      ;;
    --db_password)
      db_password=$2; shift 2
      ;;
    --node_id)
      node_id=$2; shift 2
      ;;
    --)
      shift
      ;;
    *)
      echo "错误：参数未知！" && exit 1
      ;;
  esac
done
if [[ ${is_auto} != "y" ]]; then
	echo "按Y继续安装过程，或按其他任意键退出。"
	read is_install
	if [[ ${is_install} != "y" && ${is_install} != "Y" ]]; then
    	echo -e "安装已被取消..."
    	exit 0
	fi
fi
echo "正在检查是否存在Shadowsocksr服务器软件..."
if [ -d "/soft/shadowsocks" ]; then
	while :; do echo
		echo -n "检测是否存在Shadowsocks服务器安装！ 如果继续此安装，所有先前的配置都将丢失！ 继续吗？(Y/N)"
		read is_clean_old
		if [[ ${is_clean_old} != "y" && ${is_clean_old} != "Y" && ${is_clean_old} != "N" && ${is_clean_old} != "n" ]]; then
			echo -n "错误的输入！ 请仅输入字母Y或N"
		elif [[ ${is_clean_old} == "y" || ${is_clean_old} == "Y" ]]; then
			rm -rf /soft
			break
		else
			exit 0
		fi
	done
fi
echo "正在更新退出程序包..."
yum clean all && rm -rf /var/cache/yum && yum update -y
echo "正在配置EPEL版本..."
yum install epel-release -y && yum makecache
echo "安装必要的程序包..."
yum install git net-tools htop ntp -y
echo "禁用firewalld ..."
systemctl stop firewalld && systemctl disable firewalld
echo "设置系统时区..."
timedatectl set-timezone Asia/Taipei && systemctl stop ntpd.service && ntpdate us.pool.ntp.org
echo "正在安装libsodium ..."
yum install libsodium -y
echo "正在安装Python3.6 ..."
yum install python36 python36-pip -y
echo "从GitHub安装Shadowsocksr服务器..."
mkdir /soft
cd /tmp && git clone -b manyuser https://github.com/Anankke/shadowsocks-mod.git
mv shadowsocks-mod shadowsocks
mv -f shadowsocks /soft
cd /soft/shadowsocks
pip3 install --upgrade pip setuptools
pip3 install -r requirements.txt
echo "正在生成配置文件..."
cp apiconfig.py userapiconfig.py
cp config.json user-config.json
if [[ ${is_auto} != "y" ]]; then
	#Choose the connection method
	while :; do echo
		echo -e "请选择您的节点服务器连接方式："
		echo -e "\t1. WebAPI"
		echo -e "\t2. 数据库"
		read -p "请输入数字：（默认2按 Enter）" connection_method
		[ -z ${connection_method} ] && connection_method=2
		if [[ ! ${connection_method} =~ ^[1-2]$ ]]; then
			echo "错误的输入！ 请只输入数字1〜2"
		else
			break
		fi			
	done
	while :; do echo
		echo -n "是否要在单端口中启用多用户功能？(Y/N)"
		read is_mu
		if [[ ${is_mu} != "y" && ${is_mu} != "Y" && ${is_mu} != "N" && ${is_mu} != "n" ]]; then
			echo -n "错误的输入！ 请仅输入字母Y或N"
		else
			break
		fi
	done
fi
do_mu(){
	if [[ ${is_auto} != "y" ]]; then
		echo -n "请输入 MU_SUFFIX:"
		read mu_suffix
		echo -n "请输入 MU_REGEX:"
		read mu_regex
		echo "正在配置..."
	fi
	sed -i -e "s/MU_SUFFIX = 'zhaoj.in'/MU_SUFFIX = '${mu_suffix}'/g" -e "s/MU_REGEX = '%5m%id.%suffix'/MU_REGEX = '${mu_regex}'/g" userapiconfig.py
}
do_modwebapi(){
	if [[ ${is_auto} != "y" ]]; then
		echo -n "请输入 WebAPI url:"
		read webapi_url
		echo -n "请输入 WebAPI token:"
		read webapi_token
		echo -n "节点 node ID:"
		read node_id
	fi
	if [[ ${is_mu} == "y" || ${is_mu} == "Y" ]]; then
		do_mu
	fi
	echo "正在编写配置..."
	sed -i -e "s/NODE_ID = 0/NODE_ID = ${node_id}/g" -e "s%WEBAPI_URL = 'https://zhaoj.in'%WEBAPI_URL = '${webapi_url}'%g" -e "s/WEBAPI_TOKEN = 'glzjin'/WEBAPI_TOKEN = '${webapi_token}'/g" userapiconfig.py
}
do_glzjinmod(){
	if [[ ${is_auto} != "y" ]]; then
		sed -i -e "s/'modwebapi'/'glzjinmod'/g" userapiconfig.py
		echo -n "请输入数据库服务器的IP地址："
		read db_ip
		echo -n "数据库名:"
		read db_name
		echo -n "数据库用户名:"
		read db_user
		echo -n "数据库密码:"
		read db_password
		echo -n "服务器节点ID:"
		read node_id
	fi
	if [[ ${is_mu} == "y" || ${is_mu} == "Y" ]]; then
		do_mu
	fi
	echo "正在编写配置..."
	sed -i -e "s/NODE_ID = 0/NODE_ID = ${node_id}/g" -e "s/MYSQL_HOST = '127.0.0.1'/MYSQL_HOST = '${db_ip}'/g" -e "s/MYSQL_USER = 'ss'/MYSQL_USER = '${db_user}'/g" -e "s/MYSQL_PASS = 'ss'/MYSQL_PASS = '${db_password}'/g" -e "s/MYSQL_DB = 'shadowsocks'/MYSQL_DB = '${db_name}'/g" userapiconfig.py
}
if [[ ${is_auto} != "y" ]]; then
	#Do the configuration
	if [ "${connection_method}" == '1' ]; then
		do_modwebapi
	elif [ "${connection_method}" == '2' ]; then
		do_glzjinmod
	fi
fi
do_bbr(){
	echo "正在运行系统优化并启用BBR ..."
	rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
	rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm
	yum remove kernel-headers -y
	yum --enablerepo=elrepo-kernel install kernel-ml kernel-ml-headers -y
	grub2-set-default 0
	echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
	cat >> /etc/security/limits.conf << EOF
	* soft nofile 51200
	* hard nofile 51200
EOF
	ulimit -n 51200
	cat >> /etc/sysctl.conf << EOF
	fs.file-max = 51200
	net.core.default_qdisc = fq
	net.core.rmem_max = 67108864
	net.core.wmem_max = 67108864
	net.core.netdev_max_backlog = 250000
	net.core.somaxconn = 4096
	net.ipv4.tcp_congestion_control = bbr
	net.ipv4.tcp_syncookies = 1
	net.ipv4.tcp_tw_reuse = 1
	net.ipv4.tcp_fin_timeout = 30
	net.ipv4.tcp_keepalive_time = 1200
	net.ipv4.ip_local_port_range = 10000 65000
	net.ipv4.tcp_max_syn_backlog = 8192
	net.ipv4.tcp_max_tw_buckets = 5000
	net.ipv4.tcp_fastopen = 3
	net.ipv4.tcp_rmem = 4096 87380 67108864
	net.ipv4.tcp_wmem = 4096 65536 67108864
	net.ipv4.tcp_mtu_probing = 1
EOF
	sysctl -p
}
do_service(){
	echo "正在编写系统配置..."
	wget --no-check-certificate -O ssr_node.service https://raw.githubusercontent.com/SuicidalCat/Airport-toolkit/master/ssr_node.service.el7
	chmod 664 ssr_node.service && mv ssr_node.service /etc/systemd/system
	echo "正在启动SSR节点服务..."
	systemctl daemon-reload && systemctl enable ssr_node && systemctl start ssr_node
}
do_salt_minion(){
	echo "安装Salt Minion ..."
	curl -L https://bootstrap.saltstack.com -o install_salt.sh && sudo sh install_salt.sh -P
	echo "正在编写Salt配置..."
	sed -i -e "s/#master: salt/master: ${salt_master_ip}/g" /etc/salt/minion
}
while :; do echo
	echo -n "您要启用BBR功能（写入内核服务）并优化系统吗？(Y/N)"
	read is_bbr
	if [[ ${is_bbr} != "y" && ${is_bbr} != "Y" && ${is_bbr} != "N" && ${is_bbr} != "n" ]]; then
		echo -n "错误的输入！ 请仅输入字母Y或N"
	else
		break
	fi
done
while :; do echo
	echo -n "是否要将SSR节点注册为系统服务？(Y/N)"
	read is_service
	if [[ ${is_service} != "y" && ${is_service} != "Y" && ${is_service} != "N" && ${is_service} != "n" ]]; then
		echo -n "错误的输入！ 请仅输入字母Y或N"
	else
		break
	fi
done
while :; do echo
	echo -n "您要安装Salt Minion吗？(Y/N)"
	read is_salt_minion
	if [[ ${is_salt_minion} != "y" && ${is_salt_minion} != "Y" && ${is_salt_minion} != "N" && ${is_salt_minion} != "n" ]]; then
		echo -n "错误的输入！ 请仅输入字母Y或N"
	elif [[ ${is_salt_minion} == "y" && ${is_salt_minion} == "Y" ]]; then
		echo -n "请输入Salt Master的IP地址："
		read salt_master_ip
		break
	else
		break
	fi
done
if [[ ${is_bbr} == "y" || ${is_bbr} == "Y" ]]; then
	do_bbr
fi
if [[ ${is_service} == "y" || ${is_service} == "Y" ]]; then
	do_service
fi
if [[ ${is_salt_minion} == "y" || ${is_salt_minion} == "Y" ]]; then
	do_salt_minion
fi
echo "系统需要重新启动才能完成安装过程，按Y继续，或按其他任意键退出此脚本。"
read is_reboot
if [[ ${is_reboot} == "y" || ${is_reboot} == "Y" ]]; then
  reboot
else
  echo -e "重新启动已被取消..."
	exit 0
fi
