# static-toolbox

`static-toolbox` publishes current, portable Linux binaries for incident response,
security testing, and deployment to minimal hosts where the normal package manager
or runtime libraries are unavailable. A good release is reproducible from pinned
sources, statically linked with musl, validated on every supported architecture, and
downloadable with a matching SHA-256 file.

## Published toolset

| Tool | Version | Included programs |
| --- | --- | --- |
| Nmap | 7.993 | `nmap`, `ncat`, `nping`, and Nmap data files |
| tcpdump | 4.99.7 | `tcpdump` with libpcap 1.11.0 |
| OpenSSH | 10.6p2 | Client, server, required helpers, key, agent, SCP, and SFTP programs |
| socat | 1.8.1.3 | `socat` with OpenSSL support |
| GDB | 18.1 | `gdb` and `gdbserver` |
| strace | 7.3 | `strace` |
| tcpreplay | 4.6.2 | Replay, rewrite, preparation, bridge, and inspection programs |

Linux releases are built for `x86`, `x86_64`, `armhf`, and `aarch64`. Each release
contains one tar archive and checksum per architecture. Download release artifacts
from the [GitHub releases page](https://github.com/godylockz/static-toolbox/releases).

## CI and release checks

The Linux workflows run when their build inputs change, can be started manually,
and run weekly to detect build-environment regressions. The shared workflow:

1. builds in a musl cross-compiler container pinned by image digest;
2. downloads source archives pinned by version and SHA-256, or checks out an exact
   source commit;
3. checks every executable's architecture and rejects ELF interpreters or dynamic
   dependencies;
4. runs version checks and tool-specific smoke tests, including a localhost Nmap
   scan and offline tcpdump packet parsing;
5. creates deterministic `tar.gz` artifacts, verifies their checksums, and publishes
   all four architectures as a GitHub release.

The workflow run artifacts expire after 30 days. Releases are the durable download
location.

## Static Linux scope

These are musl-linked Linux executables, not OCI container images. Static linkage
removes the target host's libc and shared-library dependency, but it does not remove
kernel, privilege, device, or configuration requirements. Packet capture and raw
network operations still need the appropriate capabilities. `sshd` still needs host
keys, configuration, users, and privilege-separation directories. Nmap uses its
bundled data directory through `run-nmap.sh`.

OpenSSH 10.6 splits authentication and session handling into separate executables.
Use the included `run-sshd.sh` to resolve those helpers from the extracted archive,
or install them at the paths configured in `sshd_config` with `SshdAuthPath` and
`SshdSessionPath`.

Optional integrations that reduce portability are disabled:

- GDB is built without Python, Guile, TUI, debuginfod, source-highlight, and LZMA.
- socat is built without readline.
- OpenSSH is built without PAM, SELinux, Kerberos, and libedit.
- tcpreplay uses libpcap injection without optional libdnet, AF_XDP, or io_uring
  backends.

The separate Visual Studio Nmap workflow is a Windows build and is not covered by
the Linux static-link guarantees above.

## Local build

The CI container is the reference build environment. For example, an x86_64
tcpdump build can be reproduced from the repository root with:

```sh
docker run --rm \
  -e GITHUB_WORKSPACE=/workspace \
  -v "$PWD:/workspace:ro" \
  -v "$PWD/out/build:/build" \
  -v "$PWD/out/release:/output" \
  -v "$PWD/out/packages:/packaged" \
  -w /workspace \
  muslcc/x86_64:x86_64-linux-musl@sha256:173c042a23a544defa3364d4472b30b36af1d827a74cd8dab7683b8500004334 \
  sh -lc 'sh build/01_init.sh && bash build/targets/build_tcpdump.sh x86_64'
```

Run the matching `build/validate.sh` and `build/package.sh` commands after the build,
as shown in `.github/workflows/reusable-build-linux.yml`.
