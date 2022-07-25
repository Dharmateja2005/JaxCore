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

# ----------------------------- Terminal outputs ----------------------------- #
# Helper functions edited from spicetify cli ps1 installer (https://github.com/spicetify/spicetify-cli/blob/master/install.ps1)
function debug ([string] $Text) {
  Write-Host $Text
}

# ---------------------------------------------------------------------------- #
#                                    Actions                                   #
# ---------------------------------------------------------------------------- #

$ErrorActionPreference = 'SilentlyContinue'

# ------------------------------ Read RMSKIN.ini ----------------------------- #
$Ini = Get-IniContent "$root\RMSKIN.ini"
$skin_name = $Ini["rmskin"]["Name"]
$skin_auth = $Ini["rmskin"]["Author"]
$skin_ver = $Ini["rmskin"]["Version"]
$skin_varf = $Ini["rmskin"]["VariableFiles"]
$bit = $Ini["rmskin"]["RainmeterPluginsBit"]
$settingspath = $Ini["rmskin"]["RainmeterPath"]
debug "$skin_name $skin_ver - by $skin_auth"
debug "Variable files: $skin_varf"
debug "-----------------"
# ------------------------------ Variable files ------------------------------ #
$skinspath = "$root\..\.."
If (Test-Path "$skinspath\$skin_name") {
    $new_install = $false
    debug "This is an update"
    debug "> Saving variable files"
    $skin_varf = $skin_varf -split '\s\|\s'
    Remove-Item -Path "$root\SavedVarFiles" -Force -Recurse | Out-Null
    New-Item -Path "$root\SavedVarFiles" -Type "Directory" | Out-Null
    for ($i=0; $i -lt $skin_varf.Count; $i++) {
        $i_savedir = "$root\SavedVarFiles\$(Split-Path $skin_varf[$i])"
        $i_savelocation = "$root\SavedVarFiles\$($skin_varf[$i])"
        debug "Saving #$i $($skin_varf[$i]) -> $i_savelocation"
        New-Item -Path "$i_savedir" -Type "Directory" | Out-Null
        Copy-Item -Path "$skinspath\$($skin_varf[$i])" -Destination "$i_savelocation" -Force | Out-Null
    }
    Remove-Item -Path "$skinspath\$skin_name" -Force -Recurse | Out-Null
} else {
    $new_install = $true
    debug "This is a new installation"
}
# # ---------------------------------- Process --------------------------------- #
debug "> Moving skin files"
Move-Item -Path "$root\Skins\*" -Destination "$skinspath" -Force
debug "> Moving / replacing plugins"
Move-Item -Path "$root\Plugins\$bit\*" -Destination "$($settingspath)Plugins\" -Force
If (-not $new_install) {
    debug "> Moving saved variables files back to skin"
    for ($i=0; $i -lt $skin_varf.Count; $i++) {
        $i_savelocation = "$root\SavedVarFiles\$($skin_varf[$i])"
        $i_targetlocation = "$skinspath\$($skin_varf[$i])"
        debug "Moving #$i $i_savelocation -> $i_targetlocation"
        New-Item -Path "$(Split-Path $i_targetlocation)" -Type "Directory" | Out-Null
        Copy-Item -Path "$i_savelocation" -Destination "$i_targetlocation" -Force | Out-Null
    }
}
Start-Process "$($settingspath)Rainmeter.exe"
Exit