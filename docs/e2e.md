# E2E

Offline Lua hook tests (`tests/hooks_test.lua`) run via the **Test Plugin** workflow.
A containerized end-to-end suite exercises the plugin against real vfox (`latest` +
`main`) on Linux and Windows. Each of the four `vfox` x `flavor` combinations runs in
its own throwaway container, so no state leaks between them.

## Running on Ubuntu 26.04

Assume that Git and Docker Engine (in either rootful or rootless mode) are already installed.

Execute in Bash,

```bash
git clone git@github.com:version-fox/vfox-flutter.git
cd ./vfox-flutter/
bash tests/e2e/linux/e2e.sh
```

## Running on Windows 11 Pro

Assume Git for Windows and PowerShell 7 are already installed.

1. Execute in PowerShell 7,

```powershell
Invoke-WebRequest -UseBasicParsing `
    "https://raw.githubusercontent.com/microsoft/Windows-Containers/Main/helpful_tools/Install-DockerCE/install-docker-ce.ps1" `
    -OutFile ./install-docker-ce.ps1
```

2. Execute in PowerShell 7 with administrator privileges,

```powershell
./install-docker-ce.ps1
```

3. Execute in PowerShell 7,

```powershell
git clone git@github.com:version-fox/vfox-flutter.git
cd ./vfox-flutter/
pwsh -NoProfile -ExecutionPolicy Bypass -File .\tests\e2e\windows\e2e.ps1
```
