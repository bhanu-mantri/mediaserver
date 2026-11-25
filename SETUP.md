# Media Server Setup

| App | URL | Purpose |
|---|---|---|
| Seerr (formerly Jellyseerr) | http://localhost:5055 | Search & request movies/TV/anime |
| Jellyfin | http://localhost:8096 | Watch |
| Radarr | http://localhost:7878 | Movies |
| Sonarr | http://localhost:8989 | TV + anime |
| Prowlarr | http://localhost:9696 | Indexers (public + private) |
| qBittorrent | http://localhost:8080 | Downloads (through Surfshark) |
| Bazarr | http://localhost:6767 | Subtitles |
| Whisparr | http://localhost:6969 | Adult (v3: movies + scenes) — not in Seerr, add titles here |

**Inside the apps, always use container names, not `localhost`** (e.g. `http://radarr:7878`).
qBittorrent and FlareSolverr live inside the VPN container, so their addresses are `http://gluetun:8080` / `http://gluetun:8191`.
If gluetun is ever recreated/restarted, run `docker compose up -d --force-recreate qbittorrent flaresolverr`.

Folders (all apps see `C:\...\mediaserver\data` as `/data`):
```
/data/torrents/movies   /data/torrents/tv     <- downloads
/data/media/movies      /data/media/tv        <- libraries
```

---

## 1. VPN + qBittorrent
1. Surfshark key: my.surfshark.com -> VPN -> Manual setup -> Router -> **WireGuard** ->
   "I don't have a key pair" -> generate -> copy the **private key** into `.env` (`WIREGUARD_PRIVATE_KEY=`).
2. `docker compose up -d` (gluetun also runs an internal HTTP proxy on :8888 used by Prowlarr)
3. Verify VPN: `docker logs gluetun` should show `Public IP address is ... (Netherlands ...)`.
   Double-check: `docker exec gluetun wget -qO- https://ipinfo.io` must NOT show your home IP.
4. qBittorrent — DONE via API: user `admin`, password = `QBIT_PASSWORD` in `.env`;
   save path `/data/torrents`, Automatic Torrent Management on, categories `movies` -> `/data/torrents/movies`,
   `tv` -> `/data/torrents/tv`; ratio limit 1.0 then stop; network interface `tun0`.
   To change the password: put the new one in `.env` (`QBIT_PASSWORD`) and ask Claude to apply it — it resets qBittorrent
   to that value and updates Radarr + Sonarr. (Changing it only in the UI breaks Radarr/Sonarr and risks a 1-hour login ban.)
   qBittorrent writes settings to disk lazily — after changing settings, `docker restart qbittorrent` to be safe.

