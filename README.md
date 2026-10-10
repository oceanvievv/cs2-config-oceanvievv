# cs2-config-oceanvievv

Run **cs2-config.exe**, choose **Apply profile**, then choose a profile explicitly. Review the settings and select **Apply**.

Close CS2 before applying or capturing settings. Sign in to Steam first. Applying a profile creates missing settings folders; no preliminary CS2 launch is required.

## Profiles

- **Домашний**: [console commands](console/profile-%D0%94%D0%BE%D0%BC%D0%B0%D1%88%D0%BD%D0%B8%D0%B9-d185ed7c.txt)
- **Клубный**: [console commands](console/profile-%D0%9A%D0%BB%D1%83%D0%B1%D0%BD%D1%8B%D0%B9-74f7c583.txt)

## Update a profile

Change settings in CS2 or launch options in Steam, exit CS2, run **cs2-config.exe**, choose **Update profile**, and select the profile to update. Review the changes and choose **Save changes**. Only the selected profile is replaced. No previous versions are retained.

## Create a profile

Run **cs2-config.exe** and choose **Create profile** in the main menu. Enter any unique name, review the settings and destination, then choose **Create profile**.

## Rename the config

Choose **Rename config** in the main menu and enter a new name. The config name is
updated in the saved data, executable, README headings and window title. Profile
names and settings, the folder and the GitHub repository remain unchanged.

Choose **Rename profile**, select a profile and enter its new name to rename only
that profile. Its settings stay unchanged; console file links are updated.

## Launch options

The profile stores the exact launch options read from Steam. After applying, paste the displayed line into **Steam > CS2 > Properties > General > Launch Options**. An empty line means clearing that field. Launch options are a manual step.

If the requested fullscreen refresh rate exceeds the maximum available at the profile's resolution, the utility uses that maximum and reports the adjustment. The saved profile is unchanged. Explicit refresh arguments in the displayed launch-options line are adjusted for this application too. Unavailable resolutions are skipped.

## Console alternative

Open the command file for your profile above. Paste its commands into the CS2 console in small batches, then check your settings in CS2.

Supported settings: crosshair, mouse, audio and controls.

## Files and results

**profiles.json** is the editable source for this config. Keep it beside the executable. The executable also contains all profiles, so a downloaded **cs2-config.exe** can run on its own. Rebuilding updates the executable and console files. Saved and checked means the values were verified on disk; check the actual result after starting CS2. Skipped settings and write failures are listed separately.

## Publish or update on GitHub

Open your config repository, choose **Add file > Upload files**, upload the updated folder contents and choose **Commit changes**. Download a fresh **cs2-config.exe** on another PC; previously downloaded files keep their embedded settings.

## Config notes

System.Collections.Specialized.OrderedDictionary
System.Collections.Specialized.OrderedDictionary
