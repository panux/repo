if [ "$#" -lt 1 ]; then
	echo "script requires at least one argument"
	exit 1
fi
if [ ! -d packages-main ]; then
	git clone https://github.com/panux/packages-main.git || { echo "Failed to git clone package repo"; exit 1; }
fi
if [ ! -d repo/$1/pkgs ]; then
	mkdir -p repo/$1/pkgs || { echo "Failed to create repo directory"; exit 1; }
fi
git -C packages-main pull || { echo "Failed to pull package repo"; exit 1; }
docker pull panux/package-builder || { echo "Failed to pull package-builder image"; exit 1; }
TMPDIR=$(mktemp -d)
LST=$(mktemp)
function cleanup() {
	rm -rf $TMPDIR
	rm -f $LST
}
trap cleanup EXIT
if [ "$#" -lt 2 ]; then
	make -C packages-main DEST=$TMPDIR all || { echo "Failed to build package(s)"; exit 1; }
else
	make -C packages-main DEST=$TMPDIR "${@:2}" || { echo "Failed to build package(s)"; exit 1; }
fi
ls $TMPDIR
for i in $TMPDIR/*.tar.xz; do
	cmp --silent "$i" repo/$1/pkgs/$(basename -s .tar.xz "$i") && {
		rm "$i" || { echo "Removal error"; exit 1; }
	} || {
		gpg --output $TMPDIR/$(basename -s .tar.xz "$i").sig --detach-sig "$i" || { echo "Signature failure"; exit 1; }
	}
done
for i in $TMPDIR/*; do
	mv $i repo/$1/pkgs/$(basename "$i") || { echo "Move error"; exit 1; }
done
