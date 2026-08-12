# CS2 config

oceanvievv — CS2 config packed by [cs2-config](https://github.com/oceanvievv/cs2-config).

## Installing the config on another PC

Use the first option that works there.

### 1. Double-click `apply-config.cmd`

Needs PowerShell. The easy one: you already have this folder, off a USB stick or a
download. It asks what to do — apply everything, apply configs only, check what differs,
or undo.

### 2. One command

Needs PowerShell and internet. For a PC that has nothing on it yet:

```powershell
iwr -useb https://raw.githubusercontent.com/<you>/<repo>/main/apply-config.cmd -OutFile "$env:TEMP\cs2.cmd"; & "$env:TEMP\cs2.cmd" -Video
```

### 3. PowerShell blocked

Needs only Explorer. Copy the files from `cfg\` into:

```
...\steamapps\common\Counter-Strike Global Offensive\game\csgo\cfg\
```

That is all the installer does.

### 4. No file access at all

Needs only the game. `apply-config-using-console.txt` is one line of console commands and
nothing else: open it, select all, copy, paste into the CS2 console, Enter. Once.

Turn the console on first: Settings > Game > Enable Developer Console = Yes. It opens with
the ~ key.

Not an equal substitute: configs and crosshair only. No video settings, no
`cloud-backup`, nothing written to disk, no undo. Configs you run from a key are left out
of the line as well — pasting one would change the server you are on rather than your
settings. Crosshair, sensitivity and binds do survive a restart, because CS2 saves those
convars on exit. Server settings like `sv_cheats` do not.

## apply-config switches

`apply-config.cmd` offers these as a menu. Pass one on the command line and the menu is
skipped.

| switch | what it does |
|---|---|
| `-Video` | also apply resolution and quality |
| `-Convars` | restore sensitivity and binds from `cloud-backup\`. Only if Steam Cloud failed. Close CS2 and Steam first |
| `-Check` | show what differs, write nothing |
| `-Undo` | put the PC back the way you found it |

## Launch options

Steam > CS2 > Properties > General.

Portable version, safe on unknown hardware:

```
+fps_max 0 -forcenovsync -nojoy -novid +engine_low_latency_sleep_after_client_tick true -language english
```

Your full version, for home:

```
+fps_max 0 -high -forcenovsync -softparticlesdefaultoff +mat_disable_fancy_blending 1 -nojoy -threads 8 -novid +engine_low_latency_sleep_after_client_tick true -language english
```

Dropped, because they do not travel well:

- `-high` — high priority can starve audio and input on a faster CPU
- `-softparticlesdefaultoff` — lowers quality to gain fps you may not need
- `+mat_disable_fancy_blending 1` — lowers quality to gain fps you may not need
- `-threads 8` — thread count is specific to this CPU

## What is in here

```
apply-config.cmd                 applies the settings; your configs are embedded in it
apply-config-using-console.txt   one line to paste into the console, see option 4
update-config.cmd                re-reads your settings and rebuilds this folder
cfg\autoexec.cfg                 runs automatically on startup
cfg\crosshair.cfg                your crosshair, no share code needed
cfg\knife.cfg
cfg\oceanvievv.cfg               your main config
cfg\training.cfg
video\cs2_video.txt              resolution and quality
cloud-backup\cs2_user_convars_0_slot0.vcfg  what Steam Cloud normally brings
cloud-backup\cs2_user_keys_0_slot0.vcfg  what Steam Cloud normally brings
```

The crosshair is applied as convars. There is no share code to paste.

`cloud-backup\` is a copy of what Steam Cloud normally delivers. You usually never need
it: logging into Steam brings your sensitivity, crosshair and binds down by itself.

## The config in the cloud

Git is not needed. This is all done in a browser.

**Putting the config in the cloud**

1. Sign in at github.com
2. Create a public repository (`cs2-config`, for example)
3. On the page that opens, click **uploading an existing file**
4. Drag the contents of this folder onto the page
5. Click **Commit changes**

**Updating the config in the cloud**

1. Open the repository holding your config
2. Click `Add file` and pick `Upload files`
3. Drag the contents of this folder onto the page
4. Click **Commit changes**

Then fix up the one-line install at the top of this file: replace <you> and <repo> with
your GitHub name and the repo you just created.

## Updating the config

Changed your settings in the game? Run `update-config.cmd`. Before you travel, not after.

---

Built with cs2-config 1.6.2 — https://github.com/oceanvievv/cs2-config