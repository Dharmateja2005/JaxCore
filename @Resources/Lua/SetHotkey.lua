function Set(hotkey, useWin)
    local SecNum = SKIN:GetVariable('Sec.Num')
    if useWin == 1 then
        hotkey = '#'..hotkey
    end
    local matchArray = {'%#', '%!', '%^', '%+'}
    local replaceArray = {'Win ', 'Alt ', 'Ctrl ', 'Shift '}
    local hotkeyString = hotkey
    for i = 1, 4 do
        hotkeyString = hotkeyString:gsub(matchArray[i], replaceArray[i])
    end
    local saveLocation = [[#SKINSPATH##Skin.Name#\@Resources\Actions\HotKeys.ini]]
    SKIN:Bang('[!WriteKeyvalue Variables Key'..SecNum..' "'..hotkey..'" "'..saveLocation..'"][!WriteKeyvalue Variables Key'..SecNum..'InString "'..hotkeyString..'" "'..saveLocation..'"][!UpdateMeasure Auto_Refresh:M "#JaxCore\\Main"][!Refresh "#JaxCore\\Main"][!DeactivateConfig]')
end

function Start()
    local bang = ''
    local winbool = 0
    local currentKey = SKIN:ReplaceVariables('[#Key[#Sec.Num]]')
    if currentKey:find('#') then
        currentKey = currentKey:gsub('#', '')
        winbool = 1
    end
    local saveLocation = [[#@#Actions\\AHKCacheVariables.inc]]
    bang = bang .. '[!WriteKeyvalue Variables CurrentKey "'..currentKey..'" "'..saveLocation..'"]'
    bang = bang .. '[!WriteKeyvalue Variables WinBool "'..winbool..'" "'..saveLocation..'"]'
    bang = bang .. '[!WriteKeyvalue Variables RMPATH "#PROGRAMPATH#Rainmeter.exe" "'..saveLocation..'"]'
    bang = bang .. '["#@#Actions\\Hotkey.ahk" "#@#Actions\\AHKv1.exe"]'
    SKIN:Bang(bang)
end