if [ "$#" -lt 2 ]; then
	echo "script requires at least two arguments"
	exit 1
fi
if [ -d packages-main ]; then
	rm -rf packages-main
fi
git clone -b $1 https://github.com/panux/packages-main.git || { echo "Failed to git clone package repo"; exit 1; }
echo clone done
if [ ! -d repo/$1/$2/pkgs ]; then
	mkdir -p repo/$1/$2/pkgs || { echo "Failed to create repo directory"; exit 1; }
fi
git -C packages-main pull || { echo "Failed to pull package repo"; exit 1; }
docker pull panux/package-builder:$2 || { echo "Failed to pull package-builder image"; exit 1; }
TMPDIR=$(mktemp -d)
LST=$(mktemp)
function cleanup() {
	rm -rf $TMPDIR
	rm -f $LST
}
trap cleanup EXIT
if [ "$#" -lt 2 ]; then
	make -C packages-main ARCH=$2 DEST=$TMPDIR all || { echo "Failed to build package(s)"; exit 1; }
else
	make -C packages-main ARCH=$2 DEST=$TMPDIR "${@:3}" || { echo "Failed to build package(s)"; exit 1; }
fi
ls $TMPDIR
for i in $TMPDIR/*.tar.xz; do
	cmp --silent "$i" repo/$1/$2/pkgs/$(basename -s .tar.xz "$i") && {
		rm "$i" || { echo "Removal error"; exit 1; }
	} || {
		cp $i $TMPDIR/$(basename -s .tar.xz "$i").tar
		tar -xf $TMPDIR/$(basename -s .tar.xz "$i").tar -C $TMPDIR ./.pkginfo
		mv $TMPDIR/.pkginfo $TMPDIR/$(basename -s .tar.xz "$i").pkginfo
		gzip $TMPDIR/$(basename -s .tar.xz "$i").tar
		echo SHA256SUM="\""$(sha256sum "$i" | cut -d' ' -f1)"\"" >> $TMPDIR/$(basename -s .tar.xz "$i").pkginfo
		gpg --output $TMPDIR/$(basename -s .tar.xz "$i").pkginfo.sig --sign $TMPDIR/$(basename -s .tar.xz "$i").pkginfo || { echo "Signature failure"; exit 1; }
		echo | minisign -SHm $TMPDIR/$(basename -s .tar.xz "$i").pkginfo || { echo "minisign signature failure"; exit 1; }
		gpg --output $TMPDIR/$(basename -s .tar.xz "$i").sig --detach-sig "$i" || { echo "Signature failure"; exit 1; }
		gpgv $TMPDIR/$(basename -s .tar.xz "$i").sig $i || { echo "Bad signature"; exit 1; }
	}
done
for i in $TMPDIR/*; do
	mv $i repo/$1/$2/pkgs/$(basename "$i") || { echo "Move error"; exit 1; }
done
