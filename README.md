# setup-peachq

Install [peachq](https://github.com/peachq-org/peachq) in CI: a pinned release, checksum-verified, with the absolute
path of its `q` exported as `QCMD` and `PEACHQ_Q`.

peachq is an open-source (MIT) q. Because anyone may download and run it, a GitHub-hosted runner can use it to run a
q project's checks. For a ready-made template that uses this action, see
[peachq-starter](https://github.com/peachq-org/peachq-starter).

## Use the action

```yaml
- uses: peachq-org/setup-peachq@v1.1.0
  with:
    version: 0.92.20261116
- run: $QCMD tests/run.q
```

Releases are immutable, so `v1.1.0` always names the same commit; orgs that require commit pinning can use its SHA.

| input | | |
|---|---|---|
| `version` | required | An exact build such as `0.92.20261116` (recommended), a release tag such as `v0.92`, or `latest`. There is no default, so the engine changes only when a commit changes it. |
| `dist-url` | optional | Download from `https://peachq.org/file`, or from your own mirror of it, instead of GitHub Releases (see below). |
| `add-to-path` | optional, `false` | Also put peachq on `PATH` as `q`. Off by default, so no script that runs plain `q` mistakes peachq for another q. |
| `args` | optional | With `add-to-path: true`, extra arguments the `q` on `PATH` appends after the caller's, such as `-classic` (see below). |

| output / env | |
|---|---|
| `q-path` output, `QCMD` and `PEACHQ_Q` env | Absolute path of the installed `q`. |
| `version` output | The installed build, as `.pq.version` reports it. |

**Linux by default.** Run your checks on `ubuntu-latest`. Add `macos-latest` or `windows-latest` if you ship there.
Builds exist for Linux x86_64, Linux arm64, macOS arm64 and Windows x86_64 runners. An exact build is cached (`actions/cache`, keyed by version, OS,
architecture and download source). A tag or `latest` can move, so it is downloaded every time.

### Projects whose own scripts call `q`

peachq prints kdb+'s text only with `-classic`, and a script that starts `q` itself cannot pass it. With
`add-to-path: true` and `args: -classic`, the `q` on `PATH` is a two-line shim that runs peachq with the caller's
arguments and then `args`, so `q tests/run.q -p 5000` runs `peachq tests/run.q -p 5000 -classic` (the script must come
first, so the extra arguments go last). `args` is split on whitespace into separate arguments, with no quoting or
globbing, so an argument cannot contain a space. `QCMD` and `PEACHQ_Q` still name the real binary.

### Windows

On `windows-latest`, `QCMD`, `PEACHQ_Q` and `q-path` are the Windows path of `q.exe`, such as
`C:\hostedtoolcache\windows\peachq\…\q.exe`. That path launches from bash (`"$QCMD"`), PowerShell (`& $env:QCMD`), cmd
(`"%QCMD%"`) and a JVM (`new ProcessBuilder(System.getenv("QCMD"), …)`). With `add-to-path: true`, plain `q` works in
all three shells. With `args`, the shim is `q` for bash and `q.cmd` for cmd and PowerShell. A cmd script must run it as
`call q …`, as with any `.cmd`. On Windows an `args` word cannot contain a double quote.

### Exact builds and release tags

A version such as `0.92.20261116` names one build. The installer looks for a release tagged `v0.92.20261116` first,
then for `v0.92`, and refuses to install unless the `q` it unpacked reports exactly `0.92.20261116`. If a release
tag has since been rebuilt, the job fails and tells you which build the tag holds now. It never runs a different
build without saying so. That is how `0.92.20261115`, which has no release of its own, installs from `v0.92`.

## Without the action: download from peachq.org

You need no action and no installer: every build is a plain download. Releases are immutable, so the URL is the pin.

```sh
curl -fsSL https://peachq.org/file/peachq-v0.92.20261116-linux-x86_64.tar.gz | tar -xz    # q, LICENSE, NOTICE, README.md
```

The files are `https://peachq.org/file/peachq-v<VERSION>-<platform>.tar.gz` (`.zip` for Windows). The platforms are
`linux-x86_64`, `linux-arm64`, `linux-x86_64-glibc`, `linux-arm64-glibc`, `darwin-arm64` and `windows-x86_64`. Note
that the site says `darwin` where GitHub Releases say `macos`. The same works against GitHub Releases:

```sh
curl -fsSL https://github.com/peachq-org/peachq/releases/download/v0.92.20261116/peachq-linux-x86_64.tar.gz | tar -xz
```

**Latest.** `https://peachq.org/file/latest.json` names the newest build of each platform:
`{version, uploaded, files: {linux: {name, bytes, sha256}, …}}`.

```sh
curl -fsSL "https://peachq.org/file/$(curl -fsSL https://peachq.org/file/latest.json | jq -r .files.linux.name)" | tar -xz
```

**Provenance.** To check where a build came from, save the archive and run `gh attestation verify <file> -R
peachq-org/peachq` (builds from `0.92.20261116` on; it works on a peachq.org download just as on a GitHub one).

## Without the action: install.sh

Some organisations allow only approved actions. `install.sh` is the whole installer and needs only bash, curl, tar (unzip on
Windows) and `sha256sum` or `shasum`. On Windows it runs in Git Bash, which has all of them. Run it from a release, or copy it into your repository:

```yaml
- name: install peachq
  run: |
    q=$(curl -fsSL https://raw.githubusercontent.com/peachq-org/setup-peachq/v1.1.0/install.sh |
      bash -s -- --version 0.92.20261116 --dir "$RUNNER_TEMP/peachq")
    echo "QCMD=$q" >> "$GITHUB_ENV"
```

```text
install.sh [--version V] [--dir D]
  V   0.92.20261116 (exact build), v0.92 (release tag) or latest       env PEACHQ_VERSION
  D   install directory (default ~/.peachq/<V>/<platform>)            env PEACHQ_INSTALL_DIR
env PEACHQ_DIST_URL   download from https://peachq.org/file, or a mirror with its flat layout
                      (<url>/peachq-v<version>-<platform>.tar.gz or .zip, + .sha256), instead of GitHub Releases
env PEACHQ_PLATFORM   linux-x86_64 | linux-arm64 | macos-arm64 | windows-x86_64 (default: this machine)
```

The path of `q` (`q.exe` on Windows, as an MSYS path such as `/c/…`) is the only thing it prints to stdout. Messages go to stderr.

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
  source the archive came from. If the release has one, `gh attestation verify --repo peachq-org/peachq` must pass,
  and the log says `setup-peachq: build attestation verified`.
  Releases up to v0.92 were published before attestations, so for those it prints a notice and relies on the
  checksum.
- **The build itself.** The unpacked `q` must start and report its version before it is installed. Installs are
  unpacked to a temporary directory and moved into place, so an interrupted install leaves nothing behind. A
  directory that holds anything other than a peachq install is never replaced.

Transient network errors are retried. A missing build names the version and every URL tried.

## Licence

MIT, see [LICENSE](LICENSE).
