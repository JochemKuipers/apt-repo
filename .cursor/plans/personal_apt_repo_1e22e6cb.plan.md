---
name: Personal APT repo
overview: This repo is only the signed APT site. Howdy-Next and adguard-tray keep building .debs and upload GitHub Releases; skills-manager is downloaded from upstream. No packaging trees are copied here.
todos:
  - id: strip-howdy
    content: "Howdy-Next: remove reprepro/Pages/signing; keep Docker .deb build; upload the .deb as a GitHub Release; README points at jochemkuipers.github.io/apt"
    status: pending
  - id: strip-adguard
    content: "adguard-tray: remove APT Pages/reprepro/install.sh/index.html/GPG publish; keep build + GitHub Release of the .deb; README points at the combined APT source"
    status: pending
  - id: fetch-debs
    content: "This repo: one fetch script that downloads latest howdy-next-apt and adguard-tray GitHub Release .debs plus xingkongliang/skills-manager_*_{amd64,arm64}.deb"
    status: pending
  - id: publish-script
    content: "scripts/publish-apt.sh: merge pool + fetched debs, reprepro, one Signed-By jochem.sources, index.html, push gh-pages"
    status: pending
  - id: apt-workflow
    content: One workflow in this repo (schedule + dispatch) that fetches all debs and publishes Pages
    status: pending
  - id: readme
    content: Root README is only how to add https://jochemkuipers.github.io/apt and apt install the three packages
    status: pending
isProject: false
---

# Combined personal APT repository

This workspace becomes a **thin aggregator**. It does not contain howdy-next or adguard-tray packaging, and it does not need a skills-manager package tree. It downloads `.deb` files and publishes one signed GitHub Pages APT repo.

- GitHub: [JochemKuipers/apt](https://github.com/JochemKuipers/apt)
- Pages: `https://jochemkuipers.github.io/apt`

```mermaid
flowchart LR
  howdyRepo["howdy-next-apt: build only"]
  adguardRepo["adguard-tray: build only"]
  skillsUp["xingkongliang/skills-manager"]
  howdyRel["GitHub Release .deb"]
  adguardRel["GitHub Release .deb"]
  skillsDeb["GitHub Release .deb"]
  aptRepo["JochemKuipers/apt"]
  pages["jochemkuipers.github.io/apt"]
  howdyRepo --> howdyRel
  adguardRepo --> adguardRel
  skillsUp --> skillsDeb
  howdyRel --> aptRepo
  adguardRel --> aptRepo
  skillsDeb --> aptRepo
  aptRepo --> pages
```



## This repo (skills-manager-apt → JochemKuipers/apt)

Layout:

```
scripts/fetch-debs.sh      # gh/curl latest .debs into out/
scripts/publish-apt.sh     # reprepro from out/ + existing pool
.github/workflows/publish.yml
README.md
```

`fetch-debs.sh` downloads:

- `gh release download -R JochemKuipers/howdy-next-apt` (latest `howdy-next_*.deb`)
- `gh release download -R JochemKuipers/adguard-tray` (latest `adguard-tray_*.deb`)
- `https://github.com/xingkongliang/skills-manager/releases/latest` assets `skills-manager_*_amd64.deb` and `*_arm64.deb` when they exist

No `packages/` directory. No rebuild of Howdy OpenCV here.

One workflow: schedule (daily is enough) + `workflow_dispatch`. Fetch → reprepro → deploy `gh-pages`. Skip republish if every fetched filename is already in `pool/`.

`publish-apt.sh` clones existing `gh-pages`, unions `pool/**/*.deb` with newly fetched debs, builds a fresh reprepro tree (drop `db/` and `conf/` from the published site), writes `jochem.sources` with embedded `Signed-By`, keyring, `.nojekyll`, `index.html`. Origin `Jochem Kuipers`, suite `stable`, archs `amd64 arm64`.

No `install.sh`. One DEB822 source file.

Secrets on `JochemKuipers/apt`: `APT_SIGNING_KEY`, `APT_SIGNING_KEY_PASSPHRASE` (reuse Howdy’s key or make a new “Jochem APT” key).

## Howdy-Next ([/home/jochem/Projects/Howdy-Next](/home/jochem/Projects/Howdy-Next))

Keep: `debian/`, Docker `ci-build.sh`, dep build scripts, weekly/dispatch build.

Delete / stop using:

- [scripts/publish-apt.sh](/home/jochem/Projects/Howdy-Next/scripts/publish-apt.sh)
- Pages deploy (`upload-pages-artifact`, `deploy-pages`, `pages: write`)
- Signing env (`APT_SIGNING_KEY`, keyring, `.sources` generation)
- `keyring.asc` if it is only for the old APT repo

Add: after a successful build, `softprops/action-gh-release` (or `gh release create`) with `out/howdy-next_*.deb` so this aggregator can fetch it. Howdy currently has no GitHub Releases.

README install section: point at `https://jochemkuipers.github.io/apt`. Keep the PAM / camera notes.

## adguard-tray ([/home/jochem/Projects/adguard-tray](/home/jochem/Projects/adguard-tray))

Keep: `debian/`, `packaging/fetch-upstream.sh`, `packaging/build-deb.sh`, `packaging/sync-upstream.sh`, changelog bump, lintian, **GitHub Release of the `.deb`** (already exists).

Delete:

- [packaging/publish-apt-repo.sh](/home/jochem/Projects/adguard-tray/packaging/publish-apt-repo.sh)
- [packaging/index.html](/home/jochem/Projects/adguard-tray/packaging/index.html)
- [install.sh](/home/jochem/Projects/adguard-tray/install.sh) (old Pages APT installer)
- GPG import + clone `gh-pages` + `peaceiris/actions-gh-pages` from [release.yml](/home/jochem/Projects/adguard-tray/.github/workflows/release.yml)
- APT signing secret docs in [packaging/README.md](/home/jochem/Projects/adguard-tray/packaging/README.md)

README: install via the combined APT source, not `curl | bash` against `jochemkuipers.github.io/adguard-tray`.

## After code lands (you)

1. Create empty GitHub repo `JochemKuipers/apt`, add signing secrets, Pages from `gh-pages`.
2. Push Howdy-Next / adguard-tray changes; run their build workflows so GitHub Releases exist.
3. Push this aggregator; run **Publish** once.
4. On machines:

```sh
curl -fsSL https://jochemkuipers.github.io/apt/jochem.sources \
  | sudo tee /etc/apt/sources.list.d/jochem.sources
sudo apt update
sudo apt install howdy-next adguard-tray skills-manager
```

Remove the old howdy-next / adguard-tray APT sources. Leave those GitHub repos in place as builders.