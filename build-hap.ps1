#Requires -Version 5.1
<#
.SYNOPSIS
    把 STUFFS_NEXT(寸进 / CUNJIN)编译成 HarmonyOS 安装包(.hap)。

.DESCRIPTION
    不需要打开 DevEco Studio 的图形界面,直接用 IDE 自带的 hvigor 命令行构建。
    构建产物:
        entry\build\default\outputs\default\entry-default-signed.hap     (已签名, 可直接安装)
        entry\build\default\outputs\default\entry-default-unsigned.hap   (未签名, 只能用于检查/上传前处理)

.PARAMETER BuildMode
    debug(默认)或 release。release 会按 entry\obfuscation-rules.txt 做混淆。

.PARAMETER Clean
    先删除 entry\build 等产物目录,做一次全新构建。

.PARAMETER App
    改为打 .app 整包(上架 AppGallery / 提审用),产物是 entry\build\...\outputs\default\*.app。

.PARAMETER Install
    构建完成后用 hdc 直接安装到已连接的设备(必须已签名的 hap)。

.EXAMPLE
    .\build-hap.ps1
.EXAMPLE
    .\build-hap.ps1 -BuildMode release -Clean
.EXAMPLE
    .\build-hap.ps1 -Install
#>
param(
    [ValidateSet('debug', 'release')]
    [string]$BuildMode = 'debug',

    [switch]$Clean,

    [switch]$App,

    [switch]$Install
)

$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot
if (-not $root) { $root = (Get-Location).Path }

# ---------------------------------------------------------------- 定位 DevEco Studio
function Find-DevEcoStudio {
    if ($env:DEVECO_STUDIO_HOME -and (Test-Path (Join-Path $env:DEVECO_STUDIO_HOME 'tools\hvigor\bin\hvigorw.bat'))) {
        return $env:DEVECO_STUDIO_HOME
    }
    $candidates = @(
        'C:\Program Files\Huawei\DevEco Studio',
        'C:\Program Files (x86)\Huawei\DevEco Studio',
        'D:\Program Files\Huawei\DevEco Studio',
        'D:\Huawei\DevEco Studio',
        (Join-Path $env:LOCALAPPDATA 'Programs\Huawei\DevEco Studio')
    )
    foreach ($c in $candidates) {
        if (Test-Path (Join-Path $c 'tools\hvigor\bin\hvigorw.bat')) { return $c }
    }
    throw "找不到 DevEco Studio。请设置环境变量 DEVECO_STUDIO_HOME 指向 DevEco Studio 安装目录。"
}

$deveco = Find-DevEcoStudio
$hvigorw = Join-Path $deveco 'tools\hvigor\bin\hvigorw.bat'
$hdc = Join-Path $deveco 'sdk\default\openharmony\toolchains\hdc.exe'

# hvigor 需要 SDK 位置和配套的 Node(用 IDE 自带的 Node 18,别用系统的 Node 24)
$env:DEVECO_SDK_HOME = Join-Path $deveco 'sdk'
$env:NODE_HOME = Join-Path $deveco 'tools\node'

Write-Host "DevEco Studio : $deveco" -ForegroundColor DarkGray
Write-Host "SDK           : $env:DEVECO_SDK_HOME" -ForegroundColor DarkGray

# ---------------------------------------------------------------- 签名状态提示
$profilePath = Join-Path $root 'build-profile.json5'
$profileText = Get-Content -LiteralPath $profilePath -Raw
# "signingConfigs": [] 或里面没有实际条目,都视为没配置签名
$hasSigning = $profileText -match '"signingConfigs"\s*:\s*\[\s*\{'

if (-not $hasSigning) {
    Write-Host ""
    Write-Host "提示: 当前 build-profile.json5 里 signingConfigs 是空的," -ForegroundColor Yellow
    Write-Host "      所以本次只能产出 *-unsigned.hap(未签名),无法安装到真机/模拟器。" -ForegroundColor Yellow
    Write-Host "      要得到可安装的包,请在 DevEco Studio 里登录华为账号后开启自动签名:" -ForegroundColor Yellow
    Write-Host "      File > Project Structure > Project > Signing Configs > 勾选 Automatically generate signature" -ForegroundColor Yellow
    Write-Host "      再点 Apply / OK,本脚本会自动识别并在构建时签名。" -ForegroundColor Yellow
    Write-Host ""
}

# ---------------------------------------------------------------- 清理
if ($Clean) {
    Write-Host "清理构建产物..." -ForegroundColor Cyan
    foreach ($p in @('entry\build', 'build', '.hvigor\cache', '.hvigor\outputs')) {
        $full = Join-Path $root $p
        if (Test-Path $full) { Remove-Item -LiteralPath $full -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# ---------------------------------------------------------------- 组装 hvigor 参数
$task = if ($App) { 'assembleApp' } else { 'assembleHap' }
$mode = if ($App) { 'project' } else { 'module' }
$hvigorArgs = @(
    $task,
    '--mode', $mode,
    '-p', 'product=default',
    '-p', "buildMode=$BuildMode",
    '--no-daemon'
)

Write-Host "构建任务      : $task ($BuildMode)" -ForegroundColor Cyan
Write-Host ""

Push-Location $root
try {
    $output = & $hvigorw @hvigorArgs 2>&1 | ForEach-Object { $_.ToString() }
    $code = $LASTEXITCODE
}
finally {
    Pop-Location
}

# 只显示尾部,完整日志在 .hvigor\outputs\build-logs 下
$output | Select-Object -Last 30 | ForEach-Object { Write-Host $_ }

if ($code -ne 0) {
    Write-Host ""
    Write-Host "构建失败 (exit code $code)。完整日志: .hvigor\outputs\build-logs" -ForegroundColor Red
    exit $code
}

# ---------------------------------------------------------------- 结果
$outDir = Join-Path $root 'entry\build\default\outputs\default'
$artifacts = @()
if (Test-Path $outDir) {
    $pattern = if ($App) { '*.app' } else { '*.hap' }
    $artifacts = Get-ChildItem -LiteralPath $outDir -Filter $pattern -ErrorAction SilentlyContinue
}

Write-Host ""
if ($artifacts.Count -eq 0) {
    Write-Host "构建成功,但没在 $outDir 找到安装包,请检查日志。" -ForegroundColor Yellow
    exit 0
}

Write-Host "构建成功,产物:" -ForegroundColor Green
foreach ($a in $artifacts) {
    $mb = [math]::Round($a.Length / 1MB, 2)
    Write-Host ("  {0}  ({1} MB)" -f $a.FullName, $mb) -ForegroundColor Green
}

# ---------------------------------------------------------------- 可选安装
if ($Install) {
    $signedHap = $artifacts | Where-Object { $_.Name -like '*-signed.hap' } | Select-Object -First 1
    if (-not $signedHap) {
        Write-Host "没有已签名的 hap,无法安装。请先在 DevEco Studio 中配置自动签名。" -ForegroundColor Red
        exit 1
    }
    if (-not (Test-Path $hdc)) {
        Write-Host "找不到 hdc: $hdc" -ForegroundColor Red
        exit 1
    }
    Write-Host ""
    Write-Host "安装到设备: $($signedHap.Name)" -ForegroundColor Cyan
    & $hdc install -r $signedHap.FullName
    exit $LASTEXITCODE
}

exit 0
