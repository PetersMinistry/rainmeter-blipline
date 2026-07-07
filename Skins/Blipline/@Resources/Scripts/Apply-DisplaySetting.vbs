Option Explicit
On Error Resume Next

Function Quote(value)
    Quote = """" & Replace(CStr(value), """", """""") & """"
End Function

Dim shell, scriptPath, settingsPath, outputPath, settingName, settingValue, settingLabel, refreshConfigs, command

If WScript.Arguments.Count < 4 Then
    WScript.Quit 1
End If

scriptPath = CreateObject("Scripting.FileSystemObject").BuildPath(CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName), "Apply-DisplaySetting.ps1")
settingsPath = WScript.Arguments(0)
outputPath = WScript.Arguments(1)
settingName = WScript.Arguments(2)
settingValue = WScript.Arguments(3)
settingLabel = ""
refreshConfigs = ""

If WScript.Arguments.Count > 4 Then
    settingLabel = WScript.Arguments(4)
End If
If WScript.Arguments.Count > 5 Then
    refreshConfigs = WScript.Arguments(5)
End If

command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " & Quote(scriptPath) & _
    " -SettingsPath " & Quote(settingsPath) & _
    " -OutputPath " & Quote(outputPath) & _
    " -Name " & Quote(settingName) & _
    " -Value " & Quote(settingValue)

If Len(settingLabel) > 0 Then
    command = command & " -Label " & Quote(settingLabel)
End If
If Len(refreshConfigs) > 0 Then
    command = command & " -RefreshConfigs " & Quote(refreshConfigs)
End If

Set shell = CreateObject("WScript.Shell")
shell.Run command, 0, False
