# ---------------------------------------------------------------------------- #
#                                   Functions                                  #
# ---------------------------------------------------------------------------- #

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

function Wait-ForProcess
{
    param
    (
        $Name = 'notepad',
        [Switch]
        $IgnoreAlreadyRunningProcesses
    )
    if ($IgnoreAlreadyRunningProcesses)
    {        $NumberOfProcesses = (Get-Process -Name $Name -ErrorAction SilentlyContinue).Count    }
    else
    {        $NumberOfProcesses = 0    }


    Write-Host "Waiting for $Name" -NoNewline
    while ( (Get-Process -Name $Name -ErrorAction SilentlyContinue).Count -eq $NumberOfProcesses )
    {
        Write-Host '.' -NoNewline
        Start-Sleep -Milliseconds 400
    }
    Write-Host ''
}

# ----------------------------- Terminal outputs ----------------------------- #
# Helper functions edited from spicetify cli ps1 installer (https://github.com/spicetify/spicetify-cli/blob/master/install.ps1)
function debug ([string] $Text) {
  Write-Host $Text
}

# ---------------------------------------------------------------------------- #
#                                    Actions                                   #
# ---------------------------------------------------------------------------- #

$ErrorActionPreference = 'SilentlyContinue'

[System.IO.Directory]::SetCurrentDirectory($root)
# --------------------------- Read carry over data --------------------------- #
$Ini = Get-IniContent "$root\InstallerProcessData.ini"
$bit = $Ini["Data"]["RainmeterPluginsBit"]
$settingspath = $Ini["Data"]["RainmeterPath"]
$programpath = $Ini["Data"]["RainmeterExePath"]

debug "RainmeterPluginsBit: $bit"
debug "RainmeterPath: $settingspath"
debug "RainmeterExePath: $programpath"
debug "-----------------"

$skin_need_load = $false
Get-ChildItem "$root\" -Directory | ForEach-Object {
    $i_root = "$root\$($_.Name)"

    # ------------------------------ Read RMSKIN.ini ----------------------------- #
    $Ini = Get-IniContent "$i_root\RMSKIN.ini"
    $skin_name = Get-ChildItem -Path "$i_root\Skins\" | Select-Object -First 1
    $skin_name = $skin_name.Name
    $skin_auth = $Ini["rmskin"]["Author"]
    $skin_ver = $Ini["rmskin"]["Version"]
    $skin_varf = $Ini["rmskin"]["VariableFiles"]

    $skin_load = $Ini["rmskin"]["Load"]
    $skin_load_path = Split-Path $skin_load
    If ($skin_name -contains '#JaxCore') {$skin_need_load = $true}

    debug "$skin_name $skin_ver - by $skin_auth"
    debug "Variable files: $skin_varf"
    debug "Load: $skin_load_path ($skin_need_load)"
    debug "-----------------"
    # ------------------------------ Variable files ------------------------------ #
    $skinspath = "$root\..\.."
    If (Test-Path "$skinspath\$skin_name") {
        $new_install = $false
        debug "This is an update"
        debug "> Saving variable files"
        $skin_varf = $skin_varf -split '\s\|\s'
        Remove-Item -Path "$i_root\SavedVarFiles" -Force -Recurse | Out-Null
        New-Item -Path "$i_root\SavedVarFiles" -Type "Directory" | Out-Null
        for ($i=0; $i -lt $skin_varf.Count; $i++) {
            $i_savedir = "$i_root\SavedVarFiles\$(Split-Path $skin_varf[$i])"
            $i_savelocation = "$i_root\SavedVarFiles\$($skin_varf[$i])"
            debug "Saving #$i $($skin_varf[$i]) -> $i_savelocation"
            New-Item -Path "$i_savedir" -Type "Directory" | Out-Null
            Copy-Item -Path "$skinspath\$($skin_varf[$i])" -Destination "$i_savelocation" -Force | Out-Null
        }
        Get-ChildItem -Path "$skinspath\$skin_name" -Recurse | Remove-Item -Recurse
    } else {
        $new_install = $true
        debug "This is a new installation"
    }
    # ---------------------------------- Process --------------------------------- #
    debug "> Moving skin files"
    If ($new_install) {New-Item -Path "$skinspath\$skin_name\" -Type "Directory" -Force | Out-Null}
    Move-Item -Path "$i_root\Skins\$skin_name\*" -Destination "$skinspath\$skin_name\" -Force
    If (Test-Path "$i_root\Plugins\") {
        debug "> Moving / replacing plugins"
        Move-Item -Path "$i_root\Plugins\$bit\*" -Destination "$($settingspath)Plugins\" -Force
    } else {
        debug "> Skipping plugin installation (none)"
    }
    If (-not $new_install) {A
        debug "> Moving saved variables files back to skin"
        for ($i=0; $i -lt $skin_varf.Count; $i++) {
            $i_savelocation = "$i_root\SavedVarFiles\$($skin_varf[$i])"
            $i_targetlocation = "$skinspath\$($skin_varf[$i])"
            debug "Moving #$i $i_savelocation -> $i_targetlocation"
            New-Item -Path "$(Split-Path $i_targetlocation)" -Type "Directory" | Out-Null
            Copy-Item -Path "$i_savelocation" -Destination "$i_targetlocation" -Force | Out-Null
        }
    }
    debug "> Finished installation of $skin_name"
    debug "-----------------"
}
Start-Process "$($programpath)Rainmeter.exe"
If ($skin_need_load) {
    Wait-ForProcess 'Rainmeter'
    Start-Sleep -Milliseconds 500
    & "$($programpath)Rainmeter.exe" [!ActivateConfig $skin_load_path]
}
Exit