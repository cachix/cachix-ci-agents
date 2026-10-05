# Two disks in a RAID 1 array, booted with GRUB from the MBR.
{
  disks ? [
    "/dev/vdb"
    "/dev/vdc"
  ],
  ...
}:

let
  mkDisk = device: {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size = "1M";
          type = "EF02"; # for grub MBR
        };
        mdadm = {
          size = "100%";
          content = {
            type = "mdraid";
            name = "raid1";
          };
        };
      };
    };
  };
in
{
  disko.devices = {
    disk = {
      vdb = mkDisk (builtins.elemAt disks 0);
      vdc = mkDisk (builtins.elemAt disks 1);
    };
    mdadm = {
      raid1 = {
        type = "mdadm";
        level = 1;
        content = {
          type = "gpt";
          partitions = {
            primary = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
