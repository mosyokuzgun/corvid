#!/usr/bin/env bash
# Builds the Corvid image (datarhei Restreamer + NVIDIA fork) from upstream datarhei sources + these patches.
#   ./build.sh                  -> image corvid:v1 with FFmpeg 9.0.2 (corvid-ffmpeg:9.0.2)
#   FFMPEG=6 ./build.sh         -> the previous FFmpeg 6.1.1 (CUDA=11|12 picks its CUDA toolkit)
#   REBUILD_FFMPEG=1 ./build.sh -> rebuild the FFmpeg image even if it exists
#   TAG=user/corvid:1.6 ./build.sh -> another image name (e.g. for Docker Hub)
#
# FFmpeg 9.0.2 (fork: Dockerfile.ubuntu.corvid): the datarhei JSON progress and HLS patches ported
# to 9.0, NVENC/NVDEC, CUDA filters (scale_cuda, overlay_cuda) compiled with clang, no
# --enable-nonfree, so the image may be redistributed. No CUDA toolkit is needed; the driver's
# libraries are mounted by the NVIDIA container toolkit. The first run compiles FFmpeg
# (~20-40 min); afterwards the image is reused.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${WORK:-$HERE/src}"
TAG="${TAG:-corvid:v1}"

declare -A BASE=( [core]=8204728 [restreamer-ui]=7164b38 [restreamer]=fd12aee [ffmpeg]=b37fc95 )

mkdir -p "$WORK"
for repo in core restreamer-ui restreamer ffmpeg; do
  if [ ! -d "$WORK/$repo/.git" ]; then
    git clone "https://github.com/datarhei/$repo.git" "$WORK/$repo"
  fi
  git -C "$WORK/$repo" checkout -q -f -B nvidia "${BASE[$repo]}"
  git -C "$WORK/$repo" -c user.name=build -c user.email=build@localhost am -q "$HERE/patches/$repo"/*.patch
done

# ---- FFmpeg with CUDA filters -------------------------------------------------------------
FFMPEG_IMAGE="${FFMPEG_IMAGE:-}"
drv="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1 | cut -d. -f1 || true)"
echo ">> NVIDIA driver: ${drv:-unknown}"

if [ -z "$FFMPEG_IMAGE" ] && [ "${FFMPEG:-9}" = 9 ]; then
  FFMPEG_IMAGE="corvid-ffmpeg:9.0.2"
  # The CUDA runtime image requires driver >= 560 (CUDA 12.6); FFmpeg itself needs no CUDA
  # runtime, so older drivers (>= 530 for NVENC SDK 12.1) get plain Ubuntu 24.04.
  if [ -n "$drv" ] && [ "$drv" -lt 560 ] 2>/dev/null; then DEPLOY_IMAGE=ubuntu:24.04; else DEPLOY_IMAGE=nvidia/cuda:12.6.1-runtime-ubuntu24.04; fi
  if [ -n "${REBUILD_FFMPEG:-}" ] || ! docker image inspect "$FFMPEG_IMAGE" >/dev/null 2>&1; then
    echo ">> Building $FFMPEG_IMAGE on $DEPLOY_IMAGE (first time only, takes a while) ..."
    ( cd "$WORK/ffmpeg"
      set -a; . ./Build.ubuntu.corvid.env; set +a
      docker build --progress=plain \
        --build-arg BUILD_IMAGE="$OS_NAME:$OS_VERSION" \
        --build-arg DEPLOY_IMAGE="$DEPLOY_IMAGE" \
        --build-arg FFNVCODEC_VERSION="$FFNVCODEC_VERSION" \
        --build-arg FFMPEG_VERSION="$FFMPEG_VERSION" \
        --build-arg BUILD_COMMIT="$(git rev-parse --short HEAD)" \
        -f Dockerfile.ubuntu.corvid \
        -t "$FFMPEG_IMAGE" . )
  else
    echo ">> Using existing FFmpeg image $FFMPEG_IMAGE (REBUILD_FFMPEG=1 to rebuild)"
  fi
elif [ -z "$FFMPEG_IMAGE" ]; then
  # FFmpeg 6.1.1, datarhei's 6.1 branch built with nvcc (needs --enable-nonfree)
  CUDA="${CUDA:-}"
  if [ -z "$CUDA" ]; then
    # nvcc embeds PTX that the *driver* compiles at run time: a toolkit newer than the driver
    # fails with "PTX was compiled with an unsupported toolchain". Pick by the host driver.
    if [ -n "$drv" ] && [ "$drv" -ge 560 ] 2>/dev/null; then CUDA=12; else CUDA=11; fi
  fi
  FFMPEG_IMAGE="restreamer-ffmpeg:6.1.1-cuda$CUDA"

  if [ -n "${REBUILD_FFMPEG:-}" ] || ! docker image inspect "$FFMPEG_IMAGE" >/dev/null 2>&1; then
    echo ">> Building $FFMPEG_IMAGE (first time only, takes a while) ..."
    ( cd "$WORK/ffmpeg"
      set -a; . "./Build.ubuntu.cuda$CUDA.env"; set +a
      docker build --progress=plain \
        --build-arg BUILD_IMAGE="nvidia/cuda:$CUDA_VERSION-devel-ubuntu$OS_VERSION" \
        --build-arg DEPLOY_IMAGE="nvidia/cuda:$CUDA_VERSION-runtime-ubuntu$OS_VERSION" \
        --build-arg FFNVCODEC_VERSION="$FFNVCODEC_VERSION" \
        --build-arg FFMPEG_VERSION="$FFMPEG_VERSION" \
        -f "Dockerfile.ubuntu.cuda$CUDA" \
        -t "$FFMPEG_IMAGE" . )
  else
    echo ">> Using existing FFmpeg image $FFMPEG_IMAGE (REBUILD_FFMPEG=1 to rebuild)"
  fi
fi

# ---- Corvid image ------------------------------------------------------------------------
docker build -f "$WORK/restreamer/Dockerfile.nvidia" \
  --build-context core="$WORK/core" \
  --build-context ui="$WORK/restreamer-ui" \
  --build-arg FFMPEG_IMAGE="$FFMPEG_IMAGE" \
  -t "$TAG" "$WORK/restreamer"

echo "Built $TAG (FFmpeg: $FFMPEG_IMAGE)."
echo "Install / switch over: sudo bash temiz-kurulum.sh (in the package)"
