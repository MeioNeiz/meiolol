' Runs meiolol-awake.ps1 with no window (powershell -WindowStyle Hidden still flashes
' one) and waits for it, so lab-watch.sh can tell whether it is still holding
Set sh = CreateObject("WScript.Shell")
Set fs = CreateObject("Scripting.FileSystemObject")
dir = fs.GetParentFolderName(WScript.ScriptFullName)
ps = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File "
sh.Run ps & """" & dir & "\meiolol-awake.ps1"" """ & WScript.Arguments(0) & """", 0, True
