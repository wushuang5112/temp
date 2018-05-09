#!/usr/bin/env bash

source /etc/profile

# 安装系统级组件库
yum install lsscsi pciutils parted smartmontools dmidecode iproute -y
yum install redhat-lsb-core -y
yum install libselinux-python -y
yum install wget -y

CURRENTPATH=$(pwd)
TEMPLATE_CACHE_PATH=/tmp/cmdb_install/

# 判断当前操作用户
if [ ${USER} != "root" ]
  then
    echo "Current User Is Not root, Please sudo su - root."
    exit 1
fi

# 缓存目录
if [ ! -d ${TEMPLATE_CACHE_PATH} ]
  then
  mkdir -p ${TEMPLATE_CACHE_PATH}
fi
cd ${TEMPLATE_CACHE_PATH}

# 系统版本
OS_VERSION=`cat /etc/redhat-release | grep -o '[0-9\.]\+'`
OS_MAJOR_VERSION=`echo ${OS_VERSION:0:1}`
if [ ${OS_MAJOR_VERSION} != "6" -a ${OS_MAJOR_VERSION} != "7" ]
then
  echo "CentOS Version Is Not 6 OR 7, Please Check!"
fi

# Python版本
PYTHON_VERSION=$(python -V 2>&1)
PYTHON_SHORT_VERSION=`echo ${PYTHON_VERSION:6:4}`
# 判断Python版本
if [ ${PYTHON_SHORT_VERSION} == '2.7' ]
  then
    PYTHON_PIP_EXIST=$(pip -V 2>&1 | grep 'pip' | grep 'site-packages' | wc -l)
    if [ "${PYTHON_PIP_EXIST}" == "1" ]
      then
      pip install pexpect
    else
      wget https://bootstrap.pypa.io/get-pip.py
      python get-pip.py
      pip install pexpect
    fi
elif [ ${PYTHON_SHORT_VERSION} == '2.6' ]
  then
    cd ${TEMPLATE_CACHE_PATH}
    wget http://pexpect.sourceforge.net/pexpect-2.3.tar.gz
    tar zxvf pexpect-2.3.tar.gz
    cd pexpect-2.3
    python setup.py install
    cd ..
    rm -fr pexpect-2.3.tar.gz pexpect-2.3
else
  echo "Python Version is not satisfied!"
fi

# 安装路径
CMDB_INSTALL_PATH="/usr/local/CMDBClient"
if [ ! -d i${CMDB_INSTALL_PATH} ]; then
  mkdir -p ${CMDB_INSTALL_PATH}
fi

# 下载客户端并解压到指定目录
wget https://s3.ap-northeast-2.amazonaws.com/yunweiconfig/CMDBClient/CMDBClient.tar.gz
tar -xzvf CMDBClient.tar.gz -C ${CMDB_INSTALL_PATH}
rm -fr CMDBClient.tar.gz

# 定时任务
CRONTAB_MINITE="06"
CRONTAB_HOUR="00"
CMDB_SYMBOL="cmdb_client"
CMDB_CACHE_FILE_PATH="/tmp/cmdb_temp_cache"
CRONTAB_PATH=$(echo /var/spool/cron/$USER)
FILE_PATH="${CMDB_INSTALL_PATH}/bin/Client.py"
CMDB_LINE=$(grep -n ${CMDB_SYMBOL} ${CRONTAB_PATH} |cut -f1 -d :)
CMDB_CRONTAB_LOG_PATH="/var/log/cmdb/cmdb_client.log"
CMDB_CRONTAB_LOG_DIR=$(dirname ${CMDB_CRONTAB_LOG_PATH})

# CMDB Crontab日志目录
if [ ! -d ${CMDB_CRONTAB_LOG_DIR} ]
  then
  mkdir -p ${CMDB_CRONTAB_LOG_DIR}
fi

if [ -f "/var/spool/cron/$USER" ]
  then
  cat /var/spool/cron/$USER |grep -v ${CMDB_SYMBOL} > ${CMDB_CACHE_FILE_PATH}
else
  touch ${CMDB_CACHE_FILE_PATH}
fi

echo '# cmdb_client' >> ${CMDB_CACHE_FILE_PATH}
echo "${CRONTAB_MINITE}  ${CRONTAB_HOUR}  *  *  *  python ${FILE_PATH} report_asset cmdb_client 2>&1 >> \"${CMDB_CRONTAB_LOG_DIR}/\$(date '+\%Y\%m\%d').log\"" >> ${CMDB_CACHE_FILE_PATH}
# echo "${CRONTAB_MINITE}  ${CRONTAB_HOUR}  *  *  *  python ${FILE_PATH} report_asset cmdb_client"

# cat ${CMDB_CACHE_FILE_PATH} > /var/spool/cron/$USER
su - root -c "crontab ${CMDB_CACHE_FILE_PATH}"
rm -fr ${CMDB_CACHE_FILE_PATH}


if [ "${OS_MAJOR_VERSION}" == "7" ]
  then
    systemctl reload crond.service
elif [ "${OS_MAJOR_VERSION}" == "6" ]
  then
    service crond reload
else
  echo "Please reload crontab service manually."
fi

# 清理缓存目录
if [ -d ${TEMPLATE_CACHE_PATH} ]
  then
  rm -fr ${TEMPLATE_CACHE_PATH}
fi

cd ${CURRENTPATH}
