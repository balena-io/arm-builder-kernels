# arm-builder-kernels

⚠️ deprecation notice: this repository is being replaced by https://github.com/balena-io/remote-workers

## ToC
* [Ubuntu](#ubuntu)
* [Amazon Linux 2](#amazon-linux-2)

## Ubuntu
* update `build/kernel-src` submodule and checkout new upstream version tag
* generate `patch/{{version-tag}}/balena.patch` from existing/previous [patch(es)](patch)
* use pull-request workflow to create a GitHub release containing kernel binaries (.deb)
* [renovate](https://github.com/balena-io/renovate-config/blob/master/default.json) or manually update [remote-builders](https://github.com/balena-io/remote-builders/blob/master/equinix_metal_devices.tf)


## Amazon Linux 2

### install dependencies
> use next generation Linux kernel as a base on a temporary AWS EC2 build instance (aarch64)

    amazon-linux-extras install kernel-ng

    yum groupinstall -y "Development Tools"

    yum-builddep -y kernel && yum install -y pesign

    yumdownloader --source kernel

    groupadd mock && useradd mockbuild


### unpack RPM
> https://www.hiroom2.com/2016/05/29/centos-7-rebuild-kernel-with-src-rpm/

    rpm -i kernel-*.src.rpm

    pushd rpmbuild

    cp -a SPECS/kernel.spec{,.org}


### increment build version
> increment build number in `SPECS/kernel.spec`

    diff -uprN SPECS/kernel.spec{.org,}


### prepare kernel source

    rpmbuild -bp SPECS/kernel.spec

    pushd BUILD/kernel-*

    kernel_tree=$(find . -maxdepth 1 -name linux-*.amzn2.aarch64 -type d)

    cp -a ${kernel_tree}{,.org}


### patch
> (e.g.) diff [patch](https://github.com/balena-io-archive/kernel/blob/fd12169aeb39b23b08373aa66cbd819365efec59/kernel/sys.c) [base](https://github.com/torvalds/linux/blob/v5.4/kernel/sys.c) reference

```
--- a/kernel/sys.c
+++ b/kernel/sys.c
@@ -1196,10 +1196,25 @@ SYSCALL_DEFINE0(setsid)
 DECLARE_RWSEM(uts_sem);

 #ifdef COMPAT_UTS_MACHINE
+static char compat_uts_machine[__OLD_UTS_LEN+1] = COMPAT_UTS_MACHINE;
+
+static int __init parse_compat_uts_machine(char *arg)
+{
+   strncpy(compat_uts_machine, arg, __OLD_UTS_LEN);
+   compat_uts_machine[__OLD_UTS_LEN] = 0;
+   return 0;
+}
+early_param("compat_uts_machine", parse_compat_uts_machine);
+
+#undef COMPAT_UTS_MACHINE
+#define COMPAT_UTS_MACHINE compat_uts_machine
+#endif
+
+#ifdef COMPAT_UTS_MACHINE
 #define override_architecture(name) \
    (personality(current->personality) == PER_LINUX32 && \
     copy_to_user(name->machine, COMPAT_UTS_MACHINE, \
-             sizeof(COMPAT_UTS_MACHINE)))
+             sizeof(COMPAT_UTS_MACHINE)))
 #else
 #define override_architecture(name)    0
 #endif
@@ -1207,31 +1222,15 @@ DECLARE_RWSEM(uts_sem);
 /*
  * Work around broken programs that cannot handle "Linux 3.0".
  * Instead we map 3.x to 2.6.40+x, so e.g. 3.0 would be 2.6.40
- * And we map 4.x and later versions to 2.6.60+x, so 4.0/5.0/6.0/... would be
- * 2.6.60.
+ * And we map 4.x to 2.6.60+x, so 4.0 would be 2.6.60.
  */
 static int override_release(char __user *release, size_t len)
 {
    int ret = 0;

+   strncpy(compat_uts_machine, "armv7l", __OLD_UTS_LEN);
    if (current->personality & UNAME26) {
-       const char *rest = UTS_RELEASE;
-       char buf[65] = { 0 };
-       int ndots = 0;
-       unsigned v;
-       size_t copy;
-
-       while (*rest) {
-           if (*rest == '.' && ++ndots >= 3)
-               break;
-           if (!isdigit(*rest) && *rest != '.')
-               break;
-           rest++;
-       }
-       v = ((LINUX_VERSION_CODE >> 8) & 0xff) + 60;
-       copy = clamp_t(size_t, len, 1, sizeof(buf));
-       copy = scnprintf(buf, copy, "2.6.%u%s", v, rest);
-       ret = copy_to_user(release, buf, copy + 1);
+       strncpy(compat_uts_machine, "armv6l", __OLD_UTS_LEN);
    }
    return ret;
 }
```


### add patch
> check next available patch slot in SOURCES/ (e.g. 0509) and add to `../../SPECS/kernel.spec`

    # generate and apply patch with override_release and compat_uts_machine functions
    git diff ${kernel_tree}{.org,} > ../../SOURCES/0509-balena.patch
    popd

	# diff -uprN SPECS/kernel.spec{.org,}
	--- SPECS/kernel.spec.org       2022-08-11 22:34:36.000000000 +0000
	+++ SPECS/kernel.spec   2022-09-05 22:13:37.058325535 +0000
	@@ -1,4 +1,4 @@
	-%define buildid 122.509
	+%define buildid 122.509.1

	 # We have to override the new %%install behavior because, well... the kernel is special.
	 %global __spec_install_pre %%{___build_pre}
	@@ -877,6 +877,7 @@ Patch0505: 0505-ENA-Update-to-v2.7.4.pat
	 Patch0506: 0506-ext4-reduce-computation-of-overhead-during-resize.patch
	 Patch0507: 0507-ext4-avoid-resizing-to-a-partial-cluster-size.patch
	 Patch0508: 0508-Mitigate-unbalanced-RETs-on-vmexit-via-serialising-w.patch
	+Patch0509: 0509-balena.patch

	 BuildRoot: %{_tmppath}/kernel-%{KVERREL}-root

	@@ -1734,6 +1735,7 @@ ApplyPatch 0505-ENA-Update-to-v2.7.4.pat
	 ApplyPatch 0506-ext4-reduce-computation-of-overhead-during-resize.patch
	 ApplyPatch 0507-ext4-avoid-resizing-to-a-partial-cluster-size.patch
	 ApplyPatch 0508-Mitigate-unbalanced-RETs-on-vmexit-via-serialising-w.patch
	+ApplyPatch 0509-balena.patch

	 # Any further pre-build tree manipulations happen here.


### build

    rpmbuild -ba --without debug --without doc --without perf \
      --without tools --without debuginfo --without kdump \
      --without bootwrapper SPECS/kernel.spec


### install

    rpm -i RPMS/aarch64/kernel-*.amzn2.aarch64.rpm
    rpm -i RPMS/aarch64/kernel-devel-*.amzn2.aarch64.rpm
    rpm -i RPMS/aarch64/kernel-headers-*.amzn2.aarch64.rpm


### update bootloader
> add `compat_uts_machine=armv7l` parameter to default boot line in `/etc/default/grub`

    grub2-mkconfig -o /boot/grub2/grub.cfg


### disable kernel updates

    $ cat /etc/yum.conf
    [main]
    cachedir=/var/cache/yum/$basearch/$releasever
    ...
    exclude=kernel*


### reboot

    sync && reboot && exit


### test

    # should match your patch kernel version
    uname -r

    # linux32 --uname-2.6 uname -m
    armv6l

    # linux32 uname -m
    armv7l

    # uname -m
    aarch64
