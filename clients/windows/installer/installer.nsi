; BaumAgent Windows Installer — NSIS script
; Build: makensis /DVERSION=1.2.3 installer.nsi
; Requires NSIS 3.x, place publish\ output next to this script before running.

!define APPNAME     "BaumAgent"
!define APPID       "com.baumagent.client"
!define PUBLISHER   "Bruiserbaum"
!define APPURL      "https://github.com/Bruiserbaum/baumagent-clients"
!define EXENAME     "BaumAgentClient.exe"
!define REGKEY      "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPID}"

!ifndef VERSION
  !define VERSION "1.0.0"
!endif

Name           "${APPNAME} ${VERSION}"
OutFile        "BaumAgent-Setup-${VERSION}.exe"
InstallDir     "$PROGRAMFILES64\${APPNAME}"
InstallDirRegKey HKLM "${REGKEY}" "InstallLocation"
RequestExecutionLevel admin
Unicode True

; Modern UI
!include "MUI2.nsh"
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE   "Install ${APPNAME} ${VERSION}"
!define MUI_WELCOMEPAGE_TEXT    "This will install ${APPNAME} on your computer.$\n$\nClick Next to continue."
!define MUI_FINISHPAGE_RUN      "$INSTDIR\${EXENAME}"
!define MUI_FINISHPAGE_RUN_TEXT "Launch ${APPNAME}"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

; ── Install ────────────────────────────────────────────────────────────────

Section "Main" SecMain
    SetOutPath "$INSTDIR"
    File /r "publish\*.*"

    ; Windows App Runtime bootstrapper (silent install, skips if already present)
    DetailPrint "Checking Windows App Runtime…"
    nsExec::ExecToStack '"$INSTDIR\WindowsAppRuntimeInstall.exe" --quiet'

    ; Shortcuts
    CreateShortcut "$DESKTOP\${APPNAME}.lnk" "$INSTDIR\${EXENAME}"
    CreateDirectory "$SMPROGRAMS\${APPNAME}"
    CreateShortcut "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk" "$INSTDIR\${EXENAME}"
    CreateShortcut "$SMPROGRAMS\${APPNAME}\Uninstall ${APPNAME}.lnk" "$INSTDIR\Uninstall.exe"

    ; Uninstall registry entries
    WriteRegStr   HKLM "${REGKEY}" "DisplayName"      "${APPNAME}"
    WriteRegStr   HKLM "${REGKEY}" "DisplayVersion"   "${VERSION}"
    WriteRegStr   HKLM "${REGKEY}" "Publisher"        "${PUBLISHER}"
    WriteRegStr   HKLM "${REGKEY}" "URLInfoAbout"     "${APPURL}"
    WriteRegStr   HKLM "${REGKEY}" "InstallLocation"  "$INSTDIR"
    WriteRegStr   HKLM "${REGKEY}" "UninstallString"  '"$INSTDIR\Uninstall.exe"'
    WriteRegDWORD HKLM "${REGKEY}" "NoModify"         1
    WriteRegDWORD HKLM "${REGKEY}" "NoRepair"         1

    WriteUninstaller "$INSTDIR\Uninstall.exe"
SectionEnd

; ── Uninstall ──────────────────────────────────────────────────────────────

Section "Uninstall"
    Delete "$DESKTOP\${APPNAME}.lnk"
    RMDir /r "$SMPROGRAMS\${APPNAME}"
    RMDir /r "$INSTDIR"
    DeleteRegKey HKLM "${REGKEY}"
SectionEnd
