$env:TEMP="F:\temp"; $env:TMP="F:\temp";$env:CARGO_HOME="F:\cargo-cache"
$env:LIB = "C:\vcpkg\installed\x64-windows-static\lib;C:\Program Files (x86)\Windows Kits\10\Lib\10.0.26100.0\um\x64"

cargo rustc --locked --release --features hwcodec,vram,flutter --lib --   -l static=swresample -l mfuuid -l strmiids
  
python build.py --flutter --hwcodec --vram --skip-cargo