#!/bin/bash
#
############################## 蜈蚣出品 #####################
# Function : openssl openssh update                         #
# Platform : Centos6.x-8.x & Rocky8.x & openEuler 20.x-22.x #
# Version  : 2.6                                            #
# Date     : 2024-09-10                                     #
#############################################################
#
# RHEL8系列操作系统恢复使用旧库，解决编译安装Openssl出现的libssl及libcrypto版本不匹配问题。
# 使用旧库将导致openssl程序版本号与库版本号不一致的问题，暂无完美解决方法。
#
clear
export LANG="en_US.UTF-8"
date_time=$(date +%Y%m%d-%H%M%S)
OLD_IFS=$IFS
IFS=$' '

#
#请根据官方发行的版本号按需要安装的版本修改 <<==================================
zlib_version="zlib-1.3"
openssl_version="openssl-1.1.1w"
openssh_version="openssh-9.8p1"
#源码包链接
zlib_url="https://www.zlib.net/fossils/$zlib_version.tar.gz"
openssl_url="https://www.openssl.org/source/$openssl_version.tar.gz"
openssh_url="https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/$openssh_version.tar.gz"

#安装包路径建议根据安装脚本上传的位置修改 <<==================================
upsslssh_home="/opt/upsslssh"
#默认编译路径
install_path="/usr/local"
#安装目录
install_files="$upsslssh_home/install"
backup_files="$upsslssh_home/backup"
log_files="$upsslssh_home/log"

#需要安装的依赖包
pkg_need="gcc gcc-c++ glibc make autoconf automake openssl openssl-devel pam pam-devel zlib zlib-devel wget tar pcre-devel"

#输出信息颜色
color_0="\033[0m"
color_R="\033[31m"
color_G="\033[32m"
color_Y="\033[33m"
color_C="\033[36m"

#判断是否root用户
if [ $(id -u) != "0" ] ; then
	echo -e "\n"
	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "当前用户为普通用户，必须使用root用户运行，脚本退出. . ."
	sleep 0.25
	echo -e "\n"
	exit
fi

#获取软件版本信息
las_zlib_version=$(echo $zlib_version | awk -F "-" '{print $2}')
las_openssl_version=$(echo $openssl_version | awk -F "-" '{print $2}')
las_openssh_version=$(echo $openssh_version | awk -F "-" '{print $2}')
las_openssh_version_2=$(echo $openssh_version | awk -F "-" '{print $2}' | sed 's/..$//')
old_zlib_version=$(ldconfig -v 2>/dev/null | grep -E "zlib" | awk -F "-" '{print $2'} | awk -F "/lib" '{print $1}') 
old_openssl_version=$(openssl version 2>&1 | awk -F" " '{print $2}' | awk -F"-" '{print $1}' | cut -c1-6) 
old_openssh_version=$(ssh -V 2>&1 | awk -F"," '{print $1}' | awk -F"_" '{print $2}')

if [[ $(openssl version 2>&1) =~ Library ]] ; then
	os_openssl_version=$(openssl version 2>&1 | awk -F"Library" '{print $2}' | awk -F" " '{print $3}')
fi

echo -e "\n"

