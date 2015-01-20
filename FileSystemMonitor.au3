#include-once

#cs
    Title:           File System Monitoring UDF Library for AutoIt3
    Filename:          FileSystemMonitor.au3
    Description:     A collection of functions for monitoring the Windows File System
    Author:           seangriffin
    Version:          V0.4
    Last Update:     02/05/10
    Requirements:     AutoIt3 3.2 or higher
#ce

#AutoIt3Wrapper_au3check_parameters=-d -w 1 -w 2 -w 3 -w 4 -w 5 -w 6

; #INCLUDES# =========================================================================================================

; #GLOBAL VARIABLES# =================================================================================================
Global $pFSM_DirEvents, $pFSM_Dir, $pFSM_Overlapped, $tFSM_FNI, $pFSM_Buffer, $sFSM_Filename, $aFSM_Register, $iFSM_Buffersize, $tFSM_Overlapped
Global $tFSM_Buffer, $tFSM_DirEvents, $iFSM_DirEvents, $hFSM_Event, $hFSM_ShellMonGUI = GUICreate("")

; #FUNCTION# ;===============================================================================
;
; Name...........: _FileSysMonSetup()
; Description ...: Setup File System Monitoring.
; Syntax.........: _FileSysMonSetup($iMonitor_Type = 3, $sDirMon_Path = "C:\", $sShellMon_Path = "")
; Parameters ....: $iMonitor_Type - Optional: The type of monitoring to use.
;                      1 = directory monitoring only
;                      2 = shell monitoring only
;                      3 = both directory and shell monitoring
;                  $sDirMon_Path - Optional: The path to use for directory monitoring.
;                      The path "C:\" is used if one isn't provided.
;                  $sShellMon_Path - Optional: The path to use for shell monitoring.
;                      The blank path is used if one isn't provided. This
;                      denotes that system-wide shell events will be monitored.
; Return values .: On Success            - Returns True.
;                  On Failure            - Returns False.
; Author ........: seangriffin
; Modified.......:
; Remarks .......: A call to this function should be inserted in a script prior to calling other
;                  functions in this UDF.  Ideally the function should be placed before
;                  the main message loop in a GUI-based script.
; Related .......:
; Link ..........:
; Example .......: Yes
; ;==========================================================================================
Func _FileSysMonSetup($iMonitor_Type = 3, $sDirMon_Path = "C:\", $sShellMon_Path = "")

    If BitAnd($iMonitor_Type, 1) Then ; Setup the Directory Event Handler
        Local $sdir = $sDirMon_Path
        $tFSM_Buffer = DllStructCreate("byte[4096]")
        $pFSM_Buffer = DllStructGetPtr($tFSM_Buffer)
        $iFSM_Buffersize = DllStructGetSize($tFSM_Buffer)
        $tFSM_FNI = 0
        $pFSM_Dir = DllCall("kernel32.dll", "hwnd", "CreateFile", "Str", $sdir, "Int", 0x1, "Int", BitOR(0x1, 0x4, 0x2), "ptr", 0, "int", 0x3, "int", BitOR(0x2000000, 0x40000000), "int", 0)
        $pFSM_Dir = $pFSM_Dir[0]
        $tFSM_Overlapped = DllStructCreate("Uint OL1;Uint OL2; Uint OL3; Uint OL4; hwnd OL5")
        For $i = 1 To 5
            DllStructSetData($tFSM_Overlapped, $i, 0)
        Next
        $pFSM_Overlapped = DllStructGetPtr($tFSM_Overlapped)
        $tFSM_DirEvents = DllStructCreate("hwnd DirEvents")
        $pFSM_DirEvents = DllStructGetPtr($tFSM_DirEvents)
        Local $hFSM_Event = DllCall("kernel32.dll", "hwnd", "CreateEvent", "UInt", 0, "Int", True, "Int", False, "UInt", 0)
        DllStructSetData($tFSM_Overlapped, 5, $hFSM_Event[0])
        DllStructSetData($tFSM_DirEvents, 1, $hFSM_Event[0])
        DllCall("kernel32.dll", "Int", "ReadDirectoryChangesW", "hwnd", $pFSM_Dir, "ptr", $pFSM_Buffer, "dword", $iFSM_Buffersize, "int", True, "dword", BitOR(0x1, 0x2, 0x4, 0x8, 0x10, 0x20, 0x40, 0x100), "Uint", 0, "Uint", $pFSM_Overlapped, "Uint", 0)
        $sFSM_Filename = ""
    EndIf

    If BitAND($iMonitor_Type, 2) Then ; Setup the Shell Event Handler
        ; Register a window message to associate an AutoIT function with the change notification events
        Local $aRet = DllCall("user32.dll", "uint", "RegisterWindowMessageW", "wstr", "shchangenotifymsg")
        If @error Then Return SetError(@error, @extended, 0)
        Local $SHNOTIFY = $aRet[0]
        GUIRegisterMsg($SHNOTIFY, "_FileSysMonShellEventHandler")
        ; Setup the structure for registering the gui to receive shell notifications
        If StringCompare($sShellMon_Path, "") <> 0 Then
            Local $ppidl = DllCall("shell32.dll", "ptr", "ILCreateFromPath", "wstr", $sShellMon_Path)
        EndIf
        Local $shnotifystruct = DllStructCreate("ptr pidl; int fRecursive")
        If StringCompare($sShellMon_Path, "") <> 0 Then
            DllStructSetData($shnotifystruct, "pidl", $ppidl[0])
        Else
            DllStructSetData($shnotifystruct, "pidl", 0)
        EndIf
        DllStructSetData($shnotifystruct, "fRecursive", 0)
        ; Register the gui to receive shell notifications
        $aFSM_Register = DllCall("shell32.dll", "int", "SHChangeNotifyRegister", "hwnd", $hFSM_ShellMonGUI, "int", BitOR(0x0001, 0x0002), "long", 0x7FFFFFFF, "uint", $SHNOTIFY, "int", 1, "ptr", DllStructGetPtr($shnotifystruct))
        If StringCompare($sShellMon_Path, "") <> 0 Then
            DllCall("ole32.dll", "none", "CoTaskMemFree", "ptr", $ppidl[0])
        EndIf
    EndIf

    Return True
EndFunc   ;==>_FileSysMonSetup

; #FUNCTION# ;===============================================================================
;
; Name...........: _FileSysMonSetDirMonPath()
; Description ...: Change the path of Directory Monitoring
; Syntax.........: _FileSysMonSetDirMonPath($sDirMon_Path = "C:\")
; Parameters ....: $sDirMon_Path - Optional: The path to use for directory monitoring.
;                      The path "C:\" is used if one isn't provided.
; Return values .: On Success - Returns True.
;                  On Failure - Returns False.
;
; Author ........: seangriffin
; Modified.......:
; Remarks .......: For an unknown reason, after this function is called the
;
; Related .......:
; Link ..........:
; Example .......: Yes
; ;==========================================================================================
Func _FileSysMonSetDirMonPath($sDirMon_Path = "C:\")

    Local $sdir = $sDirMon_Path
    $pFSM_Dir = DllCall("kernel32.dll", "hwnd", "CreateFile", "Str", $sdir, "Int", 0x1, "Int", BitOR(0x1, 0x4, 0x2), "ptr", 0, "int", 0x3, "int", BitOR(0x2000000, 0x40000000), "int", 0)
    $pFSM_Dir = $pFSM_Dir[0]
    For $i = 1 To 5
        DllStructSetData($tFSM_Overlapped, $i, 0)
    Next
    Local $hFSM_Event = DllCall("kernel32.dll", "hwnd", "CreateEvent", "UInt", 0, "Int", True, "Int", False, "UInt", 0)
    DllStructSetData($tFSM_Overlapped, 5, $hFSM_Event[0])
    DllStructSetData($tFSM_DirEvents, 1, $hFSM_Event[0])
    DllCall("kernel32.dll", "Int", "ReadDirectoryChangesW", "hwnd", $pFSM_Dir, "ptr", $pFSM_Buffer, "dword", $iFSM_Buffersize, "int", True, "dword", BitOR(0x1, 0x2, 0x4, 0x8, 0x10, 0x20, 0x40, 0x100), "Uint", 0, "Uint", $pFSM_Overlapped, "Uint", 0)

    Return True
EndFunc   ;==>_FileSysMonSetDirMonPath

; #FUNCTION# ;===============================================================================
;
; Name...........: _FileSysMonSetShellMonPath()
; Description ...: Change the path of Shell Monitoring
; Syntax.........: _FileSysMonSetShellMonPath($sDirMon_Path = "")
; Parameters ....: $sDirMon_Path    - Optional: The path to use for shell monitoring.
;                      The path "" is used if one isn't provided.
; Return values .: On Success - Returns True.
;                  On Failure - Returns False.
;
; Author ........: seangriffin
; Modified.......:
; Remarks .......:
;
; Related .......:
; Link ..........:
; Example .......: Yes
; ;==========================================================================================
Func _FileSysMonSetShellMonPath($sShellMon_Path = "")

    ; De-Register the gui from receiving shell notifications
    DllCall("shell32.dll", "int", "SHChangeNotifyDeregister", "ulong", $aFSM_Register[0])
    ; Register a window message to associate an AutoIT function with the change notification events
    ;Local $SHNOTIFY = _WinAPI_RegisterWindowMessage("shchangenotifymsg")
    Local $aRet = DllCall("user32.dll", "uint", "RegisterWindowMessageW", "wstr", "shchangenotifymsg")
    If @error Then Return SetError(@error, @extended, 0)
    Local $SHNOTIFY = $aRet[0]
    GUIRegisterMsg($SHNOTIFY, "_FileSysMonShellEventHandler")
    ; Setup the structure for registering the gui to receive shell notifications
    If StringCompare($sShellMon_Path, "") <> 0 Then
        Local $ppidl = DllCall("shell32.dll", "ptr", "ILCreateFromPath", "wstr", $sShellMon_Path)
    EndIf
    Local $shnotifystruct = DllStructCreate("ptr pidl; int fRecursive")
    If StringCompare($sShellMon_Path, "") <> 0 Then
        DllStructSetData($shnotifystruct, "pidl", $ppidl[0])
    Else
        DllStructSetData($shnotifystruct, "pidl", 0)
    EndIf
    DllStructSetData($shnotifystruct, "fRecursive", 0)
    ; Register the gui to receive shell notifications
    $aFSM_Register = DllCall("shell32.dll", "int", "SHChangeNotifyRegister", "hwnd", $hFSM_ShellMonGUI, "int", BitOR(0x0001, 0x0002), "long", 0x7FFFFFFF, "uint", $SHNOTIFY, "int", 1, "ptr", DllStructGetPtr($shnotifystruct))
    If StringCompare($sShellMon_Path, "") <> 0 Then
        DllCall("ole32.dll", "none", "CoTaskMemFree", "ptr", $ppidl[0])
    EndIf

    Return True

EndFunc   ;==>_FileSysMonSetShellMonPath

; #FUNCTION# ;===============================================================================
;
; Name...........: _FileSysMonDirEventHandler()
; Description ...: Monitors the file system for changes to a given directory.  If a change event occurs,
;                      the user-defined "_FileSysMonActionEvent" function is called.
; Syntax.........: _FileSysMonDirEventHandler()
; Parameters ....: none
; Return values .: On Success - Returns True.
;                  On Failure - Returns False.
;
; Author ........: seangriffin
; Modified.......:
; Remarks .......: This function utilises the "ReadDirectoryChangesW" Win32 operating system function to
;                  monitor the a directory for changes.
;
;                  The ReadDirectoryChangesW function appears to queue events, such that whenever
;                  it is called, all unprocessed events are retrieved one at a time.
;
;                  The function "_FileSysMonSetup" must be called, with a $iMonitor_Type
;                  of either 1 or 3, prior to calling this    function.
;
;                  A call to this function should be inserted within the main message loop of a GUI-based script.
;
;                  A user-defined function to action the events is required to be created by the user
;                  in the calling script, and must be defined as follows:
;
;                  Func _FileSysMonActionEvent($event_type, $event_id, $event_value)
;
;                  EndFunc
;
; Related .......:
; Link ..........:
; Example .......: Yes
; ;==========================================================================================
Func _FileSysMonDirEventHandler()

    Local $aRet, $iOffset, $nReadLen, $tStr, $iNext, $ff

    $aRet = DllCall("User32.dll", "dword", "MsgWaitForMultipleObjectsEx", "dword", 1, "ptr", $pFSM_DirEvents, "dword", 100, "dword", 0x4FF, "dword", 0x6)

    If $aRet[0] = 0 Then
        $iOffset = 0
        $nReadLen = 0
        DllCall("kernel32.dll", "Uint", "GetOverlappedResult", "hWnd", $pFSM_Dir, "Uint", $pFSM_Overlapped, "UInt*", $nReadLen, "Int", True)
        While 1
            $tFSM_FNI = DllStructCreate("dword Next;dword Action;dword FilenameLen", $pFSM_Buffer + $iOffset)
            $tStr = DllStructCreate("wchar[" & DllStructGetData($tFSM_FNI, "FilenameLen") / 2 & "]", $pFSM_Buffer + $iOffset + 12)
            $sFSM_Filename = DllStructGetData($tStr, 1)
            _FileSysMonActionEvent(0, DllStructGetData($tFSM_FNI, "Action"), $sFSM_Filename)
            $iNext = DllStructGetData($tFSM_FNI, "Next")
            If $iNext = 0 Then ExitLoop
            $iOffset += $iNext
        WEnd
        $ff = DllStructGetData($tFSM_Overlapped, 5)
        DllCall("kernel32.dll", "Uint", "ResetEvent", "UInt", $ff)
        DllCall("kernel32.dll", "Int", "ReadDirectoryChangesW", "hwnd", $pFSM_Dir, "ptr", $pFSM_Buffer, "dword", $iFSM_Buffersize, "int", True, "dword", BitOR(0x1, 0x2, 0x4, 0x8, 0x10, 0x20, 0x40, 0x100), "Uint", 0, "Uint", $pFSM_Overlapped, "Uint", 0)
    EndIf

    Return True

EndFunc   ;==>_FileSysMonDirEventHandler

; #FUNCTION# ;===============================================================================
;
; Name...........: _FileSysMonShellEventHandler()
; Description ...: Monitors the file system for shell events.
; Syntax.........: _FileSysMonShellEventHandler()
; Parameters ....: $hWnd   - The Window handle of the GUI in which the message appears.
;                  $iMsg    - The Windows message ID.
;                  $wParam - The first message parameter as hex value.
;                  $lParam - The second message parameter as hex value.
; Return values .: On Success - Returns True.
;                  On Failure - Returns False.
;
; Author ........: seangriffin
; Modified.......:
; Remarks .......: If a directory was provided in "_FileSysMonSetup" then only events in
;                  that directory will be caught.  If no directory was provided, then
;                  system-wide events will be caught.
;
;                  This function utilises the "SHChangeNotifyRegister" Win32 operating system functionality
;                  monitor a system or directory for changes relating to the Windows shell.
;
;                  The function "_FileSysMonSetup" must be called, with a $iMonitor_Type
;                  of either 2 or 3, prior to calling this    function.
;
;                  A call to this function is not required.  It is triggered automatically
;                  for each new shell event.
;
;                  A user-defined function to action the events is required to be created by the user
;                  in the calling script, and must be defined as follows:
;
;                  Func _FileSysMonActionEvent($event_type, $event_id, $event_value)
;
;                  EndFunc
;
; Related .......:
; Link ..........:
; Example .......: Yes
; ;==========================================================================================
Func _FileSysMonShellEventHandler($hWnd, $iMsg, $wParam, $lParam)

    #forceref $hWnd, $iMsg

    Local $tDestination, $wHighBit

    Local $tPath = DllStructCreate("dword dwItem1; dword dwItem2", $wParam)
    Local $aRet = DllCall("shell32.dll", "int", "SHGetPathFromIDList", "ptr", DllStructGetData($tPath, "dwItem1"), "str", "")
    ; Get the drive for which free space has changed
    If $lParam = 0x00040000 Then
        $tDestination = DllStructCreate("long")
        DllCall("kernel32.dll", "none", "RtlMoveMemory", "ptr", DllStructGetPtr($tDestination), "ptr", (DllStructGetData($tPath, "dwItem1") + 2), "int", 4) ; CopyMemory
        $wHighBit = Int(Log(DllStructGetData($tDestination, 1)) / Log(2))
        $aRet[2] = Chr(65 + $wHighBit)
    EndIf
    If $lParam <> 0x00000002 And $lParam <> 0x00000004 Then ; FILE_ACTION_ADDED & FILE_ACTION_REMOVED skipped due to a deadlock with Directory_Event_Handler()
        _FileSysMonActionEvent(1, $lParam, $aRet[2])
    EndIf

    Return True

EndFunc   ;==>_FileSysMonShellEventHandler