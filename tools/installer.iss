; Altrobyte Trainer: one installer, no admin rights, nothing else to install. Built by tools/build_installer.py.
#define AppName "Altrobyte Trainer"
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef SourceDir
  #error SourceDir is required
#endif

[Setup]
AppId={{6D1E5C0A-7B1B-4B7E-9C6B-A17B0B07E001}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Altrobyte Lab
AppPublisherURL=https://altrobytelab.com
DefaultDirName={autopf}\Altrobyte Trainer
DefaultGroupName=Altrobyte
PrivilegesRequired=lowest
OutputDir={#OutDir}
OutputBaseFilename=AltrobyteTrainerSetup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
DisableProgramGroupPage=yes
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible
UninstallDisplayName={#AppName}

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion createallsubdirs

[Icons]
Name: "{autoprograms}\Altrobyte\Altrobyte Trainer"; Filename: "{app}\altrobyte_trainer.exe"
Name: "{autodesktop}\Altrobyte Trainer"; Filename: "{app}\altrobyte_trainer.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Put a shortcut on my desktop"; Flags: checkedonce

[Run]
Filename: "{app}\altrobyte_trainer.exe"; Description: "Open Altrobyte Trainer now"; Flags: nowait postinstall skipifsilent

[Code]
// The helper shares this folder's Python. Stop only the ones that run from here, so an update can replace the files.
procedure StopOurHelper();
var
  code: Integer;
begin
  Exec('powershell.exe',
    '-NoProfile -NonInteractive -Command "Get-Process | Where-Object { $_.Path -like ''' + ExpandConstant('{app}') + '\runtime\*'' } | Stop-Process -Force"',
    '', SW_HIDE, ewWaitUntilTerminated, code);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  StopOurHelper();
  Result := '';
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then StopOurHelper();
end;
