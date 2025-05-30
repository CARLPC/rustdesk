del rustdesk-*.exe

python build.py --flutter --hwcodec --vram

echo 正在查找生成的安装文件...
dir rustdesk-*-install.exe
echo.

for %%i in (rustdesk-*-install.exe) do (
    echo 找到安装文件: %%i
    echo 正在运行安装文件...
    %%i --silent-install
)
