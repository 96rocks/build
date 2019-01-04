#!/bin/bash

export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-

LOCALPATH=$(pwd)
OUT=${LOCALPATH}/out
TOOLPATH=${LOCALPATH}/rkbin/tools
BOARD=$1

PATH=$PATH:$TOOLPATH

finish() {
	echo -e "\e[31m MAKE UBOOT IMAGE FAILED.\e[0m"
	exit -1
}
trap finish ERR

if [ $# != 1 ]; then
	BOARD=rk3288-evb
fi

[ ! -d ${OUT} ] && mkdir ${OUT}
[ ! -d ${OUT}/u-boot ] && mkdir ${OUT}/u-boot
[ ! -d ${OUT}/u-boot/spi ] && mkdir ${OUT}/u-boot/spi

source $LOCALPATH/build/board_configs.sh $BOARD

if [ $? -ne 0 ]; then
	exit
fi

echo -e "\e[36m Building U-boot for ${BOARD} board! \e[0m"
echo -e "\e[36m Using ${UBOOT_DEFCONFIG} \e[0m"

cd ${LOCALPATH}/u-boot
make ${UBOOT_DEFCONFIG} all

if [ "${CHIP}" == "rk3288" ] || [ "${CHIP}" == "rk322x" ] || [ "${CHIP}" == "rk3036" ]; then
	if [ `grep CONFIG_SPL_OF_CONTROL=y ./.config` ] && \
			! [ `grep CONFIG_SPL_OF_PLATDATA=y .config` ] ; then
		SPL_BINARY=u-boot-spl-dtb.bin
	else
		SPL_BINARY=u-boot-spl-nodtb.bin
	fi
	tools/mkimage -n ${CHIP} -T \
		rksd -d spl/${SPL_BINARY} idbloader.img
	cat u-boot-dtb.bin >>idbloader.img
	cp idbloader.img ${OUT}/u-boot/
elif [ "${CHIP}" == "rk3328" ]; then
	$TOOLPATH/loaderimage --pack --uboot ./u-boot-dtb.bin uboot.img 0x200000

	tools/mkimage -n rk3328 -T rksd -d ../rkbin/rk33/rk3328_ddr_786MHz_v1.06.bin idbloader.img
	cat ../rkbin/rk33/rk3328_miniloader_v2.43.bin >> idbloader.img
	cp idbloader.img ${OUT}/u-boot/	
	cp ../rkbin/rk33/rk3328_loader_ddr786_v1.06.243.bin ${OUT}/u-boot/

	cat >trust.ini <<EOF
[VERSION]
MAJOR=1
MINOR=2
[BL30_OPTION]
SEC=0
[BL31_OPTION]
SEC=1
PATH=../rkbin/rk33/rk3328_bl31_v1.34.bin
ADDR=0x10000
[BL32_OPTION]
SEC=0
[BL33_OPTION]
SEC=0
[OUTPUT]
PATH=trust.img
EOF

	$TOOLPATH/trust_merger trust.ini

	cp uboot.img ${OUT}/u-boot/
	mv trust.img ${OUT}/u-boot/
elif [ "${CHIP}" == "rk3399" ]; then
	$TOOLPATH/loaderimage --pack --uboot ./u-boot-dtb.bin uboot.img 0x200000 --size 1024 1

	tools/mkimage -n rk3399 -T rksd -d ../rkbin/bin/rk33/rk3399_ddr_800MHz_v1.15.bin idbloader.img
	cat ../rkbin/bin/rk33/rk3399_miniloader_v1.15.bin >> idbloader.img
	cp idbloader.img ${OUT}/u-boot/

	tools/mkimage -n rk3399 -T rkspi -d ../rkbin/bin/rk33/rk3399_ddr_800MHz_v1.15.bin idbloader-spi.img
	cat ../rkbin/bin/rk33/rk3399_miniloader_spinor_v1.14.bin >> idbloader-spi.img
	cp idbloader-spi.img ${OUT}/u-boot/spi

	cp ../rkbin/bin/rk33/rk3399_loader_v1.12.112.bin ${OUT}/u-boot/
	cp ../rkbin/bin/rk33/rk3399_loader_spinor_v1.15.114.bin ${OUT}/u-boot/spi

	cat >trust.ini <<EOF
[VERSION]
MAJOR=1
MINOR=0
[BL30_OPTION]
SEC=0
[BL31_OPTION]
SEC=1
PATH=../rkbin/bin/rk33/rk3399_bl31_v1.22.elf
ADDR=0x10000
[BL32_OPTION]
SEC=0
[BL33_OPTION]
SEC=0
[OUTPUT]
PATH=trust.img
EOF

	$TOOLPATH/trust_merger --size 1024 1 trust.ini

	cp uboot.img ${OUT}/u-boot/
	cp trust.img ${OUT}/u-boot/

	cat > spi.ini <<EOF
[System]
FwVersion=18.08.03
BLANK_GAP=1
FILL_BYTE=0
[UserPart1]
Name=IDBlock
Flag=0
Type=2
File=../rkbin/bin/rk33/rk3399_ddr_800MHz_v1.15.bin,../rkbin/bin/rk33/rk3399_miniloader_spinor_v1.14.bin
PartOffset=0x40
PartSize=0x7C0
[UserPart2]
Name=uboot
Type=0x20
Flag=0
File=./uboot.img
PartOffset=0x1000
PartSize=0x800
[UserPart3]
Name=trust
Type=0x10
Flag=0
File=./trust.img
PartOffset=0x1800
PartSize=0x800
EOF
	$TOOLPATH/firmwareMerger -P spi.ini ${OUT}/u-boot/spi
	mv ${OUT}/u-boot/spi/Firmware.img ${OUT}/u-boot/spi/uboot-trust-spi.img
	mv ${OUT}/u-boot/spi/Firmware.md5 ${OUT}/u-boot/spi/uboot-trust-spi.img.md5


elif [ "${CHIP}" == "rk3128" ]; then
	$TOOLPATH/loaderimage --pack --uboot ./u-boot-dtb.bin uboot.img

	dd if=../rkbin/rk31/rk3128_ddr_300MHz_v2.06.bin of=DDRTEMP bs=4 skip=1
	tools/mkimage -n rk3128 -T rksd -d DDRTEMP idbloader.img
	cat ../rkbin/rk31/rk312x_miniloader_v2.40.bin >> idbloader.img
	cp idbloader.img ${OUT}/u-boot/
	cp ../rkbin/rk31/rk3128_loader_v2.05.240.bin ${OUT}/u-boot/

	$TOOLPATH/loaderimage --pack --trustos ../rkbin/rk31/rk3126_tee_ta_v1.27.bin trust.img

	cp uboot.img ${OUT}/u-boot/
	mv trust.img ${OUT}/u-boot/
fi

echo -e "\e[36m U-boot IMAGE READY! \e[0m"