Install_make()
{
	if [[ -e /etc/redhat-release ]] || [[ -e /etc/openEuler-release ]] || [[ -e /etc/hce-release ]] || [[ -e /etc/kylin-release ]] ; then
		if [ -e /etc/redhat-release ] ; then
			redhat_version=`cat /etc/redhat-release | sed -r 's/.* ([0-9]+)\..*/\1/'`
			if [[ $redhat_version -lt 6 || $redhat_version -gt 8 ]] ; then
				echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "当前操作系统版本可能不被支持，脚本退出. . ."
				sleep 0.25
				echo -e "\n"
				exit
			fi
		fi
		if [ -e /etc/openEuler-release ] ; then
			openeuler_version=`cat /etc/openEuler-release | sed -r 's/.* ([0-9]+)\..*/\1/'`
			if [[ $openeuler_version -lt 20 || $openeuler_version -gt 22 ]] ; then
				echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "当前操作系统版本可能不被支持，脚本退出. . ."
				sleep 0.25
				echo -e "\n"
				exit
			fi
		fi
		if [ -e /etc/hce-release ] ; then
			hce_version=`cat /etc/hce-release | sed -r 's/.* ([0-9]+)\..*/\1/'`
			if [[ $hce_version -lt 2 || $hce_version -gt 2 ]] ; then
				echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "当前操作系统版本可能不被支持，脚本退出. . ."
				sleep 0.25
				echo -e "\n"
				exit
			fi
		fi
		if [ -e /etc/kylin-release ] ; then
			kylin_version=`cat /etc/kylin-release | grep -oE "[V].[^\"]" | sed 's/[^0-9]//g'`
			if [[ $kylin_version -lt 10 || $kylin_version -gt 10 ]] ; then
				echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "当前操作系统版本可能不被支持，脚本退出. . ."
				sleep 0.25
				echo -e "\n"
				exit
			fi
		fi
	else
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "当前操作系统可能不被支持，脚本退出. . ."
		sleep 0.25
		echo -e "\n"
		exit
	fi

	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 $color_C"即将升级Zlib版本至$las_zlib_version，升级OpenSSL版本至$las_openssl_version，升级OpenSSH版本至$las_openssh_version，"$color_0
	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 $color_C"升级过程中请保持活动的连接窗口，切勿中途中断！为避免升级失败无法重连服务器，"$color_0
	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 $color_C"请复制一个连接窗口以备不时之需，或自行配置Telnet服务预留另一个远程连接通道。"$color_0
	echo -en `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 $color_C"升级脚本即将开始，如暂不升级请在倒计时结束前按Ctrl+C终止脚本，倒计时: "$color_0
	count=11
	tput sc
	while true
	do
		if [ $count -ge 1 ] ; then
			let count--
			sleep 1
			tput rc
			tput ed
			echo -en $color_R"$count "$color_0
		else
			break
		fi
	done
	echo -e ""

	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在创建过程目录. . ."
	sleep 0.25

	#创建文件
	mkdir -p $install_files
	mkdir -p $backup_files
	mkdir -p $log_files
	mkdir -p $backup_files/zlib
	mkdir -p $backup_files/ssl
	mkdir -p $backup_files/ssh
	mkdir -p $log_files/yuminstall
	mkdir -p $log_files/zlib
	mkdir -p $log_files/ssl
	mkdir -p $log_files/ssh

	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在关闭SELINUX. . ."
	sleep 0.25

	sed -i 's/^SELINUX=.*$/SELINUX=disabled/' /etc/selinux/config
	setenforce 0 >/dev/null 2>&1

	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在重建yum源缓存. . ."
	sleep 0.25
	
	yum clean all >/dev/null 2>&1
	yum makecache >> $log_files/yuminstall/yummakecache.$date_time.txt 2>&1
	if [ $? -eq 0 ] ; then
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_G"SUCCESS"$color_0 "重建yum源缓存成功"
	else
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "重建yum源缓存失败，脚本退出. . ."
		sleep 0.25
		End_install
		exit
	fi

	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在安装依赖包. . ."
	sleep 1

	for pkg_need_i in $pkg_need ; do
		yum install -y $pkg_need_i --nogpgcheck >> $log_files/yuminstall/yuminstall.$pkg_need_i.$date_time.txt 2>&1
		if [ $? -eq 0 ] ; then
			echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "安装包"$color_C"$pkg_need_i"$color_0"已安装或安装成功"
		else
			echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "安装软件依赖包$pkg_need_i失败，脚本退出. . ."
			sleep 0.25
			End_install
			exit
		fi
	done
}

Install_backup()
{
	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在备份相关文件. . ."
	sleep 0.25

	\cp -rfL /usr/bin/openssl $backup_files/ssl/openssl.$old_openssl_version.$date_time.bak >/dev/null 2>&1
	\cp -rfL /etc/init.d/sshd $backup_files/ssh/sshd.$old_openssh_version.$date_time.bak >/dev/null 2>&1
	\cp -rfL /etc/ssh $backup_files/ssh/ssh.$old_openssh_version.$date_time.bak >/dev/null 2>&1
	\cp -rfL /usr/bin/ssh-copy-id $backup_files/ssh/ssh-copy-id.$old_openssh_version.$date_time.bak >/dev/null 2>&1
	\cp -rfL /usr/lib/systemd/system/sshd.service  $backup_files/ssh/sshd.service.$old_openssh_version.$date_time.bak >/dev/null 2>&1
	\cp -rfL /etc/pam.d/sshd.pam $backup_files/ssh/pam_sshd.pam.$old_openssh_version.$date_time.bak >/dev/null 2>&1
	\cp -rfL /etc/pam.d/sshd $backup_files/ssh/pam_sshd.$old_openssh_version.$date_time.bak >/dev/null 2>&1
}

Install_tar()
{
	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在检查$zlib_version.tar.gz源码包. . ."
	sleep 0.25
	if [ -e $upsslssh_home/$zlib_version.tar.gz ] ; then
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "源码包$zlib_version.tar.gz已存在"
	else
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "未发现$zlib_version.tar.gz源码包，正在从配置的链接中获取. . ."
		sleep 0.25
		cd $upsslssh_home
		wget --no-check-certificate $zlib_url >> $log_files/zlib/zlib_wget.$date_time.txt 2>&1
		if [ $? -eq 0 ] ; then
			echo -e `date +%Y-%m-%d_%H:%M:%S` $color_G"SUCCESS"$color_0 "源码包$zlib_version.tar.gz下载完成"
			sleep 0.25
		else
			echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "源码包$zlib_version.tar.gz下载失败，脚本退出. . ."
			sleep 0.25
			End_install
			exit
		fi
	fi
	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在测试$zlib_version.tar.gz源码包. . ."
	tar -tzf $upsslssh_home/$zlib_version.tar.gz >/dev/null 2>&1
	if [ $? -eq 0 ] ; then
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_G"SUCCESS"$color_0 "源码包$zlib_version.tar.gz测试正常"
		sleep 0.25
	else
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "源码包$zlib_version.tar.gz测试失败，请删除后重新下载，脚本退出. . ."
		sleep 0.25
		End_install
		exit
	fi

	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在检查$openssl_version.tar.gz源码包. . ."
	sleep 0.25

	if [ -e $upsslssh_home/$openssl_version.tar.gz ] ; then
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "源码包$openssl_version.tar.gz已存在"
	else
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "未发现$openssl_version.tar.gz源码包，正在从配置的链接中获取. . ."
		sleep 0.25
		cd $upsslssh_home
		wget --no-check-certificate $openssl_url >> $log_files/ssl/ssl_wget.$date_time.txt 2>&1
		if [ $? -eq 0 ] ; then
			echo -e `date +%Y-%m-%d_%H:%M:%S` $color_G"SUCCESS"$color_0 "源码包$openssl_version.tar.gz下载完成"
			sleep 0.25
		else
			echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "源码包$openssl_version.tar.gz下载失败，脚本退出. . ."
			sleep 0.25
			End_install
			exit 1
		fi
	fi
	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在测试$openssl_version.tar.gz源码包. . ."
	tar -tzf $upsslssh_home/$openssl_version.tar.gz >/dev/null 2>&1
	if [ $? -eq 0 ] ; then
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_G"SUCCESS"$color_0 "源码包$openssl_version.tar.gz测试正常"
		sleep 0.25
	else
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "源码包$openssl_version.tar.gz测试失败，请删除后重新下载，脚本退出. . ."
		sleep 0.25
		End_install
		exit
	fi

	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在检查$openssh_version.tar.gz源码包. . ."
	sleep 0.25

	if [ -e $upsslssh_home/$openssh_version.tar.gz ] ; then
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "源码包$openssh_version.tar.gz已存在"
	else
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "未发现$openssh_version.tar.gz源码包，正在从配置的链接中获取. . ."
		sleep 0.25
		cd $upsslssh_home
		wget --no-check-certificate $openssh_url >> $log_files/ssh/ssh_wget.$date_time.txt 2>&1
		if [ $? -eq 0 ] ; then
			echo -e `date +%Y-%m-%d_%H:%M:%S` $color_G"SUCCESS"$color_0 "源码包$openssh_version.tar.gz下载完成"
			sleep 0.25
		else
			echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "源码包$openssh_version.tar.gz下载失败，脚本退出. . ."
			sleep 0.25
			End_install
			exit
		fi
	fi
	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在测试$openssh_version.tar.gz源码包. . ."
	tar -tzf $upsslssh_home/$openssh_version.tar.gz >/dev/null 2>&1
	if [ $? -eq 0 ] ; then
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_G"SUCCESS"$color_0 "源码包$openssh_version.tar.gz测试正常"
		sleep 0.25
	else
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "源码包$openssh_version.tar.gz测试失败，请删除后重新下载，脚本退出. . ."
		sleep 0.25
		End_install
		exit
	fi
}

Install_zlib()
{
	if [ "$old_zlib_version" == "$las_zlib_version" ] ; then
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "zlib已是最新版本zlib-$old_zlib_version无需升级"
		return
	fi

	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在备份旧zlib版本. . ."
	ls -d /usr/local/zlib-* >/dev/null 2>&1
	if [ $? -eq 0 ] ; then
		old_zlib_dir=$(ls -d /usr/local/zlib-* | tr "\n" " ")
		for old_zlib_dir_i in $old_zlib_dir ; do
			mv $old_zlib_dir_i $backup_files/zlib/ >/dev/null 2>&1
		done
		sleep 0.25
	fi
	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在解压$zlib_version.tar.gz源码包. . ."
	sleep 0.25
	cd $upsslssh_home && mkdir -p $install_files && tar -zxvf $zlib_version.tar.gz -C $install_files >/dev/null 2>&1
	if [ $? -eq 0 ] ; then
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_G"SUCCESS"$color_0 "源码包$zlib_version.tar.gz解压成功"
		sleep 0.25
	else
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "源码包$zlib_version.tar.gz解压失败，脚本退出. . ."
		sleep 0.25
		End_install
		exit
	fi
	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在编译安装$zlib_version. . ."
	cd $install_files/$zlib_version
	./configure --prefix=$install_path/$zlib_version >> $log_files/zlib/zlib_configure.$date_time.txt 2>&1
	if [ $? -eq 0 ] ; then
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在编译安装$zlib_version --> make clean. . ."
		make clean >/dev/null 2>&1
		if [ $? -ne 0 ] ; then
			echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "编译安装$zlib_version失败，脚本退出. . ."
			sleep 0.25
			End_install
			exit
		fi
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在编译安装$zlib_version --> make. . ."
		make >> $log_files/zlib/zlib_make.$date_time.txt 2>&1
		if [ $? -ne 0 ] ; then
			echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "编译安装$zlib_version失败，脚本退出. . ."
			sleep 0.25
			End_install
			exit
		fi
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在编译安装$zlib_version --> make install. . ."
		make install >> $log_files/zlib/zlib_makeinsall.$date_time.txt 2>&1
		if [ $? -ne 0 ] ; then
			echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "编译安装$zlib_version失败，脚本退出. . ."
			sleep 0.25
			End_install
			exit
		fi
	else
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "编译安装$zlib_version失败，脚本退出. . ."
		sleep 0.25
		End_install
		exit
	fi

	if [ -e $install_path/$zlib_version/lib/libz.so ] ; then
		grep -v "^#" /etc/ld.so.conf | grep 'zlib' >/dev/null 2>&1
		if [ $? -eq 0 ] ; then
			echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在注释/etc/ld.so.conf旧配置信息. . ."
			sed -i "/zlib/ s/^\(.*\)$/#\1/g" /etc/ld.so.conf
		fi
		grep -v "^#" /etc/ld.so.conf.d/zlib.conf 2>&1 | grep 'zlib' >/dev/null 2>&1
		if [ $? -eq 0 ] ; then
			sed -i "/zlib/ s/^\(.*\)$/#\1/g" /etc/ld.so.conf.d/zlib.conf >/dev/null 2>&1
		fi
	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在更新/etc/ld.so.conf配置信息. . ."
	echo "$install_path/$zlib_version/lib" >> /etc/ld.so.conf
	rm -rf /etc/ld.so.cache
	ldconfig -v >> $log_files/zlib/zlib_ldconfig.$date_time.txt 2>&1
	ldconfig
	fi

	new_zlib_version=$(ldconfig -v 2>/dev/null | grep -E "zlib" | awk -F "-" '{print $2'} | awk -F "/lib" '{print $1}')

	if [ "$new_zlib_version" == "$las_zlib_version" ] ; then
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_G"SUCCESS"$color_0 "$zlib_version升级成功"
		sleep 0.25
	else
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "$zlib_version升级失败，脚本退出. . ."
		sleep 0.25
		End_install
		exit
	fi
}

Install_openssl()
{
	if [ "$old_openssl_version" == "$las_openssl_version" ] ; then
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "openssl已是最新版本openssl-$old_openssl_version无需升级"
		openssl_update=no
		return
	fi
	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在解压$openssl_version.tar.gz源码包. . ."
	sleep 0.25
	cd $upsslssh_home  &&  tar -zxvf $openssl_version.tar.gz -C $install_files >/dev/null 2>&1
	if [ $? -eq 0 ] ; then
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_G"SUCCESS"$color_0 "源码包$openssl_version.tar.gz解压成功"
		sleep 0.25
	else
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "源码包$openssl_version.tar.gz解压失败，脚本退出. . ."
		sleep 0.25
		End_install
		exit
	fi

	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在编译安装$openssl_version. . ."
	cd $install_files/$openssl_version
	./config shared zlib --prefix=$install_path/$openssl_version >> $log_files/ssl/ssl_config.$date_time.txt 2>&1
	if [ $? -eq 0 ] ; then
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在编译安装$openssl_version --> make clean. . ."
		make clean >/dev/null 2>&1
		if [ $? -ne 0 ] ; then
			echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "编译安装$openssl_version失败，脚本退出. . ."
			sleep 0.25
			End_install
			exit
		fi
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在编译安装$openssl_version --> make -j 4. . ."
		make -j 4 >> $log_files/ssl/ssl_make.$date_time.txt 2>&1
		if [ $? -ne 0 ] ; then
			echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "编译安装$openssl_version失败，脚本退出. . ."
			sleep 0.25
			End_install
			exit
		fi
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在编译安装$openssl_version --> make install. . ."
		make install >> $log_files/ssl/ssl_makeinstall.$date_time.txt 2>&1
		if [ $? -ne 0 ] ; then
			echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "编译安装$openssl_version失败，脚本退出. . ."
			sleep 0.25
			End_install
			exit
		fi
	else
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "编译安装$openssl_version失败，脚本退出. . ."
		sleep 0.25
		End_install
		exit
	fi

	if [ -e $install_path/$openssl_version/bin/openssl ] ; then
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在复制openssl执行文件. . ."
		sleep 0.25
		\cp -rfL /usr/bin/openssl $backup_files/ssl/usr_bin_openssl.$old_openssl_version.$date_time.bak >/dev/null 2>&1
		rm -rf /usr/bin/openssl >/dev/null 2>&1
		\cp -rfL $install_path/$openssl_version/bin/openssl /usr/bin/openssl
		chmod 755 /usr/bin/openssl
		if [ -e /usr/local/bin/openssl ] ; then
			\cp -rfL /usr/local/bin/openssl $backup_files/ssl/usr_local_bin_openssl.$old_openssl_version.$date_time.bak >/dev/null 2>&1
			rm -rf /usr/local/bin/openssl >/dev/null 2>&1
			\cp -rfL $install_path/$openssl_version/bin/openssl /usr/local/bin/openssl
			chmod 755 /usr/local/bin/openssl
		fi
		\cp -rfL $install_path/$openssl_version/lib/libssl.so.1.1 /usr/lib64/libssl.so.${openssl_version:8}
		chmod 755 /usr/lib64/libssl.so.${openssl_version:8}
		\cp -rfL $install_path/$openssl_version/lib/libcrypto.so.1.1 /usr/lib64/libcrypto.so.${openssl_version:8}
		chmod 755 /usr/lib64/libcrypto.so.${openssl_version:8}
		cd /usr/lib64
		rm -rf libssl.so
		ln -s libssl.so.${openssl_version:8} libssl.so
		rm -rf libcrypto.so
		ln -s libcrypto.so.${openssl_version:8} libcrypto.so
		cd
		if [[ -e /usr/local/lib64/libcrypto.so ]] || [[ -e /usr/local/lib64/libssl.so ]] ; then
			cd /usr/local/lib64/
			\cp -rfL libssl.so.1.1 $backup_files/ssl/usr_local_lib64_libssl.so.1.1.$date_time.bak >/dev/null 2>&1
			\cp -rfL libssl.so $backup_files/ssl/usr_local_lib64_libssl.so.$date_time.bak >/dev/null 2>&1
			\cp -rfL libcrypto.so.1.1 $backup_files/ssl/usr_local_lib64_libcrypto.so.1.1.$date_time.bak >/dev/null 2>&1
			\cp -rfL libcrypto.so $backup_files/ssl/usr_local_lib64_libcrypto.so.$date_time.bak >/dev/null 2>&1
			rm -rf libssl.so >/dev/null 2>&1
			rm -rf libssl.so.1.1 >/dev/null 2>&1
			rm -rf libcrypto.so >/dev/null 2>&1
			rm -rf libcrypto.so.1.1 >/dev/null 2>&1
			cd
		fi
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在注释/etc/ld.so.conf旧配置信息. . ."
		grep -v "^#" /etc/ld.so.conf | grep 'openssl' >/dev/null 2>&1
		if [ $? -eq 0 ];then
			sed -i "/openssl/ s/^\(.*\)$/#\1/g" /etc/ld.so.conf >/dev/null 2>&1
		fi
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在更新/etc/ld.so.conf配置信息. . ."
		#echo -e "/usr/lib64" >> /etc/ld.so.conf
		#echo -e "$install_path/$openssl_version/lib/" >> /etc/ld.so.conf
		rm -rf /etc/ld.so.cache
		ldconfig -v >> $log_files/ssl/ssl_ldconfig.$date_time.txt 2>&1
		ldconfig
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_G"SUCCESS"$color_0 "编译安装$openssl_version成功"
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在输出openssl版本信息. . ."
		sleep 0.25
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 $color_C"`openssl version`"$color_0
		sleep 0.25
	else
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "复制openssl执行文件失败，脚本退出. . ."
		sleep 0.25
		End_install
		exit
	fi

	new_openssl_version=$(openssl version 2>&1 | awk -F" " '{print $2}' | awk -F"-" '{print $1}')
	if [ "$new_openssl_version" == "$las_openssl_version" ] ; then
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_G"SUCCESS"$color_0 "$openssl_version升级成功"
		sleep 0.25
	else
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "$openssl_version升级失败，脚本退出. . ."
		sleep 0.25
		End_install
		exit
	fi
}

Remove_openssh()
{
	if [ "$old_openssh_version" == "$las_openssh_version" ] ; then
		return
	fi
	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在卸载openssh旧版本. . ."
	sleep 0.25
	rpm -e --nodeps openssh-$old_openssh_version >/dev/null 2>&1
	rpm -e --nodeps openssh-server-$old_openssh_version >/dev/null 2>&1
	rpm -e --nodeps openssh-clients-$old_openssh_version >/dev/null 2>&1
}

Install_openssh()
{
	if [ "$old_openssh_version" == "$las_openssh_version" ] ; then
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "openssh已是最新版本openssh-$old_openssh_version无需升级"
		return
	fi
	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在解压$openssh_version.tar.gz源码包. . ."
	sleep 0.25
	cd $upsslssh_home && tar -zxvf $openssh_version.tar.gz -C $install_files >/dev/null 2>&1
	if [ $? -eq 0 ] ; then
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_G"SUCCESS"$color_0 "源码包$openssh_version.tar.gz解压成功"
		sleep 0.25
	else
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "源码包$openssh_version.tar.gz解压失败，脚本退出. . ."
		sleep 0.25
		End_install
		exit
	fi
	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在编译安装$openssh_version. . ."
	rm -rf /etc/ssh >/dev/null 2>&1
	cd $install_files/$openssh_version
	./configure --prefix=$install_path/$openssh_version --sysconfdir=/etc/ssh --with-ssl-dir=$install_path/$openssl_version --with-zlib=$install_path/$zlib_version --without-zlib-version-check --without-openssl-header-check --with-md5-passwords --with-pam >> $log_files/ssh/ssh_configure.$date_time.txt 2>&1
	if [ $? -eq 0 ] ; then
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在编译安装$openssh_version --> make clean. . ."
		make clean >/dev/null 2>&1
		if [ $? -ne 0 ] ; then
			echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "编译安装$openssh_version失败，脚本退出. . ."
			sleep 0.25
			End_install
			exit
		fi
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在编译安装$openssh_version --> make -j 4. . ."
		make -j 4 >> $log_files/ssh/ssh_make.$date_time.txt >/dev/null 2>&1
		if [ $? -ne 0 ] ; then
			echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "编译安装$openssh_version失败，脚本退出. . ."
			sleep 0.25
			End_install
			exit
		fi
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在编译安装$openssh_version --> make install. . ."
		make install >> $log_files/ssh/ssh_makeinstall.$date_time.txt 2>&1
		if [ $? -ne 0 ] ; then
			echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "编译安装$openssh_version失败，脚本退出. . ."
			sleep 0.25
			End_install
			exit
		fi
	else
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "编译安装$openssh_version失败，脚本退出. . ."
		sleep 0.25
		End_install
		exit
	fi

	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_G"SUCCESS"$color_0 "编译安装$openssh_version成功"
	sleep 0.25
	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在迁移openssh配置文件. . ."
	sleep 0.25

	rm -rf /usr/lib/systemd/system/sshd.service >/dev/null 2>&1

	rm -rf /etc/init.d/sshd >/dev/null 2>&1
	\cp -rfL $install_files/$openssh_version/contrib/redhat/sshd.init /etc/init.d/sshd >/dev/null 2>&1
	chmod u+x /etc/init.d/sshd >/dev/null 2>&1

	rm -rf /etc/pam.d/sshd.pam >/dev/null 2>&1
	\cp -rfL $install_files/$openssh_version/contrib/redhat/sshd.pam /etc/pam.d/sshd.pam >/dev/null 2>&1

	\cp -rfL /usr/libexec/openssh/sftp-server $backup_files/ssh/libexec_openssh_sftp-server.$date_time.bak >/dev/null 2>&1
	rm -rf /usr/libexec/openssh/sftp-server >/dev/null 2>&1
	\cp -rfL $install_path/$openssh_version/libexec/sftp-server /usr/libexec/openssh/sftp-server >/dev/null 2>&1
	chmod 755 /usr/libexec/openssh/sftp-server >/dev/null 2>&1
	\cp -rfL /usr/libexec/sftp-server $backup_files/ssh/libexec_sftp-server.$date_time.bak >/dev/null 2>&1
	rm -rf /usr/libexec/sftp-server >/dev/null 2>&1
	\cp -rfL $install_path/$openssh_version/libexec/sftp-server /usr/libexec/sftp-server >/dev/null 2>&1
	chmod 755 /usr/libexec/sftp-server >/dev/null 2>&1

	\cp -rfL $install_path/$openssh_version/sbin/sshd /usr/sbin/sshd >/dev/null 2>&1
	chmod 755 /usr/sbin/sshd >/dev/null 2>&1
	\cp -rfL $install_path/$openssh_version/bin/scp /usr/bin/scp >/dev/null 2>&1
	chmod 755 /usr/bin/scp >/dev/null 2>&1
	\cp -rfL $install_path/$openssh_version/bin/sftp /usr/bin/sftp >/dev/null 2>&1
	chmod 755 /usr/bin/sftp >/dev/null 2>&1
	\cp -rfL $install_path/$openssh_version/bin/ssh /usr/bin/ssh >/dev/null 2>&1
	chmod 755 /usr/bin/ssh >/dev/null 2>&1
	\cp -rfL $install_path/$openssh_version/bin/ssh-add /usr/bin/ssh-add >/dev/null 2>&1
	chmod 755 /usr/bin/ssh-add >/dev/null 2>&1
	\cp -rfL $install_path/$openssh_version/bin/ssh-agent /usr/bin/ssh-agent >/dev/null 2>&1
	chmod 755 /usr/bin/ssh-agent >/dev/null 2>&1
	\cp -rfL $install_path/$openssh_version/bin/ssh-keygen /usr/bin/ssh-keygen >/dev/null 2>&1
	chmod 755 /usr/bin/ssh-keygen >/dev/null 2>&1
	\cp -rfL $install_path/$openssh_version/bin/ssh-keyscan /usr/bin/ssh-keyscan >/dev/null 2>&1
	chmod 755 /usr/bin/ssh-keyscan >/dev/null 2>&1
	\cp -rfL $backup_files/ssh/ssh-copy-id.$old_openssh_version.$date_time.bak /usr/bin/ssh-copy-id >/dev/null 2>&1
	chmod 755 /usr/bin/ssh-copy-id >/dev/null 2>&1

	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在配置openssh服务及开机自启. . ."
	sleep 0.25
	chkconfig --add sshd >/dev/null 2>&1
	chkconfig sshd on >/dev/null 2>&1
	chkconfig --list > $backup_files/ssh/sshservice.txt 2>&1
	if [ $? -eq 0 ] ; then
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_G"SUCCESS"$color_0 "配置openssh服务及开机自启成功"
		sleep 0.25
	else
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "配置openssh服务及开机自启失败，脚本退出. . ."
		sleep 0.25
		End_install
		exit
	fi
	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在修改openssh配置文件. . ."
	sleep 0.25
	if [ -e $backup_files/ssh/ssh.$old_openssh_version.$date_time.bak/sshd_config ] ; then
		\cp -rfL $backup_files/ssh/ssh.$old_openssh_version.$date_time.bak/sshd_config /etc/ssh/sshd_config >/dev/null 2>&1
	else
		if [ ! -e /etc/ssh/sshd_config ] ; then
			\cp -rfL $install_files/$openssh_version/sshd_config /etc/ssh/sshd_config >/dev/null 2>&1
		fi
	fi
	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在修改openssh配置文件 --> 为确保登陆正常，配置文件将被修改为"$color_R"允许root登陆"$color_0". . ."
	sleep 0.25
	grep -E "^#PasswordAuthentication|^\s*PasswordAuthentication" /etc/ssh/sshd_config >/dev/null 2>&1
	if [ $? -eq 0 ] ; then
		sed -i "/^\s*PasswordAuthentication/ s/^\s*//" /etc/ssh/sshd_config
		sed -i "/^\s*PasswordAuthentication/ s/^\(.*\)$/#\1/g" /etc/ssh/sshd_config
		sed -i "0,/^#PasswordAuthentication.*/s/^#PasswordAuthentication.*/PasswordAuthentication yes/" /etc/ssh/sshd_config
	else
		echo -e "\nPasswordAuthentication yes" >> /etc/ssh/sshd_config
	fi
	grep -E "^#PermitRootLogin|^\s*PermitRootLogin" /etc/ssh/sshd_config >/dev/null 2>&1
	if [ $? -eq 0 ] ; then
		sed -i "/^\s*PermitRootLogin/ s/^\s*//" /etc/ssh/sshd_config
		sed -i "/^\s*PermitRootLogin/ s/^\(.*\)$/#\1/g" /etc/ssh/sshd_config
		sed -i "0,/^#PermitRootLogin.*/s/^#PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config
	else
		echo -e "\nPermitRootLogin yes" >> /etc/ssh/sshd_config
	fi
	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在修改openssh配置文件 --> 优化配置以符合最低信息安全要求"$color_0". . ."
	grep -E "^\s*Subsystem" /etc/ssh/sshd_config >/dev/null 2>&1
	if [ $? -eq 0 ] ; then
		sed -i "/^\s*Subsystem/ s/^\s*//" /etc/ssh/sshd_config
		sed -i "0,/^Subsystem.*/s/^Subsystem.*/Subsystem sftp internal-sftp -l INFO -f AUTH/" /etc/ssh/sshd_config
	fi
	grep -E "^#UsePAM|^\s*UsePAM" /etc/ssh/sshd_config >/dev/null 2>&1
	if [ $? -eq 0 ] ; then
		sed -i "/^\s*UsePAM/ s/^\s*//" /etc/ssh/sshd_config
		sed -i "/^\s*UsePAM/ s/^\(.*\)$/#\1/g" /etc/ssh/sshd_config
		sed -i "0,/^#UsePAM.*/s/^#UsePAM.*/UsePAM yes/" /etc/ssh/sshd_config
	else
		echo -e "\nUsePAM yes" >> /etc/ssh/sshd_config
	fi
	if [ `expr $las_openssh_version_2 \> 8.7` -ne 0 ] ; then
		grep -E "^\s*HostkeyAlgorithms.*\+ssh-dss.*" /etc/ssh/sshd_config >/dev/null 2>&1
		if [ $? -eq 0 ] ; then
			HostkeyAlgorithms=$(grep -E "^\s*HostkeyAlgorithms.*\+ssh-dss.*" /etc/ssh/sshd_config)
			HostkeyAlgorithms2=$(echo ${HostkeyAlgorithms/\ssh-dss,/})
			sed -i "/^HostkeyAlgorithms.*/s/^HostkeyAlgorithms.*/$HostkeyAlgorithms2/" /etc/ssh/sshd_config
		fi
		grep -E "^\s*PubkeyAcceptedKeyTypes.*\+ssh-dss.*" /etc/ssh/sshd_config >/dev/null 2>&1
		if [ $? -eq 0 ] ; then
			PubkeyAcceptedKeyTypes=$(grep -E "^\s*PubkeyAcceptedKeyTypes.*\+ssh-dss.*" /etc/ssh/sshd_config)
			PubkeyAcceptedKeyTypes2=$(echo ${PubkeyAcceptedKeyTypes/\ssh-dss,/})
			sed -i "/^PubkeyAcceptedKeyTypes.*/s/^PubkeyAcceptedKeyTypes.*/$PubkeyAcceptedKeyTypes2/" /etc/ssh/sshd_config
		fi
	fi
	if [ ! -e "/etc/pam.d/sshd" ] ; then
		if [ -e "$backup_files/ssh/pam_sshd.$old_openssh_version.$date_time.bak" ] ; then
			echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在恢复/etc/pam.d/sshd文件. . ."
			\cp -rfL $backup_files/ssh/pam_sshd.$old_openssh_version.$date_time.bak /etc/pam.d/sshd >/dev/null 2>&1
		else
			echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在创建/etc/pam.d/sshd文件. . ."
			if [[ $redhat_version -gt 4 && $redhat_version -lt 7 ]] ; then
				cat > /etc/pam.d/sshd << EOF
#%PAM-1.0
auth       required     pam_sepermit.so
auth       include      password-auth
account    required     pam_nologin.so
account    include      password-auth
password   include      password-auth
### pam_selinux.so close should be the first session rule
session    required     pam_selinux.so close
session    required     pam_loginuid.so
### pam_selinux.so open should only be followed by sessions to be executed in the user context
session    required     pam_selinux.so open env_params
session    optional     pam_keyinit.so force revoke
session    include      password-auth
EOF
			fi

			if [[ $redhat_version -gt 6 ]] || [[ $openeuler_version -gt 19 ]] || [[ $hce_version -gt 1 ]] || [[ $kylin_version -gt 9 ]] ; then
				cat > /etc/pam.d/sshd << EOF
#%PAM-1.0
auth       required     pam_sepermit.so
auth       substack     password-auth
auth       include      postlogin
# Used with polkit to reauthorize users in remote sessions
-auth      optional     pam_reauthorize.so prepare
account    required     pam_nologin.so
account    include      password-auth
password   include      password-auth
# pam_selinux.so close should be the first session rule
session    required     pam_selinux.so close
session    required     pam_loginuid.so
# pam_selinux.so open should only be followed by sessions to be executed in the user context
session    required     pam_selinux.so open env_params
session    required     pam_namespace.so
session    optional     pam_keyinit.so force revoke
session    include      password-auth
session    include      postlogin
# Used with polkit to reauthorize users in remote sessions
-session   optional     pam_reauthorize.so prepare
EOF
			fi
		fi
	sleep 0.25
	fi

	sshdbadconfig=`sshd -T 2>&1 | grep -E "^/etc/.*line.*option" | wc -l`
	if [ $sshdbadconfig -ne 0 ] ; then
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在修复openssh失效的配置. . ."
		sshd -T >> $log_files/ssh/sshd_information.$date_time.txt 2>&1
		service sshd status >> $log_files/ssh/sshd_service.$date_time.txt 2>&1
		sshd -T 2>&1 | grep -E "^/etc/.*Unsupported option" | awk -F' ' '($5=="option"){print $6}' | sed -e 's/\r$//' | tr "\n" " " | sed -e 's/,$/\n/' > /tmp/sshdconfig
		sshd -T 2>&1 | grep -E "^/etc/.*Deprecated option" | awk -F' ' '($5=="option"){print $6}' | sed -e 's/\r$//' | tr "\n" " " | sed -e 's/,$/\n/' >> /tmp/sshdconfig
		sshd -T 2>&1 | grep -E "^/etc/.*Bad configuration option" | awk -F' ' '($6=="option:"){print $7}' | sed -e 's/\r$//' | tr "\n" " " | sed -e 's/,$/\n/' >> /tmp/sshdconfig
		sleep 0.25
		for sshdconfig in $(cat /tmp/sshdconfig); do
			sed -i "/^\s*$sshdconfig/ s/^\(.*\)$/#\1/g" /etc/ssh/sshd_config
			echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在注释openssh失效的配置"$color_C"$sshdconfig"$color_0". . ."
			sleep 0.25
		done
		rm -rf /tmp/sshdconfig
	fi

	echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在重新加载系统服务配置文件. . ."
    if [[ $redhat_version -gt 4 && $redhat_version -lt 7 ]] ; then
        chkconfig daemon-reload
    fi
    if [[ $redhat_version -gt 6 ]] || [[ $openeuler_version -gt 19 ]] || [[ $hce_version -gt 1 ]] || [[ $kylin_version -gt 9 ]] ; then
        systemctl daemon-reload
    fi
    sleep 0.25

    echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在重启openssh服务. . ."
	service sshd start >> $log_files/ssh/sshd_service.$date_time.txt 2>&1 && service sshd restart >> $log_files/ssh/sshd_service.$date_time.txt 2>&1
	if [ $? -ne 0 ] ; then
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "启动openssh服务失败，脚本退出. . ."
		sshd -T >> $log_files/ssh/sshd_information.$date_time.txt 2>&1
		service sshd status >> $log_files/ssh/sshd_service.$date_time.txt 2>&1
		sleep 0.25
		End_install
		exit
	else
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_G"SUCCESS"$color_0 "启动openssh服务成功"
		sleep 0.25
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在输出openssh版本信息. . ."
		sleep 0.25
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 $color_C"`ssh -V 2>&1`"$color_0
	fi
	sleep 0.25

	new_openssh_version=$(ssh -V 2>&1 | awk -F"," '{print $1}' | awk -F"_" '{print $2}')

	if [ "$new_openssh_version" == "$las_openssh_version" ] ; then
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_G"SUCCESS"$color_0 "$openssh_version升级成功"
		sleep 0.25
	else
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "$openssh_version升级失败，脚本退出. . ."
		sleep 0.25
		End_install
		exit
	fi
}

RHEL8_repair()
{
	if [[ "$openssl_update" == "no"  ]] ; then
		return
	fi
	if [[ $redhat_version -gt 7 && $redhat_version -lt 9 ]] || [[ $openeuler_version -gt 19 && $openeuler_version -lt 23 ]] || [[ $hce_version -gt 1 && $hce_version -lt 3 ]] || [[ $kylin_version -gt 9 && $kylin_version -lt 11 ]] ; then
		echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在将RHEL8系列操作系统恢复openssl相关库文件为旧库. . ."
		sleep 0.25
		if [ $os_openssl_version ] ; then
			old_openssl_version="$os_openssl_version"
		fi
		if [ -e /usr/lib64/libssl.so.$old_openssl_version ] ; then
			echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在恢复旧库openssl软链接. . ."
			sleep 0.25
			cd /usr/lib64
			rm -rf libssl.so.${openssl_version:8}
			rm -rf libcrypto.so.${openssl_version:8}
			rm -rf libssl.so.1.1
			ln -s libssl.so.$old_openssl_version libssl.so.1.1 >/dev/null 2>&1
			rm -rf libssl.so
			ln -s libssl.so.$old_openssl_version libssl.so
			rm -rf libcrypto.so.1.1
			ln -s libcrypto.so.$old_openssl_version libcrypto.so.1.1 >/dev/null 2>&1
			rm -rf libcrypto.so
			ln -s libcrypto.so.$old_openssl_version libcrypto.so
			cd
			rm -rf /etc/ld.so.cache
			ldconfig -v >> $log_files/ssl/ssl_ldconfig.$date_time.txt 2>&1
			ldconfig
			echo -e `date +%Y-%m-%d_%H:%M:%S` $color_G"SUCCESS"$color_0 "恢复openssl旧库文件成功"
			sleep 0.25
			echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "正在输出openssl版本信息. . ."
			sleep 0.25
			echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 $color_C"`openssl version`"$color_0
			echo -e `date +%Y-%m-%d_%H:%M:%S` $color_Y"INFO"$color_0 "恢复旧库的openssl会出现主版本号与库版本号不一致问题"
			sleep 0.25
		else
			echo -e `date +%Y-%m-%d_%H:%M:%S` $color_R"ERROR"$color_0 "恢复openssl旧库文件失败，脚本退出. . ."
			sleep 0.25
			End_install
			exit
		fi
	fi
}

End_install()
{
	chown `logname`.`logname` $upsslssh_home/ -R >/dev/null 2>&1
	find $upsslssh_home -type f -exec chmod 644 {} \; >/dev/null 2>&1
	find $upsslssh_home -type d -exec chmod 755 {} \; >/dev/null 2>&1
	#rm -rf $upsslssh_home/*$zlib_version.tar.gz >/dev/null 2>&1
	#rm -rf $upsslssh_home/*$openssl_version.tar.gz >/dev/null 2>&1
	#rm -rf $upsslssh_home/*$openssh_version.tar.gz >/dev/null 2>&1
	#rm -rf $install_files >/dev/null 2>&1

	echo -e "\n"
	echo -e $color_G"======================== install file ========================"$color_0
	echo -e ""
	echo -e "升级安装目录请前往: "
	cd  $install_files && pwd
	cd ~
	echo -e ""
	echo -e "升级备份目录请前往: " 
	cd  $backup_files && pwd
	cd ~
	echo -e ""
	echo -e "升级日志目录请前往: "
	cd  $log_files && pwd
	cd ~
	echo -e ""
	echo -e $color_G"=============================================================="$color_0
	echo -e "\n"
	IFS=$OLD_IFS
	sleep 1
}

Install_make
Install_backup
Install_tar
Install_zlib
Install_openssl
Remove_openssh
Install_openssh
RHEL8_repair
End_install
