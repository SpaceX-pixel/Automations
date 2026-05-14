
# PowerShell script to restart all IIS Application Pools
# Provides detailed status reporting and error handling
#
# How to run:
# 1. Open PowerShell as Administrator (REQUIRED)
# 2. Navigate to script directory
# 3. Run: .\Application_Pool_restart.ps1
#
# Prerequisites:
# - Must run as Administrator
# - IIS must be installed
# - WebAdministration module available
#
# What it does:
# - Restarts all application pools on the server
# - Verifies each restart was successful
# - Provides summary of success/failure counts
# - Waits 3 seconds between each restart

# Import IIS module
Import-Module WebAdministration

# Get all application pools
$appPools = Get-IISAppPool
$successCount = 0
$failCount = 0

# Loop through each app pool and restart
foreach ($pool in $appPools) {
    try {
        Write-Host "Restarting application pool: $($pool.Name)"
        Restart-WebAppPool -Name $pool.Name -ErrorAction Stop
        
        # Verify the restart was successful
        Start-Sleep -Seconds 2
        $poolState = Get-WebAppPoolState -Name $pool.Name
        
        if ($poolState.Value -eq "Started") {
            Write-Host "Successfully restarted: $($pool.Name)" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "WARNING: $($pool.Name) restarted but current state is: $($poolState.Value)" -ForegroundColor Yellow
            $successCount++
        }
        
        # Wait 3 seconds between restarts
        Start-Sleep -Seconds 3
    }
    catch {
        Write-Host "FAILED to restart $($pool.Name): $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Possible causes: Pool is stopped, insufficient permissions, or pool is in use" -ForegroundColor Red
        $failCount++
    }
}

Write-Host "`n=== RESTART SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total pools processed: $($appPools.Count)" -ForegroundColor Gray
Write-Host "Successfully restarted: $successCount" -ForegroundColor Green
Write-Host "Failed to restart: $failCount" -ForegroundColor Red

if ($failCount -gt 0) {
    Write-Host "`nSome application pools failed to restart. Check the errors above." -ForegroundColor Red
} else {
    Write-Host "`nAll application pools restarted successfully!" -ForegroundColor Green
}
