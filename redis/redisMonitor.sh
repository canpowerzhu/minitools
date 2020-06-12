#!/bin/bash
#PATH=/etc:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

#定义当前主机内网IP
intervalIp=`ip addr |grep inet|grep eth0 |awk '{print $2}'|awk -F/ '{print $1}'`

function dingAlarm(){
	curl 'https://oapi.dingtalk.com/robot/send?access_token=18c7b2326317cc32b76a62f4ba5b27bff72cc8f326025dcaeb21352b9360fb7d' -H 'Content-Type: application/json' -d $1
}

function alarmBody(){
	msg='domino项目 这个节点内存告急，主机名称是'$1'，内存最大可用：40G，目前占用'$2';占用率为'$3'%'
	jsonData='{"msgtype":"text","text":{"content":"'$mgs'"},}'
	dingAlarm $jsonData
}

function getNodeMem(){
	nodeIP=`echo $1|awk -F: '{print $1}'`
	nodePort=`echo $1|awk -F: '{print $2}'`
	usedMem=`redis-cli -c -h $nodeIP -p $nodePort  info memory|grep used_memory_rss: |awk -F: '{print $2}'| sed  's/\r//'`
	usedMemHuman=`redis-cli -c -h $nodeIP -p $nodePort  info memory|grep used_memory_rss_human |awk -F: '{print $2}'|sed  's/\r//'`
	maxMem=`redis-cli -c -h $nodeIP  -p $nodePort  info memory|grep maxmemory: |awk -F: '{print $2}'|sed  's/\r//'`
	maxMemHuman=`redis-cli -c -h $nodeIP -p $nodePort info memory|grep maxmemory_human |awk -F: '{print $2}'|sed  's/\r//'`
	memFragRatio=`redis-cli -c -h $nodeIP -p $nodePort  info memory|grep mem_fragmentation_ratio |awk -F: '{print $2}'|sed  's/\r//'`
	memRate=`awk 'BEGIN{printf "%.2f%%\n",('$usedMem'/'$maxMem')*100}'` 
	nodeRole=`redis-cli -c -h $nodeIP -p $nodePort info Replication |grep role |awk -F: '{print $2}'|sed 's/\r//'`
	nodeSlave=`redis-cli -c -h $nodeIP -p $nodePort info Replication |grep slave0 |awk -F, '{print $1 $2}'|awk -F: '{print $2}'`
	if [ "$nodeRole" == "master" ];then

	    msg='节点:'$1' 节点角色:'$nodeRole' 从节点为:'$nodeSlave' 内存使用:'$usedMemHuman' 最大内存:'$maxMemHuman' 内存碎片率:'$memFragRatio' 内存使用率:'$memRate
	    echo $msg
	fi
}
node=`redis-cli -c -h $intervalIp -p 13013 cluster nodes|awk '{print $2}' `
nodeList=`echo $node | sed "s/ /,/g"`
OLD_IFS="$IFS"
IFS=","
nodeArr=($nodeList)
IFS="OLD_IFS"
for node in ${nodeArr[@]}
    do
	getNodeMem $node
    done
