#!/usr/bin/env bash
set -euo pipefail

case "$TARGET_CLASSIFIER:$MSYSTEM" in
    windows-aarch64:CLANGARM64)
        compiler=clang
        cxx_compiler=clang++
        expected_target=aarch64-w64-windows-gnu
        ;;
    windows-x86_64:CLANG64)
        # replaced gcc & libstdc++ with clang & libc++
        # (https://github.com/GeyserMC/Geyser/issues/6920) - libstdc++ seems to be leaking handles on windows...
        # apparently its mutex handling doesn't destroy pthreads if a static initializer exists... which is all fine and dandy on linux,
        # but windows's handling (dubbed winpthreads), in its infinite wisdom, seems to do shenanigans where events and sempahores aren't freed until destroy
        # >> et voila, you get like 50-100 handles leaking every time
        # had to hunt these down, https://gcc.gnu.org/bugzilla/show_bug.cgi?id=59807 and https://gcc.gnu.org/bugzilla/show_bug.cgi?id=107857 both describe this issue
        # alas, libc++ on the other hand, doesn't have this issue
        compiler=clang
        cxx_compiler=clang++
        expected_target=x86_64-w64-windows-gnu
        ;;
    *)
        echo "Use CLANGARM64 on Windows ARM64 or CLANG64 on Windows x86_64" >&2
        exit 1
        ;;
esac
compiler_target=$("$compiler" -dumpmachine)
if [ "$compiler_target" != "$expected_target" ]; then
    echo "Expected $expected_target, found $compiler_target" >&2
    exit 1
fi
cmake -S jni -B "build/dockcross/$TARGET_CLASSIFIER/native" -G Ninja \
    -DCMAKE_C_COMPILER="$compiler" \
    -DCMAKE_CXX_COMPILER="$cxx_compiler" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_BUILD_TYPE="$PROJECT_BUILD_TYPE" \
    -DPROJECT_VERSION="$PROJECT_VERSION" \
    -DOPENSSL_ROOT_DIR="$MINGW_PREFIX" \
    -DOPENSSL_USE_STATIC_LIBS=ON
cmake --build "build/dockcross/$TARGET_CLASSIFIER/native" \
    --target datachannel-java --parallel "$JOBS"
