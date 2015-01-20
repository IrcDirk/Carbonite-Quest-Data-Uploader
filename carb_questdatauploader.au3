#AutoIt3Wrapper_UseUpx=y
#AutoIt3Wrapper_UPX_Parameters=--best --lzma

#pragma compile(Icon,.\up.ico)
#pragma compile(Compression, 3)
#pragma compile(ProductName, "Carbonite Quest Data Uploader")
#pragma compile(FileDescription, "Carbonite Quest Data Uploader")
#pragma compile(CompanyName, "Carbonite")
#pragma compile(LegalCopyright, "http://www.wowinterface.com/forums/forumdisplay.php?f=116")
#pragma compile(ProductVersion, 0.4.0.0)
#pragma compile(FileVersion, 0.4.0.0)

#include <Constants.au3>
#include <GUIConstants.au3>
#include <GUIConstantsEx.au3>
#include <MsgBoxConstants.au3>
#include <TrayConstants.au3>
#include <StringConstants.au3>
#include <Array.au3>
#include <File.au3>
#include "Startup.au3"
#include "ZLIB.au3"
#include "FileSystemMonitor.au3"

Opt("GUIOnEventMode", 1)
Opt("TrayMenuMode", 3)
Opt("TrayOnEventMode", 1)
Opt("WinTitleMatchMode", 3)

$curl =  @TempDir & "\curl.tmp"
FileInstall(".\curl.exe", $curl, 1)

If _StartupFolder_Exists("Carbonite Quest Data Uploader") == 0 Then
	_StartupFolder_Install("Carbonite Quest Data Uploader")
EndIf

$WOWLocale = ""
$WOWWinName = "[TITLE:World of Warcraft; CLASS:GxWindowClass]";
$WOWCarbQIniFile = @ScriptDir & "\carb_questdatauploader.ini";
$WOWPath = IniRead($WOWCarbQIniFile, "General", "WOWPath", "")
If FileExists($WOWPath) == 0 Then $WOWPath = ""
$WOWCarbQDataPath = "\WTF\Account"
$WOWCarbQDataFile = "Carbonite.Quests.lua"

$upFiles = ""
$tmpFile = @TempDir & "\carb_questdata.tmp"
$compressedFile = @TempDir & "\carb_questdata.gz";

; ABOUT DIALOG
$about = GuiCreate("About",400,100,-1,-1,BitOR($WS_CAPTION,$WS_SYSMENU))
GUISetOnEvent ($GUI_EVENT_CLOSE, "AboutOK" )
GUICtrlCreateIcon (@ScriptDir & "\up.ico",-1,11,11)
GUICtrlCreateLabel ("Carbonite Quest Data Uploader 0.4.0.0",59,11,390,20)
;$email = GUICtrlCreateLabel ("author@somewhere.com",59,70,135,15)
;GuiCtrlSetFont($email, 8.5, -1, 4) ; underlined
;GuiCtrlSetColor($email,0x0000ff)
;GuiCtrlSetCursor($email,0)
;GUICtrlSetOnEvent(-1, "OnEmail")
$www = GUICtrlCreateLabel ("http://www.wowinterface.com/forums/forumdisplay.php?f=116",59,35,390,15)
GuiCtrlSetFont($www, 8.5, -1, 4)
GuiCtrlSetColor($www,0x0000ff)
GuiCtrlSetCursor($www,0)
GUICtrlSetOnEvent(-1, "OnWWW")
GUICtrlCreateButton ("OK",(390/2 - 74/2),65,74,23,BitOr($GUI_SS_DEFAULT_BUTTON, $BS_DEFPUSHBUTTON))
GUICtrlSetState (-1, $GUI_FOCUS)
GUICtrlSetOnEvent(-1, "AboutOK")

; TRAY
TraySetToolTip("Carbonite Quest Data Uploader");
TrayCreateItem("About")
TrayItemSetOnEvent(-1, "_About")
TrayCreateItem("")
TrayCreateItem("Exit")
TrayItemSetOnEvent(-1, "_ExitScript")

While 1
   If $WOWPath == "" Then
	  WinWait($WOWWinName)
	  $aWin = _WinGetDetails($WOWWinName)
	  $WOWPath = $aWin[3];
	  IniWrite($WOWCarbQIniFile, "General", "WOWPath", $WOWPath)
   Else
	  ExitLoop
   EndIf
   Sleep(100)
WEnd

_FileSysMonSetup(1, $WOWPath & $WOWCarbQDataPath)

$event = True

While 1
	;If $event == True Then
   If(WinExists($WOWWinName) == 1) Then
	  _FileSysMonDirEventHandler()
   Else
	   Sleep(100)
   EndIf
   If(WinExists($WOWWinName) == 0 And $upFiles <> "") Then
	  ZipFiles()
	  $upFiles = ""
   EndIf
WEnd

