param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$sourcePath = [IO.Path]::GetFullPath($Source)
$destinationPath = [IO.Path]::GetFullPath($Destination)
$destinationRoot = $destinationPath.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
[IO.Directory]::CreateDirectory($destinationPath) | Out-Null

$archive = [IO.Compression.ZipFile]::OpenRead($sourcePath)
try {
    $entries = @($archive.Entries)
    $total = [Math]::Max(1, $entries.Count)
    $processed = 0
    foreach ($entry in $entries) {
        $name = [string]$entry.FullName
        if ([IO.Path]::IsPathRooted($name) -or $name.Contains(':')) {
            throw "Archive contains an unsafe absolute path: $name"
        }
        $target = [IO.Path]::GetFullPath([IO.Path]::Combine($destinationPath, $name.Replace('/', [IO.Path]::DirectorySeparatorChar)))
        if (-not $target.StartsWith($destinationRoot, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Archive entry escapes the staging directory: $name"
        }
        if ($name.EndsWith('/') -or $name.EndsWith('\')) {
            [IO.Directory]::CreateDirectory($target) | Out-Null
        }
        else {
            $parent = [IO.Path]::GetDirectoryName($target)
            if ($parent) { [IO.Directory]::CreateDirectory($parent) | Out-Null }
            if ([IO.File]::Exists($target)) { [IO.File]::Delete($target) }
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target)
        }
        $processed += 1
        [Console]::Out.WriteLine((@{ processed = $processed; total = $total } | ConvertTo-Json -Compress))
    }
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
finally {
    $archive.Dispose()
}
