; Inno Setup script for the Smart Planner Windows release.
; The build workflow compiles this with:
;   ISCC.exe /DAppVersion=<x.y.z> windows/installer/planner.iss
; Paths below are relative to this script (windows/installer/).

#define AppName "Smart Planner"
#define AppExeName "planner.exe"

#ifndef AppVersion
#error The AppVersion define must be supplied (e.g. /DAppVersion=1.0.0)
#endif

[Setup]
AppId={{C8F4A3E2-6B71-4D5C-9A0E-13F52C7B9D04}}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Lite Systems
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
; The release bundle is x64; install into "Program Files" on 64-bit Windows.
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\..\build\windows\artifacts
OutputBaseFilename=planner
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

; User SQLite data lives in the per-user Application Support directory
; (_configureDesktopDatabase() in lib/main.dart) and must survive an
; uninstall intentionally — so no [UninstallDelete] section is configured.
