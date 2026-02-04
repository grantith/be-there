# Cross platform shebang:
shebang := if os() == 'windows' {
  'pwsh.exe'
} else {
  '/usr/bin/env pwsh'
}

# Set shell for non-Windows OSs:
set shell := ["pwsh", "-c"]

# Set shell for Windows OSs:
set windows-shell := ["pwsh.exe", "-NoLogo", "-Command"]


@build:
  ./tools/build_release.ps1

@start:
  ./harken.ahk

@start_bin:
  ./dist/harken.exe

@build_rs:
  cd ./tools/focus_border_helper
  cargo build --release

compress_gifs path:
  #!{{shebang}}
  Get-ChildItem {{path}} -Filter *.gif | ForEach-Object {
      $in = $_.FullName
      $tmp = [System.IO.Path]::ChangeExtension($in, ".optimized.gif")
      ffmpeg -y -i "$in" `
          -vf "fps=11,scale=720:-2:flags=lanczos,split[s0][s1];[s0]palettegen=stats_mode=full[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3" `
          "$tmp"
  }
