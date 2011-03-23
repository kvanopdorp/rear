# Include/Exclude components

# Available configuration options:
# EXCLUDE_MOUNTPOINTS
# EXCLUDE_MD
# EXCLUDE_VG
# INCLUDE_VG

# Uses the LAYOUT_TODO and LAYOUT_DEPS files to mark excluded files as done.

# If a filesystem is excluded (for backup) we still may need to perform an
# mkfs on the filesystem as it may be referenced in fstab and mounted
# automatically, or is needed for a separate restore.
#
# If you somehow need this functionality, it's advised to exclude the
# device or volume group
#for mountpoint in "${EXCLUDE_MOUNTPOINTS[@]}" ; do
#    LogPrint "Excluding mountpoint $mountpoint."
#    mark_as_done "fs:$mountpoint"
#    mark_tree_as_done "fs:$mountpoint"
#done

for md in "${EXCLUDE_MD[@]}" ; do
    LogPrint "Excluding RAID $md."
    mark_as_done "/dev/$md"
    mark_tree_as_done "/dev/$md"
done

for vg in "${EXCLUDE_VG[@]}" ; do
    LogPrint "Excluding Volume Group $vg."
    mark_as_done "/dev/$vg"
    mark_tree_as_done "/dev/$vg"
done

if [ ${#INCLUDE_VG[@]} -gt 0 ] ; then
    while read lvmgrp name junk ; do
        if ! IsInArray "$name" "${INCLUDE_VG[@]}" ; then
            LogPrint "Excluding Volume Group $name"
            mark_as_done "/dev/$name"
            mark_tree_as_done "/dev/$name"
        fi
    done < <(grep ^lvmgrp $LAYOUT_FILE)
fi

# Component in position 2
remove_component() {
    sed -i "\,^$1 $2,d" $LAYOUT_FILE
}

# Component in position 3
remove_second_component() {
    sed -i -r "\,^$1 [^ ]+ $2,d" $LAYOUT_FILE
}

# Remove lines in the LAYOUT_FILE
while read done name type junk ; do
    case $type in 
        lvmdev)
            name=${name#pv:}
            remove_second_component $type $name
            ;;
        lvmvol)
            name=${name#/dev/mapper/*-}
            remove_second_component $type $name
            ;;
        fs)
            name=${name#fs:}
            remove_second_component $type $name
            ;;
        swap)
            name=${name#swap:}
            remove_component $type $name
            ;;
        *)
            remove_component $type $name
            ;;
    esac
done < <(grep "^done" $LAYOUT_TODO)

# Remove all LVM PVs of excluded VGs
while read status name junk ; do
    remove_component "lvmdev" "$name"
done < <(grep -E "^done [^ ]+ lvmgrp"  $LAYOUT_TODO)