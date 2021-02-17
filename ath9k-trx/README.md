# ATH9K发包收包

## 使用配置

### 硬件配置

- 发包：Dell D630笔记本，配AR9580网卡，单天线
- 收包：Dell D630笔记本，配AR9580网卡，3天线

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

- 修改过的[Atheros-CSI-Tool](https://github.com/holyens/Atheros-CSI-Tool)和[Atheros-CSI-Tool-UserSpace-APP](https://github.com/holyens/loctag-Atheros-CSI-Tool-UserSpace-APP)，修改过的源码位于各个项目的loctag分支

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

## 使用修改过的Atheros-CSI-Tool-UserSpace-APP

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