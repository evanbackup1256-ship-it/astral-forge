$env:Path += ";node_modules\.bin"
$start = Start-Process -FilePath "argon" -ArgumentList "serve","default.project.json" -WindowStyle Hidden -PassThru
$start
