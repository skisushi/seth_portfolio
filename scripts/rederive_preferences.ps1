# Re-derive Sarah Chen's preference profile from trip history
# Run this when: significant new trip data, or switching to a new model
# Usage: .\scripts\rederive_preferences.ps1

$API = "http://localhost:8000"
$TRAVELER = "traveler-sc-001"

# Check server is running
try {
    $health = Invoke-RestMethod "$API/health"
} catch {
    Write-Host "ERROR: Preference API is not running. Start it first:" -ForegroundColor Red
    Write-Host "  cd api && python -m uvicorn server:app --port 8000" -ForegroundColor Yellow
    exit 1
}

Write-Host "Deriving preferences for $TRAVELER..." -ForegroundColor Cyan
Write-Host "(This takes 30-60 seconds)"

$result = Invoke-RestMethod -Uri "$API/api/travelers/$TRAVELER/preferences/derive" -Method POST -ContentType "application/json" -TimeoutSec 300

Write-Host ""
Write-Host "Done. Derived from $($result.tripCount) trips at $($result.derivedAt)" -ForegroundColor Green
Write-Host ""
Write-Host "Top carriers:"
$result.airPreferences.preferredCarriers | ForEach-Object { Write-Host "  $($_.carrier) — $($_.confidence) confidence ($($_.percentage)%)" }
Write-Host "Seat preference: $($result.airPreferences.seatType.preference) ($($result.airPreferences.seatType.confidence) confidence)"
Write-Host "Top hotels:"
$result.hotelPreferences.preferredBrands | ForEach-Object { Write-Host "  $($_.brand) — $($_.confidence) confidence ($($_.percentage)%)" }
