Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$indigo = [System.Drawing.ColorTranslator]::FromHtml('#4F3FE8')
$white = [System.Drawing.Color]::White
$lime = [System.Drawing.ColorTranslator]::FromHtml('#C8F568')

function Draw-Racket($graphics) {
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $state = $graphics.Save()
  $graphics.TranslateTransform(256, 256)
  $graphics.RotateTransform(-32)
  $graphics.TranslateTransform(-256, -256)

  $shaft = [System.Drawing.Pen]::new($white, 18)
  $shaft.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $shaft.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $graphics.DrawLine($shaft, 256, 298, 256, 405)
  $shaft.Dispose()

  $handle = [System.Drawing.Pen]::new($lime, 30)
  $handle.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $handle.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $graphics.DrawLine($handle, 256, 394, 256, 449)
  $handle.Dispose()

  $netPath = [System.Drawing.Drawing2D.GraphicsPath]::new()
  $netPath.AddEllipse(177, 79, 158, 227)
  $graphics.SetClip($netPath)
  $net = [System.Drawing.Pen]::new($lime, 4)
  foreach ($x in @(207, 239, 272, 304)) {
    $graphics.DrawLine($net, $x, 75, $x, 310)
  }
  foreach ($y in @(119, 157, 195, 233, 271)) {
    $graphics.DrawLine($net, 170, $y, 342, $y)
  }
  $net.Dispose()
  $graphics.ResetClip()
  $netPath.Dispose()

  $head = [System.Drawing.Pen]::new($white, 17)
  $graphics.DrawEllipse($head, 177, 79, 158, 227)
  $head.Dispose()

  $graphics.Restore($state)
  $shuttle = [System.Drawing.Pen]::new($lime, 10)
  $shuttle.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $shuttle.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $graphics.DrawLine($shuttle, 350, 98, 397, 49)
  $graphics.DrawLine($shuttle, 350, 98, 416, 77)
  $graphics.DrawLine($shuttle, 350, 98, 390, 111)
  $shuttle.Dispose()
  $tip = [System.Drawing.SolidBrush]::new($white)
  $graphics.FillEllipse($tip, 329, 92, 32, 23)
  $tip.Dispose()
}

function Save-Icon($path, $size, $transparent) {
  $bitmap = [System.Drawing.Bitmap]::new($size, $size)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  if ($transparent) {
    $graphics.Clear([System.Drawing.Color]::Transparent)
  } else {
    $graphics.Clear($indigo)
  }
  $graphics.ScaleTransform($size / 512, $size / 512)
  if ($transparent) {
    # Android's adaptive icon and splash mask crop the outer 18%.
    $graphics.TranslateTransform(256, 256)
    $graphics.ScaleTransform(0.7, 0.7)
    $graphics.TranslateTransform(-256, -256)
  }
  Draw-Racket $graphics
  $graphics.Dispose()
  $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bitmap.Dispose()
}

$densities = @{ mdpi = 1; hdpi = 1.5; xhdpi = 2; xxhdpi = 3; xxxhdpi = 4 }
foreach ($entry in $densities.GetEnumerator()) {
  $directory = Join-Path $root "android/app/src/main/res/mipmap-$($entry.Key)"
  Save-Icon (Join-Path $directory 'ic_launcher.png') ([int](48 * $entry.Value)) $false
  Save-Icon (Join-Path $directory 'ic_launcher_foreground.png') ([int](108 * $entry.Value)) $true
}

Save-Icon (Join-Path $root 'assets/images/brand-racket.png') 256 $true
Save-Icon (Join-Path $root 'android/app/src/main/res/drawable-nodpi/launch_image.png') 256 $true

$ios = Join-Path $root 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
Get-ChildItem $ios -Filter 'Icon-App-*.png' | ForEach-Object {
  $image = [System.Drawing.Image]::FromFile($_.FullName)
  $size = $image.Width
  $image.Dispose()
  Save-Icon $_.FullName $size $false
}
