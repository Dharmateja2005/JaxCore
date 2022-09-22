<#

>>==SCRIPT PARAMETERS==<<
$s_Path                     - path to .shp package

#>

param(
    [Parameter(Mandatory=$true)][Alias("path")][ValidateNotNullOrEmpty()][string]$s_Path,
    [Alias("extracted")][switch]$o_noExtract,
    [Alias("nomove")][switch]$o_noMove
) 

$ErrorActionPreference = 'SilentlyContinue'

# ---------------------------------------------------------------------------- #
#                                   Functions                                  #
# ---------------------------------------------------------------------------- #

# -------------------------------- Write-Host -------------------------------- #

function Write-Task ([string] $Text) {
  Write-Host $Text -NoNewline
}

function Write-Done {
  Write-Host " > " -NoNewline
  Write-Host "OK" -ForegroundColor "Green"
}

function Write-Emphasized ([string] $Text) {
  Write-Host $Text -NoNewLine -ForegroundColor "Cyan"
}

function Write-Info ([string] $Text) {
  Write-Host $Text -ForegroundColor "Yellow"
}

function Write-Fail ([string] $Text) {
  Write-Host $Text -ForegroundColor "Red"
}

function Write-Divider {
    Write-Host "============================================" -BackgroundColor "Gray"
}

function debug ([string] $Text) {
  Write-Host $Text
}

# ------------------------------------ Ini ----------------------------------- #

function Get-IniContent ($filePath) {
    $ini = [ordered]@{}
    if (![System.IO.File]::Exists($filePath)) {
        throw "$filePath invalid"
    }
    # $section = ';ItIsNotAFuckingSection;'
    # $ini.Add($section, [ordered]@{})

    foreach ($line in [System.IO.File]::ReadLines($filePath)) {
        if ($line -match "^\s*\[(.+?)\]\s*$") {
            $section = $matches[1]
            $secDup = 1
            while ($ini.Keys -contains $section) {
                $section = $section + '||ps' + $secDup
            }
            $ini.Add($section, [ordered]@{})
        }
        elseif ($line -match "^\s*;.*$") {
            $notSectionCount = 0
            while ($ini[$section].Keys -contains ';NotSection' + $notSectionCount) {
                $notSectionCount++
            }
            $ini[$section][';NotSection' + $notSectionCount] = $matches[1]
        }
        elseif ($line -match "^\s*(.+?)\s*=\s*(.+?)$") {
            $key, $value = $matches[1..2]
            $ini[$section][$key] = $value
        }
        else {
            $notSectionCount = 0
            while ($ini[$section].Keys -contains ';NotSection' + $notSectionCount) {
                $notSectionCount++
            }
            $ini[$section][';NotSection' + $notSectionCount] = $line
        }
    }

    return $ini
}

function Set-IniContent($ini, $filePath) {
    $str = @()
    foreach ($section in $ini.GetEnumerator()) {
        if ($section -ne ';ItIsNotAFuckingSection;') {
            $str += "[" + ($section.Key -replace '\|\|ps\d+$', '') + "]"
        }
        foreach ($keyvaluepair in $section.Value.GetEnumerator()) {
            if ($keyvaluepair.Key -match "^;NotSection\d+$") {
                $str += $keyvaluepair.Value
            }
            else {
                $str += $keyvaluepair.Key + "=" + $keyvaluepair.Value
            }
        }
    }
    $finalStr = $str -join [System.Environment]::NewLine
    $finalStr | Out-File -filePath $filePath -Force -Encoding unicode
}

# ----------------------------------- Copy ----------------------------------- #