## 2. Prowlarr (:9696) — DONE (configured via API), except auth + private trackers
The ISP blocks many torrent sites, so **all Prowlarr traffic goes through Surfshark**:
- Settings -> General -> Proxy: HTTP `gluetun:8888` (Gluetun's built-in proxy), bypass
  `radarr,sonarr,gluetun,flaresolverr,jellyfin,jellyseerr,localhost` + local addresses.
- FlareSolverr runs inside the VPN container: indexer proxy host `http://gluetun:8191/`, tag `flaresolverr`.
- Apps: Radarr (`http://radarr:7878`) and Sonarr (`http://sonarr:8989`), Full Sync, server `http://prowlarr:9696`.
- Public indexers: YTS, The Pirate Bay, Knaben, LimeTorrents, TorrentDownload, Nyaa.si, SubsPlease, EZTV (eztv.tf mirror,
  tag `flaresolverr`), 1337x (tag `flaresolverr`).
  Radarr rejects TPB/LimeTorrents/SubsPlease/EZTV ("no results in configured categories" — no movie RSS); that's expected.

Login: Forms auth with `ARR_USERNAME` / `ARR_PASSWORD` from `.env` (same for Prowlarr, Radarr, Sonarr) — DONE.

Still to do by hand:
1. Indexers -> Add Indexer -> search your private tracker -> fill API key / passkey / cookie -> Test -> Save.
   If a tracker shows a Cloudflare error, add the `flaresolverr` tag.
   If a tracker forbids VPN IPs for site/API access, tell Claude — it can be excluded from the proxy.

## 3. Radarr (:7878) and Sonarr (:8989) — DONE via API, except auth + Jellyfin connect
Configured: root folders (`/data/media/movies`, `/data/media/tv`), renaming on, subtitle files imported,
qBittorrent client (`gluetun:8080`, categories `movies`/`tv`, remove completed after seeding). Health: all OK.
Test: *Night of the Living Dead* (1968) added to Radarr and downloading.

Login: Forms auth with `ARR_USERNAME` / `ARR_PASSWORD` from `.env` — DONE.
To change it: edit `.env` and ask Claude to re-apply (Settings -> General -> Security in each app otherwise).

Remaining:
2. ~~Jellyfin connect~~ DONE: Settings -> Connect -> Jellyfin (`jellyfin:8096`, key = `JELLYFIN_API_KEY` in `.env`, Update Library).
3. Optional: Settings -> Quality -> lower the max size per quality to avoid 10+ GB downloads.
4. Anime: series type **Anime** — Jellyseerr sets this automatically (see below).

## 4. Jellyfin (:8096) — DONE
Wizard done; libraries **Movies** -> `/data/media/movies`, **Shows** -> `/data/media/tv` (metadata en / IN);
API key stored as `JELLYFIN_API_KEY` in `.env`.
4. Apps for TV/phone: install "Jellyfin" and point it at `http://<this-PC's-LAN-IP>:8096`.

## 5. Seerr (:5055)
Jellyseerr 2.7.x is deprecated and can't authenticate against Jellyfin 12 (`request.App` null -> HTTP 400),
so the stack uses its successor **Seerr** (`ghcr.io/seerr-team/seerr`, container `seerr`, config `config\seerr`).
DONE: signed in via `scripts\seerr-signin.ps1` (the web form kept sending `localhost`); libraries, Radarr, Sonarr
(anime -> `/data/media/tv`, auto "anime" series type), setup initialized — all via API. Original manual steps for reference:
1. Choose **Jellyfin** -> hostname **`jellyfin`** (NOT localhost), port 8096, sign in with your Jellyfin admin.
2. Sync libraries, enable Movies + Shows.
3. Services -> add Radarr (`radarr`, 7878, API key, profile, root `/data/media/movies`) — tick **Default**.
4. Services -> add Sonarr (`sonarr`, 8989, API key, profile, root `/data/media/tv`, anime root `/data/media/tv`,
   anime series type **Anime**) — tick **Default**, enable **Season folders**.
5. Users -> your user -> grant **Auto-Approve** so requests go straight to downloading.

## 5b. Whisparr (:6969) — DONE via API
Image `ghcr.io/hotio/whisparr:v3` (Radarr-based). Root `/data/media/adult`, qBittorrent category `adult` ->
`/data/torrents/adult`, renaming on, Kodi/Emby NFO + images (so Jellyfin shows titles/posters), Jellyfin connect,
login = `ARR_USERNAME`/`ARR_PASSWORD`. Prowlarr app added (Full Sync).
Adult indexers: PornRips, MyPornClub, PornXLab, sukebei.nyaa.si, Uindex (+ existing 1337x, Knaben, TPB).
XXXClub skipped (Cloudflare beats FlareSolverr). Jellyfin library **Adult** -> `/data/media/adult` (not enabled in Seerr).
Seerr can't request adult content — search & add in Whisparr directly.
If you add other Jellyfin users: Dashboard -> Users -> <user> -> Access -> untick "Enable access to all libraries"
and leave **Adult** unticked.

## 6. Bazarr (:6767) — DONE via API
- Connected to Radarr (`radarr:7878`) and Sonarr (`sonarr:8989`) via API keys.
- Language profile **English** (id 1), applied by default to all movies and series (existing + new).
- Providers (no account needed): Embedded subtitles, YIFY Subtitles, Subtitlecat, TVsubtitles, Animetosho (anime).
  Podnapisi was dropped — its domain no longer resolves.
- Jellyfin refresh after each subtitle download (`jellyfin:8096`, Movies + Shows libraries).
- Login = `ARR_USERNAME` / `ARR_PASSWORD`.
- Test: *Night of the Living Dead* — already has 2 embedded English tracks; manual search found 13 candidates.
- Later: add OpenSubtitles.com (free account) under Settings -> Providers for much better coverage.

## 7. Test — PASSED (2026-11-20)
*Night of the Living Dead* (1968): Radarr -> Knaben -> qBittorrent (via Surfshark) -> imported to
`/data/media/movies/...` -> visible in Jellyfin -> Seerr status **Available**.

Request a public-domain film (e.g. *Night of the Living Dead* 1968) in Jellyseerr ->
see it in Radarr (Activity) -> qBittorrent -> imported to /data/media/movies -> plays in Jellyfin ->
Jellyseerr shows **Available**.

---

## Notes
- **Surfshark has no port forwarding.** Downloading works fine, but you'll be less "connectable" on private trackers
  (slower seeding/ratio building). If a tracker requires connectability, consider a provider with port forwarding.
- **Private trackers**: read each tracker's rules (VPN allowed? minimum seed time/ratio?) and set the seeding limits to match.
- Windows bind mounts can't hardlink, so imports *copy* files; seeded torrents temporarily use double space.
  Lower seeding limits or delete finished torrents to reclaim space.
- Start on boot: Docker Desktop -> Settings -> General -> "Start Docker Desktop when you sign in". Containers use `restart: unless-stopped`.
- Back up `config\` (holds all app settings). Never share `.env`.
- Update: `docker compose pull; docker compose up -d`
- Remote access: use Tailscale rather than opening router ports.
- Only download content you have the right to.
