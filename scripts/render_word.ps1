# Native Word fallback when LibreOffice is unavailable. QA images are internal.
param([string]$InputFile = 'docs/Project_2_Report.docx', [string]$OutputDir = 'docs/qa')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$inputPath = (Resolve-Path -LiteralPath $InputFile).Path
New-Item -ItemType Directory -Force $OutputDir | Out-Null
$outputPath = (Resolve-Path -LiteralPath $OutputDir).Path
$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0
$document = $null
try {
    $document = $word.Documents.Open($inputPath, $false, $true)
    $document.ActiveWindow.View.Type = 3
    $document.Repaginate()
    $count = $document.ComputeStatistics(2)
    $pagination = @()
    foreach ($paragraph in $document.Paragraphs) {
        $text = $paragraph.Range.Text.Trim()
        if ($text.Length -gt 0) { $pagination += ('{0}: {1}' -f $paragraph.Range.Information(3), $text) }
    }
    $pagination | Set-Content -LiteralPath (Join-Path $outputPath 'pagination.txt') -Encoding UTF8
    for ($i = 1; $i -le $count; $i++) {
        $bits = $document.ActiveWindow.Panes.Item(1).Pages.Item($i).EnhMetaFileBits
        $stream = New-Object System.IO.MemoryStream(,$bits)
        $metafile = [System.Drawing.Image]::FromStream($stream)
        $bitmap = New-Object System.Drawing.Bitmap(1275,1650)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([System.Drawing.Color]::White)
            $graphics.DrawImage($metafile,0,0,1275,1650)
            $bitmap.Save((Join-Path $outputPath "page-$i.png"),[System.Drawing.Imaging.ImageFormat]::Png)
        } finally { $graphics.Dispose(); $bitmap.Dispose(); $metafile.Dispose(); $stream.Dispose() }
    }
    Write-Output "Rendered $count pages using native Word."
} finally {
    if ($null -ne $document) { $document.Close(0) }
    $word.Quit()
}
