# ATH9K发包收包

## 运行发包收包示例

只需使用`recvCSI`目录下的程序，其他目录为调试收包发包所使用的程序，仅供参考

发送端：

```bash
start_monitor.sh 11  # 打开monitor模式，并设置信道为11
# 方式1：手动发包
sudo loctag_inject 1200 6 500  # 发送1200个"11b数据帧+11n数据帧"帧对，每个帧对之间间隔500us
# 方式2：自动循环发包
./loctag_inject_x.sh  # 每6秒自动执行一次"loctag_inject 1200 6 500"
```

接收端：

```bash
sudo python driverUtil.py  # 为csi驱动设置过滤选项，仅处理发送端为指定mac地址的包
# 方式1：手动收数
start_monitor.sh 11  # 打开monitor模式，并设置信道为11，记录直接来自发送端的包的CSI
sudo loctag_csi xxxxa.csi  # 记录csi数据到文件xxxxa.csi
start_monitor.sh 1  # 打开monitor模式，并设置信道为1，记录来自标签反射的包的CSI
sudo loctag_csi xxxxz.csi  # 记录csi数据到文件xxxx.csi
# 方式2：双信道简化操作
./loctag_csi_x.sh xxx a # 在11信道记录csi数据，并保存到文件xxxxa
./loctag_csi_x.sh xxx z # 在1信道记录csi数据，并保存到文件xxxxz
```

## 使用配置

### 硬件配置

- 发包：Dell D630笔记本，配AR9580网卡，单天线，MAC地址：b4:ee:b4:b7:0b:3c
- 收包：Dell D630笔记本，配AR9580网卡，3天线，MAC地址：b4:ee:b4:b7:08:f4

### 软件配置

- 操作系统与内核版本

```txt
-------------- /etc/os-release -------------
NAME="Ubuntu"
VERSION="12.04.5 LTS, Precise Pangolin"
ID=ubuntu
ID_LIKE=debian
PRETTY_NAME="Ubuntu precise (12.04.5 LTS)"
VERSION_ID="12.04"

---------------- uname -a  -----------------
Linux csi-pc 4.1.10+ #1 SMP Sat Aug 22 17:49:51 CST 2020 x86_64 x86_64 x86_64 GNU/Linux
```

- 修改过的[Atheros-CSI-Tool](https://github.com/holyens/Atheros-CSI-Tool)，修改过的源码位于各个项目的loctag分支

## 应用修改过的Atheros-CSI-Tool

- 下载修改过的Atheros-CSI-Tool，然后根据Atheros-CSI-Tool的使用说明进行安装即可

```bash
git clone git@github.com:holyens/Atheros-CSI-Tool.git
cd Atheros-CSI-Tool
git checkout loctag
```

- 修改、构建、安装驱动模块的方法
关键模块在Atheros-CSI-Tool中的位置：

```bash
net/mac80211  # 包含mac80211模块
drivers/net/wireless/ath   # 包含ath模块及ath9k目录下的模块
drivers/net/wireless/ath/ath9k  # 包含ath9k, ar9003_csi, ath9k_common, ath9k_hw模块
```

以ath9k模块为例，修改模块源码后，重新编译构建的方法如下：

```bash
# 编译
cd Atheros-CSI-Tool
make modules SUBDIRS=drivers/net/wireless/ath/ath9k
# 手动安装
SYS_ATH9K=/lib/modules/4.1.10+/kernel/drivers/net/wireless/ath/ath9k
USR_ATH9K=/home/wse/softbox/Atheros-CSI-Tool/drivers/net/wireless/ath/ath9k  # 据需修改
# 备份旧驱动
OLD_VER=`date +"%y%m%d%H%M%S"`
sudo mv ${SYS_ATH9K}/ath9k.ko ${SYS_ATH9K}/ath9k.ko.${OLD_VER}
sudo mv ${SYS_ATH9K}/ath9k_common.ko ${SYS_ATH9K}/ath9k_common.ko.${OLD_VER}
sudo mv ${SYS_ATH9K}/ath9k_hw.ko ${SYS_ATH9K}/ath9k_hw.ko.${OLD_VER}
sudo mv ${SYS_ATH9K}/ar9003_csi.ko ${SYS_ATH9K}/ar9003_csi.ko.${OLD_VER}
# 安装新驱动
sudo cp ${USR_ATH9K}/ath9k.ko ${SYS_ATH9K}/ath9k.ko
sudo cp ${USR_ATH9K}/ath9k_common.ko ${SYS_ATH9K}/ath9k_common.ko
sudo cp ${USR_ATH9K}/ath9k_hw.ko ${SYS_ATH9K}/ath9k_hw.ko
sudo cp ${USR_ATH9K}/ar9003_csi.ko ${SYS_ATH9K}/ar9003_csi.ko
# 加载新驱动
sudo modprobe -r ath9k ath9k_common ath9k_hw ar9003_csi
sudo modprobe ath9k ath9k_common ath9k_hw ar9003_csi

# 常用的调试命令
sudo dmesg --clear
sudo dmesg | grep 'loctag\|debug_csi'
```

## 使用修改过的Atheros-CSI-Tool-UserSpace-APP（本项目暂不需要）

- 下载修改过的Atheros-CSI-Tool-UserSpace-APP

```bash
git clone git@github.com:holyens/Atheros-CSI-Tool-UserSpace-APP.git
cd Atheros-CSI-Tool-UserSpace-APP
git checkout loctag
```

## 标签读取与数据收集

需要工具：

### 升级必要的依赖
- 安装：
- 升级 gcc 4.6.3 > gcc-4.9.3（可选）
- 升级：iw > [iw-5.9](http://www.linuxfromscratch.org/blfs/view/svn/basicnet/iw.html)

```bash
wget https://ftp.gnu.org/gnu/gcc/gcc-4.9.3/gcc-4.9.3.tar.gz
tar -xzf gcc-4.9.3.tar.gz && cd gcc-4.9.3
apt-get install zip
./contrib/download_prerequisites
cd ..
mkdir objdir
cd objdir
$PWD/../gcc-4.9.3/configure --prefix=$HOME/gcc-4.9.3  --disable-multilib
make
sudo make install
sudo rm -rf /usr/bin/gcc
sudo ln -s  /home/wse/gcc-4.9.3/bin/gcc /usr/bin/gcc
gcc --version

wget https://www.kernel.org/pub/software/network/iw/iw-5.9.tar.xz --no-check-certificate
cd iw-5.9/
sed -i "/INSTALL.*gz/s/.gz//" Makefile
# 修改Makefile第79行，在末尾加个空格然后加上 -lrt
make
sudo make SBINDIR=/sbin install
```

###