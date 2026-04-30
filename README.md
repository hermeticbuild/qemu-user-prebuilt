# qemu-static

This repository builds static Linux user-mode QEMU archives for GitHub releases.
It is based on <https://codeberg.org/ziglang/qemu-static> at commit
`96593b61f32eebf2e44d88fbfffdc83f5b622225`.

The purpose of the upstream project is to build a highly compatible linux QEMU
binary package for Zig CI testing.

Zig requires a very recent QEMU version, sometimes unreleased commit-revs, and
sometimes with custom patches. For this reason, distro-based QEMU packages are
unsuitable.

The overall strategy is to use Alpine Linux to host a QEMU build and link
statically to all possible libraries.

It is a non-goal to build QEMU with all features enabled.
It is a non-goal to build QEMU with system emulation enabled.
It is a non-goal to build older versions of QEMU.

## Release workflow

Pushing any tag starts `.github/workflows/release.yml`. The workflow builds:

- `qemu-user-linux-amd64-<target>` binaries, plus `.gz` and `.zst` copies, on `ubuntu-24.04`
- `qemu-user-linux-arm64-<target>` binaries, plus `.gz` and `.zst` copies, on `ubuntu-24.04-arm`
- `qemu-user-linux-amd64-<version>.tar.zst` and `.tar.gz` archives containing all amd64 exec binaries
- `qemu-user-linux-arm64-<version>.tar.zst` and `.tar.gz` archives containing all arm64 exec binaries

Each build uploads every binary, compressed binary, archive, and `.sha256` file
as workflow artifacts, attests them with GitHub artifact attestations, and
publishes the attestation bundle as a release asset. The final job creates or
updates the GitHub release for the tag and uploads both architecture artifact
sets, checksums, and attestation bundles.

The workflow can also be run manually with a `tag_name` input to retry release
publication for an existing tag.

## Maintainer note: ZSF qemu fork updates

Edit the following values in `build`:

- `ARTIFACT_BASE_VERSION`
- `ARTIFACT_SERIAL`
- `QEMU_REV`

## Build docker image

```sh
docker build --tag qemu .
```

## Run container, save ID, copy artifact(s)

```sh
mkdir ../artifact
docker run -it --cidfile=qemu.cid qemu true
docker cp "$(cat qemu.cid):work/artifact/." ../artifact/.
```

## Review final artifact(s)

```sh
ls -al ../artifact/
```

## Cleanup container, ID-file, and image

```sh
docker container rm "$(cat qemu.cid)"
rm qemu.cid
docker image rm qemu
```

## Really cleanup docker

```sh
docker system prune --force
```
