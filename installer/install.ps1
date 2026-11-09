# 天磊安全围栏 WorkBuddy 插件：Windows 一键安装 / 卸载（未在 Windows 实机验证）
#
# 安装：powershell -ExecutionPolicy Bypass -File install.ps1 [-ScanUrl URL] [-FailMode open|closed]
# 卸载：powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall
param(
  [string]$ScanUrl = "http://192.168.120.68:18000/v1/scan",
  [ValidateSet("open", "closed")][string]$FailMode = "open",
  [switch]$Uninstall
)
$ErrorActionPreference = "Stop"

$Here      = Split-Path -Parent $MyInvocation.MyCommand.Path
$GuardDir  = Join-Path $env:USERPROFILE ".tianlei-guardrail"
$MarketDir = Join-Path $GuardDir "market"
$WbDir     = Join-Path $env:USERPROFILE ".workbuddy"
$Settings  = Join-Path $WbDir "settings.json"
$PluginKey = "tianlei-guardrail@tianlei-market"
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

if (-not (Test-Path $WbDir)) {
  Write-Host "未找到 $WbDir，请先安装 WorkBuddy 并至少打开一次。"; exit 1
}

function Backup-Settings {
  if (Test-Path $Settings) {
    $backup = "$Settings.bak-tianlei-guardrail-$(Get-Date -Format yyyyMMddHHmmss)"
    Copy-Item $Settings $backup
    Write-Host "已备份原配置：$backup"
  }
}

function Set-JsonProperty($Object, [string]$Name, $Value) {
  $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force
}

function Update-Settings([string]$Action) {
  $data = [pscustomobject]@{}
  if (Test-Path $Settings) {
    $text = [System.IO.File]::ReadAllText($Settings)
    if ($text.Trim()) { $data = $text | ConvertFrom-Json }
  }
  if (-not $data.extraKnownMarketplaces) { Set-JsonProperty $data "extraKnownMarketplaces" ([pscustomobject]@{}) }
  if (-not $data.enabledPlugins) { Set-JsonProperty $data "enabledPlugins" ([pscustomobject]@{}) }

  if ($Action -eq "install") {
    $market = [pscustomobject]@{ source = [pscustomobject]@{ source = "directory"; path = $MarketDir } }
    Set-JsonProperty $data.extraKnownMarketplaces "tianlei-market" $market
    Set-JsonProperty $data.enabledPlugins $PluginKey $true
  } else {
    $data.extraKnownMarketplaces.PSObject.Properties.Remove("tianlei-market")
    Set-JsonProperty $data.enabledPlugins $PluginKey $false
  }
  $json = $data | ConvertTo-Json -Depth 100
  [System.IO.File]::WriteAllText($Settings, $json, $Utf8NoBom)
  Write-Host "settings.json 已更新"
}

if (-not $Uninstall) {
  New-Item -ItemType Directory -Force -Path $GuardDir | Out-Null
  if (Test-Path $MarketDir) { Remove-Item -Recurse -Force $MarketDir }
  Copy-Item -Recurse (Join-Path $Here "market") $MarketDir
  Write-Host "插件已复制到：$MarketDir"

  $hookConfig = Join-Path $GuardDir "hook.json"
  if (Test-Path $hookConfig) {
    Write-Host "保留已有检测配置：$hookConfig"
  } else {
    $config = [pscustomobject]@{ scanUrl = $ScanUrl; failMode = $FailMode } | ConvertTo-Json
    [System.IO.File]::WriteAllText($hookConfig, $config, $Utf8NoBom)
    Write-Host "已写入检测配置：$hookConfig"
  }

  Backup-Settings
  Update-Settings "install"
  Write-Host ""
  Write-Host "安装完成。请完全退出 WorkBuddy 后重新打开。"
  Write-Host "检测日志：$(Join-Path $GuardDir 'hook.log')"
} else {
  Backup-Settings
  Update-Settings "uninstall"
  if (Test-Path $MarketDir) { Remove-Item -Recurse -Force $MarketDir }
  Write-Host ""
  Write-Host "已停用并移除插件。检测配置和日志保留在 $GuardDir，可手动删除。"
  Write-Host "请完全退出 WorkBuddy 后重新打开。"
}
