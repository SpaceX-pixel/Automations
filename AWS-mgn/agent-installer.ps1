<#
.SYNOPSIS
    Installs the AWS MGN replication agent on a Windows server.

.DESCRIPTION
    Downloads and installs the AWS Application Migration Service (MGN) replication
    agent using the provided AWS credentials and region. Handles TLS/SSL issues
    on older PowerShell versions automatically.

.PARAMETER AWSRegion
    The AWS region where MGN is configured (e.g. "eu-central-1", "us-west-2").

.PARAMETER AzureRegion
    Display name for the source Azure region (e.g. "West Europe"). Used for logging only.

.PARAMETER AWSAccessKeyId
    AWS Access Key ID with MGN permissions.

.PARAMETER AWSSecretAccessKey
    AWS Secret Access Key corresponding to AWSAccessKeyId.

.PARAMETER TempDir
    Temporary directory for the installer download. Default: C:\temp\aws-migration-service

.EXAMPLE
    Install-MGNAgent -AWSRegion "eu-central-1" -AzureRegion "West Europe" `
                     -AWSAccessKeyId "<access_key>" -AWSSecretAccessKey "<secret_key>"

.EXAMPLE
    Install-MGNAgent -AWSRegion "us-west-2" -AzureRegion "West US" `
                     -AWSAccessKeyId "<access_key>" -AWSSecretAccessKey "<secret_key>" `
                     -TempDir "D:\temp\mgn"

.NOTES
    Requires administrative privileges.
    To load the function without running it:
        . .\mgn-agent-installation.ps1
    Then call:
        Install-MGNAgent -AWSRegion "eu-central-1" ...
#>
function Install-MGNAgent {
    param(
        [Parameter(Mandatory=$true)]  [string]$AWSRegion,
        [Parameter(Mandatory=$true)]  [string]$AzureRegion,
        [Parameter(Mandatory=$true)]  [string]$AWSAccessKeyId,
        [Parameter(Mandatory=$true)]  [string]$AWSSecretAccessKey,
        [string]$TempDir = 'C:\temp\aws-migration-service'
    )

    if ([string]::IsNullOrEmpty($AWSAccessKeyId) -or [string]::IsNullOrEmpty($AWSSecretAccessKey)) {
        Write-Error "AWS Access Key ID and Secret Access Key must be provided."
        return
    }

    $Server = $env:COMPUTERNAME.ToLower()

    if (!(Test-Path $TempDir)) { New-Item -ItemType Directory -Force -Path $TempDir | Out-Null }
    Set-Location $TempDir

    $InstallerUrl = "https://aws-application-migration-service-$AWSRegion.s3.$AWSRegion.amazonaws.com/latest/windows/AwsReplicationWindowsInstaller.exe"

    Write-Host "Installing MGN agent to AWS region: $AWSRegion, Azure region: $AzureRegion" -ForegroundColor Cyan
    Write-Host "Server hostname: $Server" -ForegroundColor Gray

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    try {
        Write-Host "Downloading installer from: $InstallerUrl"
        Invoke-WebRequest -Uri $InstallerUrl -OutFile 'AwsReplicationWindowsInstaller.exe' -UseBasicParsing

        if (!(Test-Path 'AwsReplicationWindowsInstaller.exe')) {
            throw "Download failed: Installer file not found after download attempt."
        }

        Start-Process -FilePath '.\AwsReplicationWindowsInstaller.exe' -ArgumentList @(
            '--region', $AWSRegion,
            '--aws-access-key-id', $AWSAccessKeyId,
            '--aws-secret-access-key', $AWSSecretAccessKey,
            '--user-provided-id', $Server,
            '--no-prompt'
        ) -Wait

        Write-Host "AWS MGN agent installation completed successfully." -ForegroundColor Green
    } catch {
        Write-Error "Installation failed: $($_.Exception.Message)"
        if ($_.Exception.InnerException) { Write-Error "Inner exception: $($_.Exception.InnerException.Message)" }
    } finally {
        if (Test-Path 'AwsReplicationWindowsInstaller.exe') { Remove-Item 'AwsReplicationWindowsInstaller.exe' -Force }
    }
}

# Run with eu-central-1 defaults
Install-MGNAgent -AWSRegion "eu-central-1" -AzureRegion "West Europe" `
                 -AWSAccessKeyId "<access_key>" -AWSSecretAccessKey "<secret_key>"
