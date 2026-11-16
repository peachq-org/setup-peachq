# setup-peachq

Install [peachq](https://github.com/peachq-org/peachq) in CI: a pinned release, checksum-verified, with the absolute
path of its `q` exported as `QCMD` and `PEACHQ_Q`.

peachq is an open-source (MIT) q. Because anyone may download and run it, a GitHub-hosted runner can use it to run a
q project's checks. For a ready-made template that uses this action, see
[peachq-starter](https://github.com/peachq-org/peachq-starter).

## Use the action

```yaml
- uses: peachq-org/setup-peachq@<full commit sha>   # pin by SHA, as for any third-party action
  with:
    version: 0.92.20261115
- run: $QCMD tests/run.q
```

| input | | |
|---|---|---|
| `version` | required | An exact build such as `0.92.20261115` (recommended), a release tag such as `v0.92`, or `latest`. There is no default, so the engine changes only when a commit changes it. |
| `dist-url` | optional | Download from `https://peachq.org/file`, or from your own mirror of it, instead of GitHub Releases (see below). |
| `add-to-path` | optional, `false` | Also put peachq on `PATH` as `q`. Off by default, so no script that runs plain `q` mistakes peachq for another q. |

| output / env | |
|---|---|
| `q-path` output, `QCMD` and `PEACHQ_Q` env | Absolute path of the installed `q`. |
| `version` output | The installed build, as `.pq.version` reports it. |

**Linux by default.** Run your checks on `ubuntu-latest`. Add `macos-latest` if you ship on Mac. Builds exist for Linux
x86_64, Linux arm64 and macOS arm64 runners. An exact build is cached (`actions/cache`, keyed by version, OS,
architecture and download source). A tag or `latest` can move, so it is downloaded every time.

### Exact builds and release tags

A version such as `0.92.20261115` names one build. The installer looks for a release tagged `v0.92.20261115` first,
then for `v0.92`, and refuses to install unless the `q` it unpacked reports exactly `0.92.20261115`. If a release
tag has since been rebuilt, the job fails and tells you which build the tag holds now. It never runs a different
build without saying so.

## Without the action: download from peachq.org

You need no action and no installer: every build is a plain download from peachq.org with a checksum beside it.

```sh
curl -fsSLO https://peachq.org/file/peachq-v0.92.20261116-linux-x86_64.tar.gz{,.sha256}
sha256sum -c peachq-v0.92.20261116-linux-x86_64.tar.gz.sha256
tar -xzf peachq-v0.92.20261116-linux-x86_64.tar.gz      # holds q, LICENSE, NOTICE, README.md
```

The files are `https://peachq.org/file/peachq-v<VERSION>-<platform>.tar.gz` (`.zip` for Windows), each with
`<name>.sha256` beside it. The platforms are `linux-x86_64`, `linux-arm64`, `linux-x86_64-glibc`, `linux-arm64-glibc`,
`darwin-arm64` and `windows-x86_64`. Note that the site says `darwin` where GitHub Releases say `macos`.

`.sha256` files in `sha256sum -c` format start with the next release. Builds up to v0.92 are named
`peachq-v0.92.0-…`, and their `.sha256` holds only the hash, so check them with
`echo "$(cat f.sha256)  f" | sha256sum -c -`.

**Latest.** `https://peachq.org/file/latest.json` names the newest build of each platform:
`{version, uploaded, files: {linux: {name, bytes, sha256}, …}}`. To fetch and check the latest Linux build:

```sh
curl -fsSL https://peachq.org/file/latest.json | jq -r '.files.linux | "\(.sha256)  \(.name)"' > peachq.sha256
curl -fsSLO "https://peachq.org/file/$(cut -d' ' -f3 peachq.sha256)" && sha256sum -c peachq.sha256
```

**Provenance.** An attestation binds the archive's digest, not its URL. So `gh attestation verify <file> -R
peachq-org/peachq` works on a peachq.org download just as on a GitHub one. This holds for releases from the first
dated cut onward; earlier builds have no attestation.

## Without the action: install.sh

Some organisations allow only approved actions. `install.sh` is the whole installer and needs only bash, curl, tar and
`sha256sum` or `shasum`. Run it from a pinned commit, or copy it into your repository:

```yaml
- name: install peachq
  run: |
    curl -fsSL -o install.sh https://raw.githubusercontent.com/peachq-org/setup-peachq/<full commit sha>/install.sh
    echo "<sha256 of that install.sh>  install.sh" | sha256sum -c -
    q=$(bash install.sh --version 0.92.20261115 --dir "$RUNNER_TEMP/peachq")
    echo "QCMD=$q" >> "$GITHUB_ENV"
```

```text
install.sh [--version V] [--dir D]
  V   0.92.20261115 (exact build), v0.92 (release tag) or latest       env PEACHQ_VERSION
  D   install directory (default ~/.peachq/<V>/<platform>)            env PEACHQ_INSTALL_DIR
env PEACHQ_DIST_URL   download from https://peachq.org/file, or a mirror with its flat layout
                      (<url>/peachq-v<version>-<platform>.tar.gz + .sha256), instead of GitHub Releases
env PEACHQ_PLATFORM   linux-x86_64 | linux-arm64 | macos-arm64 (default: this machine)
```

The path of `q` is the only thing it prints to stdout. Messages go to stderr.

## Sources: GitHub Releases, peachq.org, your own mirror

GitHub Releases are the default. Set `dist-url` (or `PEACHQ_DIST_URL`) to `https://peachq.org/file` to download from
the site instead. To use an internal artifact store, set it to a mirror with the site's flat layout:

```text
https://artifacts.example.com/peachq/peachq-v0.92.20261116-linux-x86_64.tar.gz
https://artifacts.example.com/peachq/peachq-v0.92.20261116-linux-x86_64.tar.gz.sha256
https://artifacts.example.com/peachq/latest.json          # only if you want `latest`
```

Copy the files unchanged. A release tag `v0.92` is looked up as the file `peachq-v0.92.0-…`. An exact build is tried
under its own name first, then under its release's name.

## Verification

- **Checksum.** The `.sha256` published beside each archive must match, or nothing is installed. A missing checksum
  file is an error.
- **Build provenance.** When `gh` has the `attestation` command and is signed in (on GitHub-hosted runners the action
  passes it the job token), the installer asks GitHub for the archive's build attestation. This works whichever
  source the archive came from. If the release has one, `gh attestation verify --repo peachq-org/peachq` must pass.
  Releases up to v0.92 were published before attestations, so for those it prints a notice and relies on the
  checksum.
- **The build itself.** The unpacked `q` must start and report its version before it is installed. Installs are
  unpacked to a temporary directory and moved into place, so an interrupted install leaves nothing behind. A
  directory that holds anything other than a peachq install is never replaced.

Transient network errors are retried. A missing build names the version and every URL tried.

## Licence

MIT, see [LICENSE](LICENSE).
