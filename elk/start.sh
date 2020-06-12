#!/bin/bash
baseDir='/application/docker-data'
curPath=$(dirname $(readlink -f "$0"))
intervalIP=`ip addr |grep inet|grep eth0 |awk '{print $2}'|awk -F/ '{print $1}'`
colorRed(){
echo -e "\033[31m========== $1 ========== \033[0m"
}

colorYellow(){
echo -e "\033[34m========== $1  ==========\033[0m"
}

colorGreen(){
echo -e "\033[32m========== $1  ==========\033[0m"
}

colorPurper(){
echo -e "\033[35m========== $1  ==========\033[0m"
}

checkDir(){
if [ ! -d $1 ];then
	colorRed "基础目录不存在，即将创建"
	mkdir -p $1
else
	colorPurper "此目录已经存在"
fi
}

checkConfig(){
if [ ! -f $1 ];then
	colorRed "配置文件不存在，请确认后执行"
	exit 0
else
	colorGreen "配置文件正常,复制中"
	cp $1 $2
fi	
}

esCluster(){
	esNode=("es/node1" "es/node2" "es/node3")
	for i in ${esNode[@]};do
		colorGreen "检查elasticsearch节点 ====== $i 目录"
	  	checkDir $baseDir/$i

		esDir=("logs" "data" "config")
			for j in ${esDir[@]};do
			colorGreen "检查elasticsearch之$1节点 ====== $j 目录"
			  checkDir $baseDir/$i/$j
			  chmod 777 $baseDir/$i/$j
			  if [ $j == "config" ];then
			    configFile=`echo $i |sed  's/\//-/g'`
			   checkConfig $curPath/$configFile'.yml' $baseDir/$i/$j/elasticsearch.yml
			   sed -i "s/intervalIP/$intervalIP/g" $baseDir/$i/$j/elasticsearch.yml
		          fi
  			done
  	done
	
}
preCheck(){
	colorGreen "检查基础目录"
	checkDir $baseDir
	
	colorGreen "检查nginx目录"
	checkDir $baseDir/openresty/conf.d/
	checkDir $baseDir/openresty/logs
 	checkConfig $curPath/nginx.conf $baseDir/openresty/conf.d/nginx.conf

	colorGreen "检查kibana目录"
	checkDir $baseDir/kibana/
	checkConfig $curPath/kibana.yml $baseDir/kibana/kibana.yml

	esCluster	
}

centOs8(){
	osType=`cat /etc/os-release |grep ^NAME= |awk  '{print $1}' |awk -F\" '{print $2}'`
	osVersion=`cat /etc/os-release |grep ^VERSION= |tr -cd "[0-9]"`
	if [[ $osType == "CentOS" ]] && [[ $osVersion == '8' ]];then
		colorGreen "系统为centos 8"
	else
		colorRed "此脚本仅适用于centos 8"
		exit 0
	fi
}
startElk(){
	colorGreen "初始化环境检查"
        centOs8
	preCheck
	checkNet=`docker network ls |awk '{print $2}' |grep elk`

	if [ ! -n "$checkNet" ];then
		colorRed "el网络不存在，即将创建"
		docker network create elk
	else
		colorGreen "elk网络已存在"
	fi
       docker-compose -f $curPath/elasticsearch-kibana.yml --env-file $curPath/env up -d
	}
startElk
