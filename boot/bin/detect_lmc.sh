#!/bin/bash

# TODO
# ...

# Successfully detects
# Fedora-Workstation-Live-x86_64-24-1.2.iso
# Solus-1.1.iso

detect_lmc() {

HERE=$(dirname $(readlink -f $0))

MOUNTPOINT="$1"

#
# Make sure this ISO is one that this script understands - otherwise return asap
#

find "$MOUNTPOINT"/LiveOS/squashfs.img 2>/dev/null || return

#
# Parse the required information out of the ISO
#

mount "$MOUNTPOINT"/LiveOS/squashfs.img "$MOUNTPOINT" -o loop
if [ -e "$MOUNTPOINT"/LiveOS/rootfs.img ] ; then
  # F24+
  LIVETOOL="livemedia-creator"
  LIVETOOLVERSION=1
  mount "$MOUNTPOINT"/LiveOS/rootfs.img "$MOUNTPOINT" -o loop
    LIVETOOLVERSION2=$(find /var/lib/dnf/yumdb/ -name "*dracut-live*" | cut -d "-" -f 4-5)
    if [ ! -z $LIVETOOLVERSION2 ] ; then
      LIVETOOLVERSION=$LIVETOOLVERSION2
    fi
  umount "$MOUNTPOINT"
else
  umount "$MOUNTPOINT"
  return
fi
umount "$MOUNTPOINT"

CFG=$(find "$MOUNTPOINT" -name isolinux.cfg | head -n 1)

LINUX=$(cat $CFG | grep "kernel " | head -n 1 | sed -e 's|kernel ||g' | xargs)
if [[ $LINUX != *"/"* ]] ; then
  LINUX=$(find "$MOUNTPOINT" -name "$LINUX" | head -n 1 | sed -e "s|$MOUNTPOINT||g" ) # Need to get full path
fi
echo "* LINUX $LINUX"

INITRD=$(cat $CFG | grep "append " | head -n 1 | cut -d = -f 2 | cut -d " " -f 1 | xargs)
if [[ $INITRD != *"/"* ]] ; then
  INITRD=$(find "$MOUNTPOINT" -name "$INITRD" | head -n 1 | sed -e "s|$MOUNTPOINT||g" ) # Need to get full path
fi
echo "* INITRD $INITRD"

APPEND=$(cat $CFG | grep "append " | head -n 1 | sed -e 's|append ||g' | sed -e 's|initrd=initrd0.img ||g' | xargs)
echo "* APPEND $APPEND"

#
# Put together a grub entry
#

read -r -d '' GRUBENTRY << EOM

menuentry "$ISONAME - $LIVETOOL $LIVETOOLVERSION" --class fedora {
        iso_path="/boot/iso/$ISONAME"
        search --no-floppy --file \${iso_path} --set
        live_args="for-dracut --> iso-scan/filename=\${iso_path} selinux=0 rd.live.deltadir=/run/initramfs/isoscan/boot/deltadir rd.live.user=$USERNAME rd.live.host=$HOSTNAME vconsole.keymap=$KEYBOARD locale.LANG=$LOCALE max_loop=256"
        custom_args=""
        iso_args="$APPEND"
        loopback loop \${iso_path}
        linux (loop)$LINUX \${live_args} \${custom_args} \${iso_args}
        initrd (loop)$INITRD /boot/iso/additional-initramfs/initramfs
}
EOM

}
