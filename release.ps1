# Verifica se o Flutter esta instalado
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "Flutter nao esta instalado ou nao esta no PATH."
    exit 1
}

# Funcao para extrair versao do pubspec.yaml
function Get-PubspecVersion {
    $line = Get-Content pubspec.yaml | Where-Object { $_ -match '^version:' }
    if ($line -match 'version:\s*(\d+\.\d+\.\d+)\+(\d+)') {
        return @{ version = $matches[1]; build = $matches[2] }
    }
    return $null
}

# Funcao para extrair versao do build.gradle.kts
function Get-GradleVersion {
    $gradle = Get-Content "android/app/build.gradle.kts"
    $versionName = ($gradle | Where-Object { $_ -match 'versionName\s*=' }) -replace '.*?"(.*?)".*', '$1'
    $versionCode = ($gradle | Where-Object { $_ -match 'versionCode\s*=' }) -replace '.*?(\d+).*', '$1'
    return @{ name = $versionName; code = $versionCode }
}

# Exibe versoes atuais
$pubspec = Get-PubspecVersion
$gradle = Get-GradleVersion

Write-Host ""
Write-Host "Versao atual em pubspec.yaml: $($pubspec.version)+$($pubspec.build)"
Write-Host "Versao atual em build.gradle.kts: versionName = $($gradle.name), versionCode = $($gradle.code)"
Write-Host ""

# Solicita nova versao
$version = Read-Host 'Digite a NOVA versao (ex: 2.0.0)'
$buildNumber = Read-Host 'Digite o NOVO numero de build (ex: 2)'

# Atualiza pubspec.yaml
(Get-Content pubspec.yaml) `
    -replace 'version: .*', "version: $version+$buildNumber" |
    Set-Content pubspec.yaml
Write-Host "pubspec.yaml atualizado para $version+$buildNumber"

# Atualiza build.gradle.kts
$gradlePath = "android/app/build.gradle.kts"
(Get-Content $gradlePath) `
    -replace 'versionName = ".*?"', "versionName = `"$version`"" `
    -replace 'versionCode = \d+', "versionCode = $buildNumber" |
    Set-Content $gradlePath
Write-Host "build.gradle.kts atualizado para versao $version e code $buildNumber"

# Gera APK
Write-Host ""
Write-Host "Gerando APK..."
flutter clean
flutter pub get
flutter build apk --release
Write-Host "APK gerado."

# Cria pasta releases/versao
$releaseFolder = "releases/$version+$buildNumber"
if (!(Test-Path $releaseFolder)) {
    New-Item -ItemType Directory -Path $releaseFolder | Out-Null
}

# Copia o APK para a pasta releases
$apkSource = "build/app/outputs/flutter-apk/app-release.apk"
$apkDest = "$releaseFolder/app-release.apk"
Copy-Item -Path $apkSource -Destination $apkDest -Force
Write-Host "APK copiado para $apkDest"

# Pergunta se deseja adicionar changelog
$addChangelog = Read-Host 'Deseja adicionar um changelog.txt nesta release? (s/n)'
if ($addChangelog -eq 's') {
    $notes = Read-Host 'Digite as notas desta versao'
    $notesPath = "$releaseFolder/changelog.txt"
    $date = Get-Date -Format "yyyy-MM-dd HH:mm"
    "Versao: $version+$buildNumber`nData: $date`nNotas:`n$notes" | Out-File -Encoding utf8 $notesPath
    Write-Host "Changelog salvo em $notesPath"
}

# Pergunta se deseja abrir a pasta do APK
$open = Read-Host 'Deseja abrir a pasta do APK? (s/n)'
if ($open -eq 's') {
    $apkPath = Resolve-Path $releaseFolder
    Start-Process $apkPath
}
