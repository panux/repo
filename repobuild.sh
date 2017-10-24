fail() {
	echo "$1"
	exit 1
}

if [ $# -lt 2 ]; then
	fail "Missing arguments"
fi

git -C packages-main pull || fail "git pull failed"
go get -u github.com/panux/pkgen || fail "go get failed"
go install github.com/panux/pkgen || fail "go install failed"
make -C packages-main ARCH=$1 "${@:2}" || fail "make failed"
make -C packages-main/out -j10 ARCH=$1 minisign=1 odir=$(realpath repo/beta/$1/pkgs) || fail "output update failed"
