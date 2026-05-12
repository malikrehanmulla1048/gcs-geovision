# Fix ALL cross-page navigation links in the GeoVision project
# Each file has consistent nav — this ensures they all point correctly

$base = "c:\Users\Marc Pedrin\Desktop\GCS - GeoVision"

# ── ADMIN PAGES (all in admin/) ──
# These pages should use relative paths like "dashboard.html", NOT "../admin/dashboard.html"
$adminFiles = @(
    "admin\dashboard.html",
    "admin\cctv-feed.html",
    "admin\entry-history.html",
    "admin\security-threats.html",
    "admin\threat-detail.html",
    "admin\student-profile-system-upgraded.html",
    "admin\visitor-management.html"
)

foreach ($f in $adminFiles) {
    $p = Join-Path $base $f
    if (-not (Test-Path $p)) { Write-Host "SKIP (not found): $f"; continue }
    $c = Get-Content $p -Raw -Encoding UTF8

    # Fix nav links that still have ../admin/ prefix (they're already in admin/)
    $c = $c -replace [regex]::Escape("../admin/dashboard.html"),     "dashboard.html"
    $c = $c -replace [regex]::Escape("../admin/cctv-feed.html"),     "cctv-feed.html"
    $c = $c -replace [regex]::Escape("../admin/entry-history.html"), "entry-history.html"
    $c = $c -replace [regex]::Escape("../admin/security-threats.html"), "security-threats.html"
    $c = $c -replace [regex]::Escape("../admin/visitor-management.html"), "visitor-management.html"
    # Also fix ../user/ paths for visitor link
    $c = $c -replace [regex]::Escape("../user/visitor-management.html"), "visitor-management.html"

    Set-Content $p $c -Encoding UTF8
    Write-Host "Fixed admin nav: $f"
}

# ── USER PAGES (in user/) ──
# These should use ../admin/pagename.html for nav
$userFiles = @(
    "user\signup-details.html",
    "user\face_capture_system.html",
    "user\display-details.html"
)

foreach ($f in $userFiles) {
    $p = Join-Path $base $f
    if (-not (Test-Path $p)) { Write-Host "SKIP (not found): $f"; continue }
    $c = Get-Content $p -Raw -Encoding UTF8

    # Fix bare page names that should have ../admin/ prefix
    $c = $c -replace '(?<!admin/)(?<!\.\./)dashboard\.html',         "../admin/dashboard.html"
    $c = $c -replace '(?<!admin/)(?<!\.\./)cctv-feed\.html',         "../admin/cctv-feed.html"
    $c = $c -replace '(?<!admin/)(?<!\.\./)entry-history\.html',     "../admin/entry-history.html"
    $c = $c -replace '(?<!admin/)(?<!\.\./)security-threats\.html',  "../admin/security-threats.html"

    Set-Content $p $c -Encoding UTF8
    Write-Host "Fixed user nav: $f"
}

Write-Host "Done - all navigation paths corrected."