function Copy-Path {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateScript({Test-Path -Path $_ -PathType Container})]
        [string]$Source,

        [Parameter(Position = 1)]
        [string]$Destination,

        [string[]]$ExcludeFolders = $null,
        [switch]$IncludeEmptyFolders
    )
    $Source      = $Source.TrimEnd("\")
    $Destination = $Destination.TrimEnd("\")

    Get-ChildItem -Path $Source -Recurse | ForEach-Object {
        if ($_.PSIsContainer) {
            # it's a folder
            if ($ExcludeFolders.Count) {
                if ($ExcludeFolders -notcontains $_.Name -and $IncludeEmptyFolders) {
                    # create the destination folder, even if it is empty
                    $target = Join-Path -Path $Destination -ChildPath $_.FullName.Substring($Source.Length)
                    if (!(Test-Path $target -PathType Container)) {
                        # Write-Verbose "Create folder $target"
                        New-Item -ItemType Directory -Path $target | Out-Null
                    }
                }
            }
        }
        else {
            # it's a file
            $copy = $true
            if ($ExcludeFolders.Count) {
                # get all subdirectories in the current file path as array
                $subs = $_.DirectoryName.Replace($Source,"").Trim("\").Split("\")
                # check each sub folder name against the $ExcludeFolders array
                foreach ($folderName in $subs) {
                    if ($ExcludeFolders -contains $folderName) { $copy = $false; break }
                }
            }

            if ($copy) {
                # create the destination folder if it does not exist yet
                $target = Join-Path -Path $Destination -ChildPath $_.DirectoryName.Substring($Source.Length)
                if (!(Test-Path $target -PathType Container)) {
                    # Write-Verbose "Create folder $target"
                    New-Item -ItemType Directory -Path $target | Out-Null
                }
                # Write-Verbose "Copy file $($_.FullName) to $target"
                $_ | Copy-Item -Destination $target -Force
            }
        }
    }
}

# ------------------------------ Plugin Version ------------------------------ #

function Get-PluginVersion {
    param(
        $file
    )
    return [System.Version](Get-Item $file).VersionInfo.FileVersion
}

# --------------------------------- Wallpaper -------------------------------- #

function Set-WallPaper($Image) {  
Add-Type -TypeDefinition @" 
using System; 
using System.Runtime.InteropServices;
  
public class Params
{ 
    [DllImport("User32.dll",CharSet=CharSet.Unicode)] 
    public static extern int SystemParametersInfo (Int32 uAction, 
                                                   Int32 uParam, 
                                                   String lpvParam, 
                                                   Int32 fuWinIni);
}
"@ 
  
    $SPI_SETDESKWALLPAPER = 0x0014
    $UpdateIniFile = 0x01
    $SendChangeEvent = 0x02
  
    $fWinIni = $UpdateIniFile -bor $SendChangeEvent
  
    $ret = [Params]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $Image, $fWinIni)
 
}

# ------------------------------ Core variables ------------------------------ #

function Apply-Variables($m) {
    debug "Importing variables files back to $m"
    Get-ChildItem -Path "$s_cache_location\Rainmeter\JaxCore\$m" -Recurse -File | ForEach-Object {
        $i_foundLocation = $_.FullName -replace "^$([regex]::Escape("$s_cache_location\Rainmeter\JaxCore\"))"
        $i_savelocation = $_.FullName
        $i_targetlocation = "$s_RMSkinFolder$i_foundLocation"
        If (Test-Path "$i_targetlocation") {
            # debug $i_savelocation
            # debug $i_targetlocation
            $Ini = Get-IniContent $i_savelocation;$oldvars = $Ini
            $Ini = Get-IniContent $i_targetlocation;$newvars = $Ini
            $oldvars.Keys | Foreach-Object {
                $i_section = $_
                $oldvars[$i_section].Keys | ForEach-Object {
                    $i_value = $_
                    If ([bool]$newvars[$i_section][$i_value]) {
                        $newvars[$i_section][$i_value] = $oldvars[$i_section][$i_value]
                    }
                }
            }
            Set-IniContent $newvars $i_targetlocation
        } else {
            debug "Moving #$i $i_savelocation -> $i_targetlocation"
            New-Item -Path "$(Split-Path $i_targetlocation)" -Type "Directory" -ErrorAction SilentlyContinue
            Copy-Item -Path "$i_savelocation" -Destination "$i_targetlocation" -Force -ErrorAction SilentlyContinue
        }
    }
}

# ---------------------------------------------------------------------------- #
#                                     Start                                    #
# ---------------------------------------------------------------------------- #

# Test: .\S-Hub\shp-extractor.ps1 "C:\Users\Jax\AppData\Roaming\JaxCore\CoreData\S-Hub\Exports\Test{}.shp"
# -dev

Write-Info "SHPEXTRACTOR REF: Experimental v1.1"
# ---------------------------- Installer variables --------------------------- #
$s_RMSettingsFolder = Get-Content 'C:\RMInstallation.txt' -Raw
$s_RMINIFile = "$s_RMSettingsFolder\Rainmeter.ini"
$RMEXEloc = "$s_RMSettingsFolder\Rainmeter.exe"
# Get the set skin path
If (Test-Path $s_RMINIFile) {
    $Ini = Get-IniContent $s_RMINIFile
    $s_RMSkinFolder = $Ini["Rainmeter"]["SkinPath"]
    $Ini = $null
} else {
    Write-Fail "Unable to locate $s_RMINIFile."
    Write-Info "S-Hub packages requires Rainmeter to be installed at the moment."
    Read-Host
    Return
}

Write-Info "Getting required information..."
# -------------------------------- Get rm bit -------------------------------- #
If (Get-Process Rainmeter -ErrorAction SilentlyContinue) {
    $rmprocess_object = Get-Process Rainmeter
    $rmprocess_id = $rmprocess_object.id
    Write-Task "Getting Rainmeter bitness..."
    $bit = '32bit'
    Get-Process -Id $rmprocess_id | Foreach {
        $modules = $_.modules
        foreach($module in $modules) {
            $file = [System.IO.Path]::GetFileName($module.FileName).ToLower()
            if($file -eq "wow64.dll") {
                $bit = "32bit"
                Break
            } else {
                $bit = "64bit"
            }
        }
    }
} else {
    Write-Fail "S-Hub extractor requires Rainmeter running in the background to get the appropriate bit for plugins."
    Read-Host
    Return
}
Write-Done
# ---------------------------------- Screen ---------------------------------- #
Write-Task "Getting screen sizes"
$vc = Get-WmiObject -class "Win32_VideoController"
$saw = $vc.CurrentHorizontalResolution
$sah = $vc.CurrentVerticalResolution
Write-Done
# ---------------------------------- Restore --------------------------------- #

If (!$o_noExtract) {
    $confirmation = Read-Host "Do you want to create a system restore point? (y/n)"
    if ($confirmation -match '^y$') {
        Write-Task "Generating system restore point"
        Checkpoint-Computer -Description "JaxCore SHP installation"
        Write-Done
    }
}
Write-Info "Please select the themes and modules that you want to import."
$o_toImport = Read-Host @"
A - Import all
R - Rainmeter skins
C - JaxCore modules
W - Windows visual style
B - BetterDiscord theme
S - Spicetify theme
F - Firefox custom css

Input example: "RCW" (To import Rainmeter, JaxCore and Windows only)
Input example: "A" (To import all available themes)

Selection
"@
If ($o_toImport) {
    $o_toImport = $o_toImport.ToCharArray()
} else {
    Write-Fail "Nothing to import, aborting"
    Read-Host
    Return
}
# ---------------------------- Create cache folder --------------------------- #
$s_cache_location = "$(Split-Path $s_RMSkinFolder)\CoreData\S-Hub\Import_Cache"
If (!$o_noExtract) {
    If (Test-Path -Path "$s_cache_location") {
        Remove-Item "$s_cache_location" -Recurse -Force
    }
    New-Item -Path "$s_cache_location" -ItemType "Directory" > $null
}
# ------------------------------- Unzip pacakge ------------------------------ #
Write-Task "Expanding $s_Path to $s_cache_location"
If (!$o_noExtract -or !(Test-Path "$s_cache_location\SHP-data.json")) {
    Copy-Item -Path "$s_Path" -Destination "$s_cache_location\$($s_Path | Split-Path -Leaf).zip"
    $ProgressPreference = 'SilentlyContinue'
    Expand-Archive -Path "$s_cache_location\$($s_Path | Split-Path -Leaf).zip" -DestinationPath "$s_cache_location" -Force
    Remove-Item "$s_cache_location\$($s_Path | Split-Path -Leaf).zip"
} 
Write-Done
# --------------------------------- SHP data --------------------------------- #
$SHPData = Get-Content -Raw "$s_cache_location\SHP-data.json" | ConvertFrom-Json
$s_name = $SHPData.Data.SetupName -replace '{.*}$'
If ($s_name -eq $null) {
    Write-Fail "Invalid SHP package file."
    Return
}
# ------------------------------- Start extract ------------------------------ #
Write-Info "Starting extraction..."
debug "-----------------"
debug "SetupDir: $s_Path"
debug "SetupName: $s_name"
debug "RainmeterPluginsBit: $bit"
debug "RainmeterPath: $s_RMSettingsFolder"
debug "RainmeterExePath: $RMEXEloc"
debug "RainmeterSkinsPath: $s_RMSkinFolder"
debug "ScreenAreaSizes: $saw x $sah"
debug "-----------------"
# ---------------------------------------------------------------------------- #
#                                   Rainmeter                                  #
# ---------------------------------------------------------------------------- #
If ((($SHPData.Tags -contains 'Rainmeter') -or ($SHPData.Data.CoreModules.Count -gt 0)) -and ('R', 'C', 'A' | ? { $o_toImport -contains $_ })) {
    # ------------------------------ Close Rainmeter ----------------------------- #
    If (Get-Process 'Rainmeter' -ErrorAction SilentlyContinue) {
        Write-Task "Ending Rainmeter & potential AHKv1 process"
        Stop-Process -Name 'Rainmeter'
        If (Get-Process 'AHKv1' -ErrorAction SilentlyContinue) {
            Stop-Process -Name 'AHKv1'
        }
        Write-Done
    }

    Write-Info "Rainmeter / JaxCore layout found in package"
    If (!$o_noMove) {
        Write-Task "Moving Rainmeter layout"
        New-Item -Path "$s_RMSettingsFolder\Layouts\$s_name" -ItemType "Directory" > $null
        Move-Item -Path "$s_cache_location\Rainmeter.ini" -Destination "$s_RMSettingsFolder\Layouts\$s_name" -Force
        Write-Done
    }
}
If (($SHPData.Tags -contains 'Rainmeter') -and ('R', 'A' | ? { $o_toImport -contains $_ })) {
    Write-Info "Rainmeter found in package"
    If (!$o_noMove) {
        # Move Rainmeter skins
        Get-ChildItem -Path "$s_cache_location\Rainmeter\Skins\" | ForEach-Object {
            $currentSkin = $_.Name
            If (Test-Path "$s_RMSkinFolder\$currentSkin") {
                If ($confirmation -notmatch '^a$') {
                    $confirmation = Read-Host "`nDo you want to replace `"$currentSkin`" in Rainmeter with the one from this package? (y/n/a) [y - yes][n - no][a - yes to all]"
                    If ($confirmation -match '^n$') {
                        return
                    }
                }
                Write-Task "Removing and re-adding `"$currentSkin`""
                Remove-Item -Path "$s_RMSKINFolder\$currentSkin\" -Recurse -Force
                New-Item -Path "$s_RMSKINFolder\$currentSkin" -ItemType "Directory" > $null
                Move-Item -Path "$s_cache_location\Rainmeter\Skins\$currentSkin\*" -Destination "$s_RMSkinFolder\$currentSkin\" -Force
                Write-Done
            } else {
                Write-Task "Moving `"$currentSkin`" to skins folder"
                New-Item -Path "$s_RMSKINFolder\$currentSkin" -ItemType "Directory" > $null
                Move-Item -Path "$s_cache_location\Rainmeter\Skins\$currentSkin\*" -Destination "$s_RMSkinFolder\$currentSkin\" -Force
                Write-Done
            }
        }
        If (Test-Path -Path "$s_cache_location\Rainmeter\Plugins\*") {
            $i_targetlocation = "$($s_RMSettingsFolder)\Plugins\"
            If (!(Test-Path "$i_targetlocation\")) { New-Item -Path "$i_targetlocation" -Type "Directory" -Force }
            Get-ChildItem -Path "$s_cache_location\Rainmeter\Plugins" | ForEach-Object {
                $i_plugin = "$($_.Name).dll"
                $i_pluginlocation = "$($_.FullName)\$bit\$i_plugin"
                If (Test-Path "$i_targetlocation\$i_plugin") {
                    $i_plugin_ver = Get-PluginVersion "$i_pluginlocation"
                    $i_plugin_localVer = Get-PluginVersion "$i_targetlocation\$i_plugin"
                    If ($i_plugin_localVer -lt $i_plugin_ver) {
                        Write-Task "Replacing plugin $i_plugin"
                        Remove-Item "$i_targetlocation\$i_plugin" -Force
                        Copy-Item -Path "$i_pluginlocation" -Destination "$i_targetlocation" -Force
                        Write-Done
                    } else {
                        debug "$i_plugin not replaced: Local $i_plugin_localVer >= Package $i_plugin_ver"
                    }
                } else {
                    Write-Task "Moving plugin $i_plugin"
                    Copy-Item -Path "$i_pluginlocation" -Destination "$i_targetlocation" -Force
                    Write-Done
                }
            }
            Write-Done
        }
    }
}
# ---------------------------------------------------------------------------- #
#                                    JaxCore                                   #
# ---------------------------------------------------------------------------- #
If (($SHPData.Data.CoreModules.Count -gt 0) -and ('C', 'A' | ? { $o_toImport -contains $_ })) {
    Write-Info "JaxCore modules found in package"
    If (!$o_noMove) {
        $o_InstallModule = @()
        $SHPData.Data.CoreModules | ForEach-Object {
            $currentModule = $_
            If (Test-Path "$s_RMSkinFolder\$currentModule") {
                Apply-Variables $currentModule
            } else {
                $hasModuleToDownload = $true
                $o_InstallModule += $currentModule
                debug "Added $_ to the list of modules pending to install"
            }
        }
        If ($hasModuleToDownload) {
            $o_FromSHUB = $true
            $o_Force = $true
            $o_Location = Split-Path $s_RMSettingsFolder
            Write-Divider
            iwr -useb 'https://raw.githubusercontent.com/Jax-Core/JaxCore/master/CoreInstaller.ps1' | iex
            Write-Divider
            foreach($module in $o_InstallModule) {
                Apply-Variables $module
            }
        }
        Write-Done
    }
}
# ---------------------------------------------------------------------------- #
#                                   Spicetify                                  #
# ---------------------------------------------------------------------------- #
If (($SHPData.Tags -contains 'Spicetify') -and ('S', 'A' | ? { $o_toImport -contains $_ })) {
    Write-Info "Spicetify found in package (pre)"
    try {spicetify.exe > $null}
    catch {$spicetify_detected = $false}

    If ($spicetify_detected -ne $false) {
        Write-Info 'Spicetify found in local (set)'
        $spicetifyconfig_path = spicetify.exe -c
        $spicetify_path = "$spicetifyconfig_path\..\"

        If (!$o_noMove) {
            # Get-Process 'Spotify' | Stop-Process

            debug "Applying settings"
            spicetify.exe config current_theme $SHPData.Spicetify.current_theme
            spicetify.exe config color_scheme $SHPData.Spicetify.color_scheme
            If ($SHPData.Spicetify.extensions) {
                spicetify.exe config extensions $SHPData.Spicetify.extensions
                Move-Item -Path "$s_cache_location\AppSkins\Spicetify\Extensions\*" -Destination "$($spicetify_path)Extensions\$($SHPData.Spicetify.extensions)"
            }
            
            debug "Copying theme assets to themes folder"
            New-Item -Path "$spicetify_path\Themes\$($SHPData.Spicetify.current_theme)" -Type "Directory"
            Move-Item -Path "$s_cache_location\AppSkins\Spicetify\Themes\*" -Destination "$($spicetify_path)Themes\$($SHPData.Spicetify.current_theme)"

            debug "Applying spicetify theme"
            ECHO Y | spicetify.exe apply
        }

        Write-Task "Spicetify"
        Write-Done
    } else {
        Write-Info 'Spicetify not found in local (nil)'
    }
}
# ---------------------------------------------------------------------------- #
#                                 BetterDiscord                                #
# ---------------------------------------------------------------------------- #
If (($SHPData.Tags -contains 'BetterDiscord') -and ('B', 'A' | ? { $o_toImport -contains $_ })) {
    Write-Info "BetterDiscord found in package (pre)"
    $bd_path = "$env:APPDATA\BetterDiscord"
    If (Test-Path -Path $bd_path) {
        Write-Info 'BetterDiscord found in local (set)'
        $bd_data_folders = Get-ChildItem -Path "$bd_path\data" -Directory

        If (!$o_noMove) {
            If ($bd_data_folders.Count -eq 1) {
                $bd_selected_folder = $bd_data_folders
            } else {
                $bd_selected_folder = $bd_data_folders[0]
            }
            debug "Found bd:$bd_selected_folder"
            $option_bdtheme = "$($SHPData.BetterDiscord.themename)"

            Get-Process | Where-Object -Property ProcessName -match "^Discord.*" | Stop-Process

            $bd_themeconfig = "$bd_path\data\$($bd_selected_folder)\themes.json"
            
            If (Test-Path -Path $bd_themeconfig) {
                $bd_themes = Get-Content -Path $bd_themeconfig | ConvertFrom-Json
            } else {
                $bd_themes = @{}
            }
            Write-Task "Generating new theme config"
            $bd_themes | Add-Member -NotePropertyName "$option_bdtheme" -NotePropertyValue $true -Force
            Remove-Item -Path $bd_themeconfig -Force
            $bd_themes | ConvertTo-Json -depth 2 | Out-File $bd_themeconfig -Force
            $bd_themeconfig_raw = (Get-Content -Path $bd_themeconfig -Raw) -replace "(?s)`r`n\s*$"
            [system.io.file]::WriteAllText($bd_themeconfig,$bd_themeconfig_raw)
            Write-Done

            Write-Task "Moving theme files to theme directory"
            Move-Item -Path "$s_cache_location\AppSkins\BetterDiscord\*" -Destination "$bd_path\themes\" -Force
            Write-Done
        }

        Write-Task "BetterDiscord"
        Write-Done
    } else {
        Write-Info 'BetterDiscord not found in local (nil)'
    }
}
# ---------------------------------------------------------------------------- #
#                                    Firefox                                   #
# ---------------------------------------------------------------------------- #
If (($SHPData.Tags -contains 'Firefox') -and ('F', 'A' | ? { $o_toImport -contains $_ })) {
    Write-Info "Firefox found in package (pre)"
    $ff_path = "$env:APPDATA\Mozilla\Firefox\"
    $ffconfig_path = "$($ff_path)profiles.ini"
    If (Test-Path -Path $ffconfig_path) {
        Write-Info 'Firefox found in local (set)'
        If (!$o_noMove) {
            # $Ini = Get-IniContent $ffconfig_path
            # $ff_currentuserprofile = $Ini[0]["Default"]
            # $ff_newprofile = "Profiles/JaxCore_SHP.$s_name"
            # for ($i = 1;$i -le 20; $i++) {
            #     If ($Ini["Profile$i"].Count -eq 0) {
            #         debug "Creating new section `"Profile$i`""
            #         $Ini["Profile$i"] = @{Name = "$s_name"; IsRelative = 1; Path = "$ff_newprofile"}
            #         Break
            #     }
            # }
            # $Ini[0]["Default"] = $ff_newprofile
            # Set-IniContent $Ini $ffconfig_path

            Get-Process 'Firefox' | Stop-Process

            # New-Item -Path "$($ff_path)$ff_newprofile" -Type "Directory"
            # debug "Copying current user profile as base, might take a while..."
            # Copy-Path -Source "$($ff_path)$ff_currentuserprofile" -Destination "$($ff_path)$ff_newprofile\"
            debug "Moving userChrome.css"
            New-Item -Path "$($ff_path)$ff_newprofile\chrome" -Type "Directory" > $null
            Move-Item -Path "$s_cache_location\AppSkins\Firefox\userChrome.css" -Destination "$($ff_path)$ff_newprofile\chrome" -Force
        }

        Write-Task "Firefox"
        Write-Done
    } else {
        Write-Info 'Firefox not found in local (nil)'
    }
}

# ---------------------------------------------------------------------------- #
#                                   Wallpaper                                  #
# ---------------------------------------------------------------------------- #

Write-Info "Applying wallpaper..."
$wallpaper_name = Get-Item "$s_cache_location\Wallpaper\*" | Select-Object Name
Write-Task "Moving and setting wallpaper from `"$s_cache_location\Wallpaper\$($wallpaper_name.Name)`""
If (!$o_noMove) {
    # Move-Item -Path "$s_cache_location\Wallpaper\$($wallpaper_name.Name)" -Destination "C:\Users\$ENV:USERNAME\AppData\Roaming\Microsoft\Windows\Themes" -Force
    Set-WallPaper "$s_cache_location\Wallpaper\$($wallpaper_name.Name)"
}
Write-Done

# ------------------------------------ .. ------------------------------------ #
Write-Info "Finalizing"
Write-Task "Clearing cache and applying changes"
If (!$o_noMove) {
    If ((($SHPData.Tags -contains 'Rainmeter') -or ($SHPData.Data.CoreModules.Count -gt 0)) -and ('R', 'C', 'A' | ? { $o_toImport -contains $_ })) {
        Start-Process "$RMEXEloc"
        Wait-ForProcess 'Rainmeter'
        Start-Sleep -Milliseconds 500
        & "$RMEXEloc" [!LoadLayout "$s_name"]
    }

    If (($SHPData.Tags -contains 'BetterDiscord') -and ('B', 'A' | ? { $o_toImport -contains $_ })) {
        & "$ENV:LOCALAPPDATA\Discord\Update.exe" --processStart Discord.exe
    }

    If (Test-Path -Path $ffconfig_path) {
        Start-Process Firefox
    }
}
Write-Done