<powershell>
$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"
$LogDir  = "C:\UserData"
$LogFile = "$LogDir\setup.log"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry     = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $entry
    Write-Host $entry
}
Write-Log "===== USER DATA SCRIPT STARTED ====="
Write-Log "Computer Name: $env:COMPUTERNAME"
Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)"
Write-Log "Configuring Windows settings..."
Set-TimeZone -Name "GMT Standard Time"
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -Name "NoAutoUpdate" -Value 0 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -Name "AUOptions" -Value 3 -Type DWord -Force
auditpol /set /subcategory:"Logon" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Logoff" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Account Logon" /success:enable /failure:enable | Out-Null
Write-Log "Windows configuration complete."
Write-Log "Installing Chocolatey package manager..."
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    $chocoInstall = Invoke-WebRequest -Uri 'https://community.chocolatey.org/install.ps1' -UseBasicParsing
    Invoke-Expression $chocoInstall.Content
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
    Write-Log "Chocolatey installed successfully."
} else {
    Write-Log "Chocolatey already installed — skipping."
}
Write-Log "Installing .NET 8 LTS Runtime and SDK..."
try {
    choco install dotnet-8.0-sdk --yes --no-progress 2>&1 | ForEach-Object { Write-Log $_ }
    choco install netfx-4.8-devpack --yes --no-progress 2>&1 | ForEach-Object { Write-Log $_ }
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
    $dotnetVersion = & dotnet --version 2>&1
    Write-Log ".NET version: $dotnetVersion"
    Write-Log ".NET 8 installation complete."
} catch {
    Write-Log "ERROR installing .NET 8: $_" "ERROR"
}
Write-Log "Installing SQL Server 2022 Express..."
try {
    $sqlInstallDir = "C:\SQLServerInstall"
    if (-not (Test-Path $sqlInstallDir)) { New-Item -ItemType Directory -Force -Path $sqlInstallDir | Out-Null }
    $sqlInstallerUrl = "https://go.microsoft.com/fwlink/p/?linkid=2216695"
    $sqlBootstrapper = "$sqlInstallDir\sql2022-ssei-expr.exe"
    Write-Log "Downloading SQL Server 2022 Express bootstrapper..."
    Invoke-WebRequest -Uri $sqlInstallerUrl -OutFile $sqlBootstrapper -UseBasicParsing
    Write-Log "Downloading SQL Server Express full installer..."
    $sqlFullInstallerPath = "$sqlInstallDir\SQLEXPR_x64_ENU.exe"
    Start-Process -FilePath $sqlBootstrapper `
        -ArgumentList "/ACTION=Download", "/MEDIAPATH=$sqlInstallDir", "/MEDIATYPE=Core", "/QUIET" `
        -Wait -NoNewWindow
    $sqlInstaller = Get-ChildItem -Path $sqlInstallDir -Filter "SQLEXPR*.exe" | Select-Object -First 1
    if ($null -eq $sqlInstaller) {
        throw "SQL Server installer not found in $sqlInstallDir"
    }
    Write-Log "Running SQL Server Express installer..."
    $sqlArgs = @(
        "/Q",
        "/ACTION=Install",
        "/FEATURES=SQLEngine,Tools",
        "/INSTANCENAME=SQLEXPRESS",
        "/SQLSVCACCOUNT=`"NT AUTHORITY\NETWORK SERVICE`"",
        "/SQLSYSADMINACCOUNTS=`"BUILTIN\Administrators`"",
        "/SECURITYMODE=SQL",
        "/SAPWD=`"${sql_admin_password}`"",
        "/TCPENABLED=1",
        "/NPENABLED=0",
        "/IACCEPTSQLSERVERLICENSETERMS",
        "/UPDATEENABLED=FALSE"
    )
    Start-Process -FilePath $sqlInstaller.FullName -ArgumentList $sqlArgs -Wait -NoNewWindow
    Write-Log "SQL Server Express installation complete."
    Set-Service -Name "SQLBrowser" -StartupType Automatic
    Start-Service -Name "SQLBrowser" -ErrorAction SilentlyContinue
    $sqlSmo = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement")
    if ($sqlSmo) {
        $mc = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer
        $instance = $mc.ServerInstances | Where-Object { $_.Name -eq "SQLEXPRESS" }
        if ($instance) {
            $np = $instance.ServerProtocols | Where-Object { $_.Name -eq "Np" }
            if ($np) { $np.IsEnabled = $false; $np.Alter() }
            $tcp = $instance.ServerProtocols | Where-Object { $_.Name -eq "Tcp" }
            if ($tcp) { $tcp.IsEnabled = $true; $tcp.Alter() }
        }
    }
} catch {
    Write-Log "ERROR installing SQL Server: $_" "ERROR"
    Write-Log "You can install SQL Server manually after connecting via SSM." "WARN"
}
Write-Log "Installing SQL Server Management Studio (SSMS)..."
try {
    choco install sql-server-management-studio --yes --no-progress --timeout 3600 2>&1 | ForEach-Object { Write-Log $_ }
    Write-Log "SSMS installation complete."
} catch {
    Write-Log "ERROR installing SSMS: $_" "ERROR"
    Write-Log "You can install SSMS manually: choco install sql-server-management-studio" "WARN"
}
Write-Log "Installing Power BI Desktop..."
try {
    choco install powerbi --yes --no-progress --timeout 3600 2>&1 | ForEach-Object { Write-Log $_ }
    Write-Log "Power BI Desktop installation complete."
} catch {
    Write-Log "Chocolatey PowerBI package failed, trying direct download..." "WARN"
    try {
        $pbiUrl = "https://go.microsoft.com/fwlink/?LinkId=2240819&clcid=0x409"
        $pbiInstaller = "C:\UserData\PBIDesktopSetup_x64.exe"
        Invoke-WebRequest -Uri $pbiUrl -OutFile $pbiInstaller -UseBasicParsing
        Start-Process -FilePath $pbiInstaller -ArgumentList "-q", "-norestart" -Wait -NoNewWindow
        Write-Log "Power BI Desktop (direct download) installation complete."
    } catch {
        Write-Log "ERROR installing Power BI Desktop: $_" "ERROR"
        Write-Log "Install manually after connecting: winget install Microsoft.PowerBIDesktop" "WARN"
    }
}
Write-Log "Installing additional developer tools..."
try {
    choco install vscode --yes --no-progress 2>&1 | ForEach-Object { Write-Log $_ }
    choco install git --yes --no-progress 2>&1 | ForEach-Object { Write-Log $_ }
    choco install azure-data-studio --yes --no-progress 2>&1 | ForEach-Object { Write-Log $_ }
    Write-Log "Additional tools installation complete."
} catch {
    Write-Log "Some additional tools failed to install: $_" "WARN"
}
Write-Log "Installing AWS CloudWatch Agent..."
try {
    $cwAgentUrl = "https://s3.amazonaws.com/amazoncloudwatch-agent/windows/amd64/latest/amazon-cloudwatch-agent.msi"
    $cwAgentMsi = "C:\UserData\amazon-cloudwatch-agent.msi"
    Invoke-WebRequest -Uri $cwAgentUrl -OutFile $cwAgentMsi -UseBasicParsing
    Start-Process msiexec.exe -ArgumentList "/i", $cwAgentMsi, "/quiet" -Wait -NoNewWindow
    Write-Log "CloudWatch Agent installed."
    $cwAgentConfig = @'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "metrics": {
    "namespace": "${cloudwatch_namespace}",
    "metrics_collected": {
      "Memory": {
        "measurement": ["% Committed Bytes In Use"],
        "metrics_collection_interval": 60
      },
      "LogicalDisk": {
        "measurement": ["% Free Space", "Free Megabytes"],
        "metrics_collection_interval": 60,
        "resources": ["C:", "D:"]
      },
      "Processor": {
        "measurement": ["% Processor Time", "% User Time", "% Idle Time"],
        "metrics_collection_interval": 60,
        "resources": ["_Total"]
      },
      "TCPv4": {
        "measurement": ["Connections Established"],
        "metrics_collection_interval": 60
      }
    },
    "append_dimensions": {
      "InstanceId": "$${aws:InstanceId}",
      "InstanceType": "$${aws:InstanceType}",
      "AutoScalingGroupName": "$${aws:AutoScalingGroupName}"
    }
  },
  "logs": {
    "logs_collected": {
      "windows_events": {
        "collect_list": [
          {
            "event_name": "System",
            "event_levels": ["WARNING", "ERROR", "CRITICAL"],
            "log_group_name": "${log_group_name}/system",
            "log_stream_name": "{instance_id}"
          },
          {
            "event_name": "Application",
            "event_levels": ["WARNING", "ERROR", "CRITICAL"],
            "log_group_name": "${log_group_name}/application",
            "log_stream_name": "{instance_id}"
          },
          {
            "event_name": "Security",
            "event_levels": ["WARNING", "ERROR", "CRITICAL", "INFORMATION"],
            "log_group_name": "${log_group_name}/security",
            "log_stream_name": "{instance_id}"
          }
        ]
      },
      "files": {
        "collect_list": [
          {
            "file_path": "C:\\UserData\\setup.log",
            "log_group_name": "${log_group_name}/userdata",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
'@
    $cwConfigPath = "C:\ProgramData\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent.json"
    $cwAgentConfig | Out-File -FilePath $cwConfigPath -Encoding utf8 -Force
    $cwCtl = "C:\Program Files\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1"
    if (Test-Path $cwCtl) {
        & $cwCtl -a fetch-config -m ec2 -c file:$cwConfigPath -s
        Write-Log "CloudWatch Agent configured and started."
    }
} catch {
    Write-Log "ERROR with CloudWatch Agent: $_" "ERROR"
}
Write-Log "Applying Windows Firewall rules..."
netsh advfirewall firewall add rule name="Block NetBIOS" protocol=TCP dir=in localport=137,138,139 action=block
netsh advfirewall firewall add rule name="Block SMB" protocol=TCP dir=in localport=445 action=block
Write-Log "Firewall rules applied."
Write-Log "Setting up D: drive directory structure..."
$directories = @(
    "D:\SQLData",
    "D:\SQLLogs",
    "D:\SQLBackups",
    "D:\Projects",
    "D:\PowerBI",
    "D:\Scripts"
)
foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        Write-Log "Created directory: $dir"
    }
}
Write-Log "===== USER DATA SCRIPT COMPLETED SUCCESSFULLY ====="
Write-Log "Software installed:"
Write-Log "  - .NET 8 LTS SDK"
Write-Log "  - SQL Server 2022 Express (instance: SQLEXPRESS)"
Write-Log "  - SQL Server Management Studio (SSMS)"
Write-Log "  - Power BI Desktop"
Write-Log "  - Visual Studio Code"
Write-Log "  - Git"
Write-Log "  - AWS CloudWatch Agent"
Write-Log ""
Write-Log "Next steps:"
Write-Log "  1. Connect via AWS SSM Session Manager"
Write-Log "  2. Check this log: C:\UserData\setup.log"
Write-Log "  3. Reboot may be required for some components"
$completionFlag = "C:\UserData\setup_complete.flag"
Get-Date | Out-File $completionFlag
</powershell>
<persist>true</persist>
