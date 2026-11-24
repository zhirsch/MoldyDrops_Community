# MoldyDrops_Community

Community drop data for [MoldyDrops](https://github.com/zhirsch/MoldyDrops), the World of Warcraft: Forever addon that shows drop chances in mob tooltips. This addon bundles the latest snapshot from the MoldyDrops website: loot recorded by MoldyDrops players and combined there. MoldyDrops uses it for a mob once it covers enough kills.

## Install

Copy the `MoldyDrops_Community` folder into `World of Warcraft\_forever_\Interface\AddOns\`, next to `MoldyDrops`, which it needs.

Between releases, you can load a newer snapshot in the game. Click "Copy latest data" on the website, type `/drops import`, paste, and click Import. The newer of the bundled and the imported snapshot is used, so the next release of this addon replaces an older import.

## Releasing a new snapshot

1. Get the snapshot: click "Copy latest data" on the website and save it to a file, or use the website's `/api/snapshot` URL.
2. Bundle it:

   ```powershell
   .\tools\Update-Snapshot.ps1 -Path snapshot.txt
   ```

   That rewrites `Snapshot.lua`, after checking that the string is a snapshot.
3. Commit `Snapshot.lua`, then push an annotated tag, for example the date:

   ```powershell
   git tag -a 2026.11.24 -m "Community data, 24 November 2026"
   git push origin 2026.11.24
   ```

The tag triggers the [BigWigs packager](https://github.com/BigWigsMods/packager) (`.pkgmeta`, `.github/workflows/release.yml`). It builds `MoldyDrops_Community-<tag>.zip` and attaches it to a GitHub release. To also upload to CurseForge, WoWInterface or Wago, add the project's ID to `MoldyDrops_Community.toc` (`## X-Curse-Project-ID:`, `## X-WoWI-ID:`, `## X-Wago-ID:`) and its token as a repository secret (`CF_API_KEY`, `WOWI_API_TOKEN`, `WAGO_API_TOKEN`).

## License

GPL-3.0-or-later, like MoldyDrops.
