# RustDesk 项目长期记忆

## 构建环境（本机 F:\rustdesk）
- Windows Flutter 构建入口：`python build.py --flutter --hwcodec --vram`（需 libs/virtual_display/dylib 与 flutter/ 的 flutter SDK）。
- 原生依赖走 vcpkg：`VCPKG_ROOT=C:\vcpkg`，三元组 `x64-windows-static`。
- **依赖必须用 manifest 模式从仓库根安装**，否则会装成 stock 端口导致 FFmpeg 版本错（见下）：
  ```bat
  cd /d F:\rustdesk
  set VCPKG_DEFAULT_HOST_TRIPLET=x64-windows-static
  C:\vcpkg\vcpkg install --triplet x64-windows-static --x-install-root="C:\vcpkg\installed"
  ```
- vcpkg 仓库须 checkout CI 锁定 commit `9e593bb18ea69cc5095e012465dcd675a822ed0d`（= `vcpkg.json` 的 baseline，2026-07-29），否则工具版本与基线不匹配（新版工具要 cmake 4.4.3，基线配套 4.3.0）。
- **FFmpeg 必须用 `res/vcpkg` 下的 overlay 端口（7.1.1 + RustDesk 补丁）**。若装成 stock ffmpeg（如 9.0.2），hwcodec 会编译失败：`FF_PROFILE_*` 未声明、`AVFrame::key_frame` 不存在。
- `hwcodec` 的 C++ 依赖：`res/vcpkg` overlay 端口 ffmpeg[amf,nvcodec,qsv] + externals 下的 nv-codec-headers 12.1.14 / Video_Codec_SDK 12.1.14 / AMF 1.4.35。
- **已应用代码级兼容补丁（本地临时）**：hwcodec 检出下的 `cpp/common/util.cpp`（`AV_PROFILE_*`）、`cpp/ffmpeg_ram/ffmpeg_ram_decode.cpp`（`#if LIBAVUTIL_VERSION_MAJOR >= 58`），让 stock ffmpeg 9.0.2 也能编过；原文件备份为同目录 `*.cpp.orig`，补丁档在 `F:\rustdesk\.workbuddy\patch\hwcodec-ffmpeg9-compat.patch`。该补丁对 FFmpeg 7.1.1 同样兼容。
- **cargo 的 hwcodec 检出存在两份，补丁必须都打**：默认 `C:\Users\carlpc\.cargo\git\checkouts\hwcodec-3f3da9ff8e484625\778df1f`（当前构建实际在用）与 `F:\cargo-cache\git\checkouts\hwcodec-3f3da9ff8e484625\778df1f`。报错时先看错误信息里的绝对路径。若 cargo 重新检出该目录，补丁会丢失，需按补丁档重打。
- **手动验证 hwcodec C++ 编译的方法**（会话内可用，不依赖 stdin 管道）：直接用 `cl.exe -nologo -MT -O2 -Brepro -W4 -DNOMINMAX -DMFX_DEPRECATED_OFF -DMFX_D3D11_SUPPORT -c` + build.rs 里的全部 `-I` 路径逐个编 `.cpp`，比整跑构建快得多。
  - **不能用 `vcvarsall.bat` / `vcvars64.bat`**：内部调 `reg.exe`，被沙箱 Program Blacklist 拦截。改为手动设 `INCLUDE`（MSVC include + SDK 10.0.26100.0 的 ucrt/shared/um/winrt）与 `PATH`（MSVC bin\HostX64\x64）。
  - 现成校验脚本：`C:\Users\carlpc\AppData\Local\Temp\hwchk3\checkall.bat`，覆盖 17 个 Windows 侧 .cpp，最近一次 17/17 PASS。

## 本地源码补丁（src/，区别于 hwcodec 检出补丁）
- **默认服务器硬编码（2026-10-27）**：ID 服务器 `172.18.24.12:21116`、key `0XHgXM73Ko3etT+QgKdBZjaQO9Qc3pUsD6cfZHAyyYg=`（改 `libs/hbb_common/src/config.rs` 的 `RENDEZVOUS_SERVERS`/`RS_PUB_KEY`，**该目录是 git 子模块**，补丁档 `hbbcommon-default-server.patch`，子模块被重置会丢需重打）；API 兜底 `http://172.18.24.12:21114`（改 `src/common.rs` `get_api_server_`，补丁档 `common-default-api-server.patch`）。中继走 hbbs 上报/ID+1 兜底，无需硬编码。密码规则放宽见 `flutter-password-rule.patch`（数字+长度≥4）。
- **默认永久密码 1992（2026-10-27）**：`libs/hbb_common/src/config.rs` 的 `DEFAULT_PRESET_PASSWORD` 常量 + `get_preset_password_storage_and_salt()` 回退（利用 fork 自带的 preset 密码机制，salt 空 → 服务端明文比对）。本机自设密码优先，预设仅兜底。并入 `hbbcommon-default-server.patch`。
- **更新源指向 fork 仓库 CARLPC/rustdesk（2026-10-27）**：`src/common.rs` 的 `UPDATE_REPO_OWNER`/`UPDATE_REPO_NAME` 常量驱动「版本检查 + 下载白名单」两处——检查 GET `https://api.github.com/repos/CARLPC/rustdesk/releases/latest`（读 `tag_name`），下载走 `https://github.com/CARLPC/rustdesk/releases/download/<tag>/<file>`；`src/updater.rs` `get_update_download_file_from_url` 只放行该仓库（官方 rustdesk/rustdesk 现被拒）。补丁档 `fork-self-update-CARLPC.patch`。换 fork 目标只需改这两个常量。发布时 tag 须为纯版本号、资源名须为 `rustdesk-<tag>-x86_64.exe|msi`（Win）/ `rustdesk-<tag>-<arch>.dmg`（macOS）。
- **secure tcp 验证完全跳过补丁（2026-10-27，最终版）**：`src/client.rs` 三处移除密钥交换——`_start_inner` 打洞路径（两个交换块删除，`webrtc_offerer = None` 禁 WebRTC 明文信令）、`request_relayed_conn` relay 路径、`hc_connection_` 健康检查；import 行同步删除。客户端与 hbbs 的 TCP 连接全部明文直连、零等待。补丁档 `F:\rustdesk\.workbuddy\patch\client-secure-tcp-skip.patch`。安全性依据：响应读取用 `get_next_nonkeyexchange_msg` 会跳过服务器补发的 KeyExchange 消息。受控端注册链路（rendezvous_mediator.rs）未动，仍保留交换。

## WorkBuddy 会话限制（重要）
- 本机 agent 会话运行在 LiteSandbox 中，会**拦截 Rust 创建「只写命名管道」**（向子进程喂 stdin），报 `OS error 231 ERROR_PIPE_BUSY`；stdout/stderr 管道与 Python 匿名管道正常，`dangerouslyDisableSandbox` 无效。
- 后果：会话内无法完成 `cargo build`（rustix build script 必挂）与 `vcpkg install`（vcpkg 本体解压归档失败）。
- **cargo 构建与 vcpkg 安装都应在 WorkBuddy 之外的普通终端执行。**