Func Upload()
   Local $iPID = Run($curl & ' -o "' & @TempDir & '\progress.tmp" -F "carb=@' & $compressedFile & '" http://dirk.hekko.pl/carb_q/upload', '', @SW_HIDE, $STDERR_CHILD), $line
   ConsoleWrite('Upload' & @CRLF)
   ProcessWaitClose($iPID)
EndFunc

Func ZipFiles()
   $upload = ""
   $sFiles = StringSplit($upFiles, "|", $STR_NOCOUNT)
   $locale = ""

   For $sFile In $sFiles
	   If FileExists($sFile) Then
		   Local $file = FileRead($sFile)
		   Local $aArray = StringRegExp($file, '(?msU)\t\t\["Q"\] = {(.*)},', $STR_REGEXPARRAYFULLMATCH)
		   Local $aLocale = StringRegExp($file, '(?msU)\["UserLocale"\] = "(.*)",', $STR_REGEXPARRAYFULLMATCH)

		   If StringLen(StringStripWS($aLocale[1], $STR_STRIPLEADING + $STR_STRIPTRAILING)) <> 0 And $locale == "" Then
				$locale = StringStripWS($aLocale[1], $STR_STRIPLEADING + $STR_STRIPTRAILING) & @CRLF
		   EndIf

		   If StringLen(StringStripWS($aArray[1], $STR_STRIPLEADING + $STR_STRIPTRAILING)) == 0 Then
			  ConsoleWrite('NO Upload for ' & $sFile & @CRLF)
		   Else
			  $find = StringStripWS($aArray[1], $STR_STRIPLEADING + $STR_STRIPTRAILING)
			  $upload = $upload & StringReplace($find, @TAB, "") & @CRLF
			  $file = StringReplace($file, $find, "")

			  $hFileOpen = FileOpen($sFile, $FO_OVERWRITE + $FO_UTF8)
			  FileWrite($hFileOpen, $file)
			  ConsoleWrite('Upload for ' & $sFile & @CRLF)
		   EndIf
		EndIf
   Next

   If $upload <> "" Then
	   $hFileOpen = FileOpen($tmpFile, $FO_OVERWRITE + $FO_UTF8)
	   FileWrite($hFileOpen, $locale & $upload)
	   ConsoleWrite('Compress' & @CRLF)
	   _ZLIB_GZFileCompress($tmpFile, $compressedFile, 9)
	   Upload()
   EndIf
EndFunc

Func _FileSysMonActionEvent($event_type, $event_id, $event_value)
   If StringInStr($event_value, $WOWCarbQDataFile) And StringInStr($event_value, $WOWCarbQDataFile & ".bak") == 0 And StringInStr($upFiles, $event_value) == 0 Then
	  Local $sep = "|"
	  If $upFiles == "" Then $sep = ""
	  $upFiles = $upFiles & $sep & $WOWPath & $WOWCarbQDataPath & '\' & $event_value;
	  ConsoleWrite('Change in ' & $WOWCarbQDataFile & @CRLF)
	  $event = False
   EndIf
EndFunc

Func _About()
   GUISetState(@SW_SHOW, $about)
EndFunc

Func OnEmail()
    Run(@ComSpec & " /c " & 'start mailto:author@somewhere.com?subject=Something', "", @SW_HIDE)
EndFunc

Func OnWWW()
    Run(@ComSpec & " /c " & 'start http://www.wowinterface.com/forums/forumdisplay.php?f=116', "", @SW_HIDE)
EndFunc

Func AboutOK()
     GUISetState(@SW_HIDE, $about)
EndFunc

Func _ExitScript()
    Exit
EndFunc

Func _WinGetDetails($sTitle, $sText = '') ; Based on code of _WinGetPath by GaryFrost.
    Local $aReturn[5] = [4, '-WinTitle', '-PID', '-FolderPath', '-FileName'], $aStringSplit

    If StringLen($sText) > 0 Then
        $aReturn[1] = WinGetTitle($sTitle, $sText)
    Else
        $aReturn[1] = WinGetTitle($sTitle)
    EndIf
    $aReturn[2] = WinGetProcess($sTitle)

    Local $oWMIService = ObjGet('winmgmts:\\.\root\CIMV2')
    Local $oItems = $oWMIService.ExecQuery('Select * From Win32_Process Where ProcessId = ' & $aReturn[2], 'WQL', 0x30)
    If IsObj($oItems) Then
        For $oItem In $oItems
            If $oItem.ExecutablePath Then
                $aStringSplit = StringSplit($oItem.ExecutablePath, '\')
                $aReturn[3] = ''
                For $A = 1 To $aStringSplit[0] - 1
                    $aReturn[3] &= $aStringSplit[$A] & '\'
                Next
                $aReturn[3] = StringTrimRight($aReturn[3], 1)
                $aReturn[4] = $aStringSplit[$aStringSplit[0]]
                Return $aReturn
            EndIf
        Next
    EndIf
    Return SetError(1, 0, $aReturn)
EndFunc