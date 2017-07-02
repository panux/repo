if [ ! -d packages-main ]; then
	git clone https://github.com/panux/packages-main.git || { echo "Failed to git clone package repo"; exit 1; }
fi
if [ ! -d repo/$1/pkgs ]
then
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
for i in packages-main/*.pkgen; do
	docker run --rm -v $(realpath packages-main):/build -v $TMPDIR:/out panux/package-builder /build/$(basename $i) /out || { echo "Failed to build package $i"; exit 1; }
done
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
