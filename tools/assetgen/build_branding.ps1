$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$output = Join-Path $PSScriptRoot "..\..\assets\generated\branding"
[System.IO.Directory]::CreateDirectory($output) | Out-Null
$cream = [System.Drawing.Color]::FromArgb(246, 239, 226)
$gold = [System.Drawing.Color]::FromArgb(247, 181, 74)
$ink = [System.Drawing.Color]::FromArgb(14, 11, 20)
$edge = [System.Drawing.Color]::FromArgb(76, 59, 39)

# Original centerline lettering, in a common 100-unit cap-height coordinate space.
$glyphs = @{
    A = @(@("M", 4, 99), @("L", 35, 4), @("L", 66, 99), @("M", 16, 63), @("L", 54, 63))
    S = @(@("M", 60, 15), @("C", 46, -1, 7, 0, 7, 26), @("C", 7, 50, 61, 43, 61, 73), @("C", 61, 101, 22, 108, 5, 87))
    T = @(@("M", 4, 4), @("L", 66, 4), @("M", 35, 4), @("L", 35, 99))
    R = @(@("M", 6, 99), @("L", 6, 4), @("L", 34, 4), @("C", 76, 4, 77, 52, 34, 52), @("L", 6, 52), @("M", 34, 52), @("L", 68, 99))
    L = @(@("M", 6, 4), @("L", 6, 99), @("L", 62, 99))
    F = @(@("M", 6, 99), @("L", 6, 4), @("L", 64, 4), @("M", 6, 49), @("L", 53, 49))
    O = @(@("M", 6, 31), @("C", 6, -6, 68, -6, 68, 31), @("L", 68, 72), @("C", 68, 110, 6, 110, 6, 72), @("L", 6, 31))
    G = @(@("M", 66, 22), @("C", 55, -7, 6, 0, 6, 34), @("L", 6, 70), @("C", 6, 108, 68, 110, 68, 75), @("L", 68, 58), @("L", 42, 58))
    E = @(@("M", 64, 4), @("L", 6, 4), @("L", 6, 99), @("L", 64, 99), @("M", 6, 49), @("L", 54, 49))
}

function Draw-Letter($graphics, $letter, $x, $y, $scale, $color, $weight) {
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $pen = [System.Drawing.Pen]::new($color, [single]($weight * $scale))
    $pen.StartCap = $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $px = $py = 0
    try {
        foreach ($command in $glyphs[$letter]) {
            if ($command[0] -eq "M") {
                $path.StartFigure()
                $px = $command[1]; $py = $command[2]
            } elseif ($command[0] -eq "L") {
                $path.AddLine([single]($x + $px * $scale), [single]($y + $py * $scale),
                    [single]($x + $command[1] * $scale), [single]($y + $command[2] * $scale))
                $px = $command[1]; $py = $command[2]
            } else {
                $path.AddBezier([single]($x + $px * $scale), [single]($y + $py * $scale),
                    [single]($x + $command[1] * $scale), [single]($y + $command[2] * $scale),
                    [single]($x + $command[3] * $scale), [single]($y + $command[4] * $scale),
                    [single]($x + $command[5] * $scale), [single]($y + $command[6] * $scale))
                $px = $command[5]; $py = $command[6]
            }
        }
        $graphics.DrawPath($pen, $path)
    } finally {
        $pen.Dispose(); $path.Dispose()
    }
}

function Draw-Word($graphics, $word, $x, $y, $scale, $tracking, $color, $weight) {
    foreach ($letter in $word.ToCharArray()) {
        Draw-Letter $graphics ([string]$letter) $x $y $scale $color $weight
        $x += (74 + $tracking) * $scale
    }
}

function Draw-Mark($graphics, $scale) {
    $state = $graphics.Save()
    $anvil = [System.Drawing.SolidBrush]::new($gold)
    try {
        $graphics.ScaleTransform([single]$scale, [single]$scale)
        Draw-Letter $graphics "A" 76 102 2.35 $cream 12
        Draw-Letter $graphics "F" 302 120 2.17 $gold 12
        $points = [System.Drawing.PointF[]]@(
            [System.Drawing.PointF]::new(112, 376), [System.Drawing.PointF]::new(413, 376),
            [System.Drawing.PointF]::new(390, 398), [System.Drawing.PointF]::new(302, 420),
            [System.Drawing.PointF]::new(294, 440), [System.Drawing.PointF]::new(222, 440),
            [System.Drawing.PointF]::new(214, 420), [System.Drawing.PointF]::new(134, 398)
        )
        $graphics.FillPolygon($anvil, $points)
    } finally {
        $anvil.Dispose(); $graphics.Restore($state)
    }
}

function Write-Art($name, $width, $height, $draw) {
    $bitmap = [System.Drawing.Bitmap]::new($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        & $draw $graphics
        $path = Join-Path $output "$name.png"
        $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Output "$name : $width x $height : $path"
    } finally {
        $graphics.Dispose(); $bitmap.Dispose()
    }
}

Write-Art "wordmark" 4096 1536 {
    param($g)
    Draw-Word $g "ASTRAL" 168 110 7.4 12 $cream 9
    Draw-Word $g "FORGE" 168 992 4.6 109 $gold 12
}
Write-Art "compact-mark" 1024 1024 { param($g) Draw-Mark $g 2 }
Write-Art "game-icon" 2048 2048 {
    param($g)
    $g.Clear($ink)
    $pen = [System.Drawing.Pen]::new($edge, 8)
    try {
        $g.DrawRectangle($pen, 96, 96, 1856, 1856)
        Draw-Mark $g 4
    } finally { $pen.Dispose() }
}
