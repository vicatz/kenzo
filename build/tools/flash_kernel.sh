#!/sbin/sh
 #
 # Copyright � 2017, Umang Leekha "umang96" <umangleekha3@gmail.com> 
 #
 # Live ramdisk patching script
 #
 # This software is licensed under the terms of the GNU General Public
 # License version 2, as published by the Free Software Foundation, and
 # may be copied, distributed, and modified under those terms.
 #
 # This program is distributed in the hope that it will be useful,
 # but WITHOUT ANY WARRANTY; without even the implied warranty of
 # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 # GNU General Public License for more details.
 #
 # Please maintain this if you use this script or any part of it
 #
selinx=$(cat /tmp/aroma/sel.prop | cut -d '=' -f2)
qc=$(cat /tmp/aroma/crate.prop | cut -d '=' -f2)
therm=$(cat /tmp/aroma/thermal.prop | cut -d '=' -f2)
nos1=`cat /system/build.prop | grep ro.product.name=`
nos2=${nos1:16:8}
if [ $nos2 == "nitrogen" ]; then
echo "NitrogenOS detected, forcing permissive"
selinx=3
fi
zim=/tmp/Image1
if [ $qc -eq 1 ]; then
dim=/tmp/dt1.img
elif [ $qc -eq 2 ]; then
dim=/tmp/dt2.img
fi
val1=$(cat /tmp/aroma/cpu53.prop | cut -d '=' -f2)

  case $val1 in
	1)
	  cpu_max_c1=" cpu_max_c1=1440000"
	  ;;
	2)
	  cpu_max_c1=" cpu_max_c1=1401600"
	  ;;
	3)
	  cpu_max_c1=" cpu_max_c1=1382400"
	  ;;
	4)
	  cpu_max_c1=" cpu_max_c1=1305600"
	  ;;
  esac

val2=$(cat /tmp/aroma/cpu72.prop | cut -d '=' -f2)

  case $val2 in
	1)
	  cpu_max_c2=" cpu_max_c2=1843200"
	  ;;
	2)
	  cpu_max_c2=" cpu_max_c2=1804800"
	  ;;
	3)
	  cpu_max_c2=" cpu_max_c2=1747200"
	  ;;
	4)
	  cpu_max_c2=" cpu_max_c2=1612800"
	  ;;
  esac

cmd="androidboot.hardware=qcom ehci-hcd.park=3 androidboot.bootdevice=7824900.sdhci lpm_levels.sleep_disabled=1 ramoops_memreserve=4M"
if [ $selinx -eq 2 ]; then
cmd=$cmd" androidboot.selinux=enforcing"
elif [ $selinx -eq 3 ]; then
cmd=$cmd" androidboot.selinux=permissive"
fi
cmd=$cmd$cpu_max_c1$cpu_max_c2
AUDIO=`grep "item.0.3" /tmp/aroma/mods.prop | cut -d '=' -f2`
if [ $AUDIO = 1 ]; then
cmd=$cmd" snd-soc-msm8x16-wcd.dig_core_collapse_enable=0"
fi
if [ $therm -eq 1 ]; then
echo "Using old thermal engine"
cp /tmp/thermal-engine /system/vendor/bin/thermal-engine
fi
cp /tmp/shadow.sh /system/etc/shadow.sh
chmod 644 /system/etc/shadow.sh
cp -f /tmp/cpio /sbin/cpio
cd /tmp/
/sbin/busybox dd if=/dev/block/bootdevice/by-name/boot of=./boot.img
./unpackbootimg -i /tmp/boot.img
mkdir /tmp/ramdisk
cp /tmp/boot.img-ramdisk.gz /tmp/ramdisk/
cd /tmp/ramdisk/
gunzip -c /tmp/ramdisk/boot.img-ramdisk.gz | /tmp/cpio -i
rm /tmp/ramdisk/boot.img-ramdisk.gz
rm /tmp/boot.img-ramdisk.gz
cp /tmp/init.shadow.rc /tmp/ramdisk/
# ADD SPECTRUM SUPPORT
cp /tmp/init.spectrum.rc /tmp/ramdisk/
cp /tmp/init.spectrum.sh /tmp/ramdisk/
# COMPATIBILITY FIXES START
cp /tmp/init.qcom.post_boot.sh /system/etc/init.qcom.post_boot.sh
cp /tmp/gxfingerprint.default.so /system/lib64/hw/gxfingerprint.default.so
chmod 644 /system/etc/init.qcom.post_boot.sh
if [ $(grep -c "lazytime" fstab.qcom) -ne 0 ]; then
cp /tmp/fstab.qcom /tmp/ramdisk/
chmod 640 /tmp/ramdisk/fstab.qcom
fi
if [ -f /tmp/ramdisk/init.darkness.rc ]; then
rm /tmp/ramdisk/init.darkness.rc
fi
if [ -f /tmp/ramdisk/init.radon.rc ]; then
rm /tmp/ramdisk/init.radon.rc
fi
# COMPATIBILITY FIXES END
chmod 0750 /tmp/ramdisk/init.shadow.rc
if [ $(grep -c "import /init.shadow.rc" /tmp/ramdisk/init.rc) == 0 ]; then
   sed -i "/import \/init\.\${ro.hardware}\.rc/aimport /init.shadow.rc" /tmp/ramdisk/init.rc
fi
chmod 0750 /tmp/ramdisk/init.spectrum.rc
if [ $(grep -c "import /init.spectrum.rc" /tmp/ramdisk/init.rc) == 0 ]; then
   sed -i "/import \/init\.\${ro.hardware}\.rc/aimport /init.spectrum.rc" /tmp/ramdisk/init.rc
fi
find . | cpio -o -H newc | gzip > /tmp/boot.img-ramdisk.gz
rm -r /tmp/ramdisk
cd /tmp/
./mkbootimg --kernel $zim --ramdisk /tmp/boot.img-ramdisk.gz --cmdline "$cmd"  --base 0x80000000 --pagesize 2048 --ramdisk_offset 0x01000000 --tags_offset 0x00000100 --dt $dim -o /tmp/newboot.img
/sbin/busybox dd if=/tmp/newboot.img of=/dev/block/bootdevice/by-name/boot
