param(
    [string]$Select = ""
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$GodotCandidates = @(
    "C:\Users\n_tin\scoop\apps\godot\4.6.2\godot.console.exe",
    "C:\Users\n_tin\scoop\apps\godot\current\godot.console.exe",
    "godot.console.exe"
)

$GodotExe = $null
foreach ($Candidate in $GodotCandidates) {
    $Command = Get-Command $Candidate -ErrorAction SilentlyContinue
    if ($Command -ne $null) {
        $GodotExe = $Command.Source
        break
    }
}

if ([string]::IsNullOrEmpty($GodotExe)) {
    throw "Could not find godot.console.exe. Install Godot or update tools/run_gut.ps1."
}

$env:APPDATA = Join-Path $RepoRoot ".test_userdata\Roaming"
$env:LOCALAPPDATA = Join-Path $RepoRoot ".test_userdata\Local"
New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA | Out-Null

$Args = @(
    "--headless",
    "-s",
    "res://addons/gut/gut_cmdln.gd",
    "-gexit"
)

if (-not [string]::IsNullOrWhiteSpace($Select)) {
    $Args += "-gselect=$Select"
}

Push-Location $RepoRoot
try {
    & $GodotExe @Args
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
