# CS2 config

Packed by [cs2-config](https://github.com/oceanvievv/cs2-config).

## Installing the config on another PC

#### One command using PowerShell
Run PowerShell and paste the following command there:

```powershell
iwr -useb https://raw.githubusercontent.com/<you>/<repo>/main/apply-config.cmd -OutFile "$env:TEMP\cs2.cmd"; & "$env:TEMP\cs2.cmd" -Video
```

#### Installation file
Download the [apply-config.cmd](the link) and launch it.

#### Copy configs manually
Copy the files from `cfg\` into:

```
...\steamapps\common\Counter-Strike Global Offensive\game\csgo\cfg\
```

#### Use CS2 console
Open `apply-config-using-console.txt` and copy everything, then paste into the CS2 console.

Configs and crosshair only.

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
