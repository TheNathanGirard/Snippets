param(
    [Parameter(Mandatory)]
    [string]$TargetFolder,          # Example: D:\Bench

    [string]$DiskSpd = "C:\Tools\diskspd.exe",

    [int]$FileSizeGB = 4,
    [int]$DurationSeconds = 15,
    [int]$WarmupSeconds = 5
)

if (-not (Test-Path $DiskSpd)) {
    throw "diskspd.exe not found at $DiskSpd"
}

if (-not (Test-Path $TargetFolder)) {
    New-Item -ItemType Directory -Path $TargetFolder | Out-Null
}

$testFile = Join-Path $TargetFolder "ps-cdm-like-testfile.dat"
$fileSize = "${FileSizeGB}G"

$tests = @(
    @{ Name = "SEQ1M Q8T1 Read";  Block = "1M"; Threads = 1; Queue = 8;  Random = $false; WritePct = 0   },
    @{ Name = "SEQ1M Q8T1 Write"; Block = "1M"; Threads = 1; Queue = 8;  Random = $false; WritePct = 100 },

    @{ Name = "SEQ1M Q1T1 Read";  Block = "1M"; Threads = 1; Queue = 1;  Random = $false; WritePct = 0   },
    @{ Name = "SEQ1M Q1T1 Write"; Block = "1M"; Threads = 1; Queue = 1;  Random = $false; WritePct = 100 },

    @{ Name = "RND4K Q32T1 Read";  Block = "4K"; Threads = 1; Queue = 32; Random = $true; WritePct = 0   },
    @{ Name = "RND4K Q32T1 Write"; Block = "4K"; Threads = 1; Queue = 32; Random = $true; WritePct = 100 },

    @{ Name = "RND4K Q1T1 Read";  Block = "4K"; Threads = 1; Queue = 1;  Random = $true; WritePct = 0   },
    @{ Name = "RND4K Q1T1 Write"; Block = "4K"; Threads = 1; Queue = 1;  Random = $true; WritePct = 100 }
)

function Invoke-DiskSpdTest {
    param($Test)

    $args = @(
        "-c$fileSize",
        "-d$DurationSeconds",
        "-W$WarmupSeconds",
        "-b$($Test.Block)",
        "-t$($Test.Threads)",
        "-o$($Test.Queue)",
        "-w$($Test.WritePct)",
        "-Sh",        # disable software/hardware caching where supported
        "-L",         # latency statistics
        "-Rxml"       # XML output
    )

    if ($Test.Random) {
        $args += "-r"
    }

    $args += $testFile

    Write-Host "Running $($Test.Name)..." -ForegroundColor Cyan

    $raw = & $DiskSpd @args 2>&1 | Out-String

    $xmlStart = $raw.IndexOf("<?xml")
    if ($xmlStart -lt 0) {
        return [pscustomobject]@{
            Test  = $Test.Name
            MBps  = $null
            IOPS  = $null
            Notes = "Could not parse XML output"
        }
    }

    [xml]$xml = $raw.Substring($xmlStart)

    $secondsNode = $xml.SelectSingleNode("//TestTimeSeconds")
    $seconds = [double]$secondsNode.InnerText

    $targets = $xml.SelectNodes("//Target")

    $readBytes = 0L
    $writeBytes = 0L
    $readCount = 0L
    $writeCount = 0L

    foreach ($target in $targets) {
        if ($target.ReadBytes)  { $readBytes  += [int64]$target.ReadBytes }
        if ($target.WriteBytes) { $writeBytes += [int64]$target.WriteBytes }
        if ($target.ReadCount)  { $readCount  += [int64]$target.ReadCount }
        if ($target.WriteCount) { $writeCount += [int64]$target.WriteCount }
    }

    if ($Test.WritePct -eq 100) {
        $bytes = $writeBytes
        $ops = $writeCount
    } else {
        $bytes = $readBytes
        $ops = $readCount
    }

    [pscustomobject]@{
        Test = $Test.Name
        "MiB/s" = [math]::Round(($bytes / 1MB) / $seconds, 2)
        IOPS = [math]::Round($ops / $seconds, 0)
        Seconds = $seconds
        File = $testFile
    }
}

$results = foreach ($test in $tests) {
    Invoke-DiskSpdTest -Test $test
}

$results | Format-Table -AutoSize

# Optional cleanup prompt
$answer = Read-Host "Delete test file $testFile ? [y/N]"
if ($answer -match '^(y|yes)$') {
    Remove-Item $testFile -Force
}