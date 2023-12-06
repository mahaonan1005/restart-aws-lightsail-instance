#!/bin/bash

# 定义一个函数来检查命令的执行状态
check_status() {
  if [ $? -ne 0 ]; then
    echo "Error: $1 failed."
    exit 1
  fi
}

# 获取所有静态 IP 地址并解除实例关联
aws lightsail get-static-ips --query 'staticIps[*].[name]' --output text | while read -r ip_name
do
  # 获取与静态 IP 关联的实例
  instance=$(aws lightsail get-static-ip --static-ip-name "$ip_name" --query 'staticIp.attachedTo' --output text)
  check_status "Fetching static IP info for $ip_name"

  # 如果 IP 已关联，则解除关联
  if [ "$instance" != "None" ]; then
    echo "Detaching $ip_name from $instance..."
    aws lightsail detach-static-ip --static-ip-name "$ip_name"
    check_status "Detaching $ip_name"
  fi

  # 删除静态 IP
  echo "Deleting $ip_name..."
  aws lightsail release-static-ip --static-ip-name "$ip_name"
  check_status "Deleting $ip_name"
done

# 等待操作完成
sleep 5s

# 获取所有实例名称
instance_names=$(aws lightsail get-instances | jq -r '.instances[] | .name')
check_status "Fetching instance names"

# 停止实例
echo "$instance_names" | xargs --no-run-if-empty -P 4 -I {} bash -c '{
  echo "Stopping instance {}..."
  aws lightsail stop-instance --instance-name {} && echo "Stopped instance {}"
}'

# 等待实例完全停止
sleep 70s

# 启动实例
echo "$instance_names" | xargs --no-run-if-empty -P 4 -I {} bash -c '{
  echo "Starting instance {}..."
  aws lightsail start-instance --instance-name {} && echo "Started instance {}"
}'

# 等待实例启动
sleep 45s

# 显示实例名称和公共 IP 地址
aws lightsail get-instances --query "instances[*].[name, publicIpAddress]" --output json | jq -r '.[] | @tsv' | sort
