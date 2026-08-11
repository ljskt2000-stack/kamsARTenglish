param(
    [string]$DataPath = (Join-Path $PSScriptRoot '..\data\posts.json'),
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\assets\thumbnails'),
    [int]$MaxSize = 900,
    [int]$JpegQuality = 82
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$utf8 = [System.Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.Drawing

$posts = Get-Content -LiteralPath $DataPath -Raw -Encoding UTF8 | ConvertFrom-Json
[IO.Directory]::CreateDirectory([IO.Path]::GetFullPath($OutputDirectory)) | Out-Null
$encoder = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq 'image/jpeg'
$encoderParameters = [Drawing.Imaging.EncoderParameters]::new(1)
$encoderParameters.Param[0] = [Drawing.Imaging.EncoderParameter]::new(
    [Drawing.Imaging.Encoder]::Quality,
    [long]$JpegQuality
)

$index = 0
foreach ($post in $posts) {
    $index++
    $id = [string]$post.id
    $sourceUrl = if ($post.sourceThumbnail) { [string]$post.sourceThumbnail } else { [string]$post.thumbnail }
    $relativePath = "assets/thumbnails/$id.jpg"
    $destination = Join-Path $OutputDirectory "$id.jpg"

    if (Test-Path -LiteralPath $destination) {
        if (-not $post.sourceThumbnail) { $post | Add-Member -NotePropertyName sourceThumbnail -NotePropertyValue $sourceUrl }
        $post.thumbnail = $relativePath
        Write-Output "IMAGE $index/$($posts.Count) $id cached"
        continue
    }

    $tempFile = Join-Path ([IO.Path]::GetTempPath()) "kams-$id-source.img"
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $sourceUrl -Headers @{
            'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            'Referer' = [string]$post.originalUrl
        } -OutFile $tempFile -TimeoutSec 40

        $source = [Drawing.Image]::FromFile($tempFile)
        try {
            $scale = [Math]::Min(1, $MaxSize / [double][Math]::Max($source.Width, $source.Height))
            $width = [Math]::Max(1, [int][Math]::Round($source.Width * $scale))
            $height = [Math]::Max(1, [int][Math]::Round($source.Height * $scale))
            $bitmap = [Drawing.Bitmap]::new($width, $height)
            try {
                $graphics = [Drawing.Graphics]::FromImage($bitmap)
                try {
                    $graphics.Clear([Drawing.ColorTranslator]::FromHtml('#FCE9E2'))
                    $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::HighQuality
                    $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                    $graphics.DrawImage($source, 0, 0, $width, $height)
                }
                finally { $graphics.Dispose() }
                $bitmap.Save($destination, $encoder, $encoderParameters)
            }
            finally { $bitmap.Dispose() }
        }
        finally { $source.Dispose() }

        if (-not $post.sourceThumbnail) { $post | Add-Member -NotePropertyName sourceThumbnail -NotePropertyValue $sourceUrl }
        $post.thumbnail = $relativePath
        Write-Output "IMAGE $index/$($posts.Count) $id ok"
    }
    catch {
        Write-Warning "IMAGE $index/$($posts.Count) $id failed: $($_.Exception.Message)"
    }
    finally {
        if (Test-Path -LiteralPath $tempFile) { Remove-Item -LiteralPath $tempFile -Force }
    }
}

$json = $posts | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText([IO.Path]::GetFullPath($DataPath), $json, $utf8)
$encoderParameters.Dispose()

Write-Output "DONE images=$($posts.Count) directory=$OutputDirectory"
