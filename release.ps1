# Verifica se o Flutter esta instalado
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "Flutter nao esta instalado ou nao esta no PATH."
    exit 1
}

# Funcao para extrair versao do pubspec.yaml
function Get-PubspecVersion {
    $line = Get-Content pubspec.yaml | Where-Object { $_ -match '^version:' }
    if ($line -match 'version:\s*(\d+\.\d+\.\d+)\+(\d+)') {
        return @{ version = $matches[1]; build = [int]$matches[2] }
    }
    return $null
}

# Funcao para extrair versao do build.gradle.kts
function Get-GradleVersion {
    $gradle = Get-Content "android/app/build.gradle.kts"
    $versionName = ($gradle | Where-Object { $_ -match 'versionName\s*=' }) -replace '.*?"(.*?)".*', '$1'
    $versionCode = ($gradle | Where-Object { $_ -match 'versionCode\s*=' }) -replace '.*?(\d+).*', '$1'
    return @{ name = $versionName; code = [int]$versionCode }
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
$buildNumber = $pubspec.build + 1
$tagName = "v$version+$buildNumber"
$releaseFolder = "releases/$version+$buildNumber"
$apkName = "app-release.apk"
$apkPath = "$releaseFolder/$apkName"

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
if (!(Test-Path $releaseFolder)) {
    New-Item -ItemType Directory -Path $releaseFolder | Out-Null
}

# Copia o APK
Copy-Item -Path "build/app/outputs/flutter-apk/app-release.apk" -Destination $apkPath -Force
Write-Host "APK copiado para $apkPath"

# Changelog opcional
$changelogPath = "$releaseFolder/changelog.txt"
$addChangelog = Read-Host 'Deseja adicionar um changelog.txt nesta release? (s/n)'
$hasNotes = $false
if ($addChangelog -eq 's') {
    $notes = Read-Host 'Digite as notas desta versao'
    $date = Get-Date -Format "yyyy-MM-dd HH:mm"
    "Versao: $version+$buildNumber`nData: $date`nNotas:`n$notes" | Out-File -Encoding utf8 $changelogPath
    $hasNotes = $true
    Write-Host "Changelog salvo em $changelogPath"
}

# Abre pasta do APK
$open = Read-Host 'Deseja abrir a pasta do APK? (s/n)'
if ($open -eq 's') {
    Start-Process (Resolve-Path $releaseFolder)
}

# Git commit, tag e push
$gitConfirm = Read-Host 'Deseja comitar e versionar no Git? (s/n)'
if ($gitConfirm -eq 's') {
    git add pubspec.yaml
    git add android/app/build.gradle.kts
    if ($hasNotes) { git add $changelogPath }

    $commitMessage = "release: $tagName"
    git commit -m $commitMessage
    git tag $tagName
    git push
    git push origin $tagName
    Write-Host "Commit, tag e push realizados com sucesso."
}

# Cria release com gh CLI
$ghConfirm = Read-Host 'Deseja criar uma release no GitHub? (s/n)'
if ($ghConfirm -eq 's') {
    $releaseTitle = "Versao $version+$buildNumber"
    if ($hasNotes) {
        gh release create $tagName $apkPath --title "$releaseTitle" --notes (Get-Content $changelogPath | Out-String)
    } else {
        gh release create $tagName $apkPath --title "$releaseTitle" --generate-notes
    }
    Write-Host "Release criada com sucesso no GitHub."
}

# Atualiza latest_version.json
$latestJsonPath = "latest_version.json"
$repoUser = "CodeGreenLab"
$repoName = "GrowMonitor_app"
$apkUrl = "https://github.com/$repoUser/$repoName/releases/download/$tagName/$apkName"

$latestJson = @{
    version = $version
    build = $buildNumber
    url = $apkUrl
} | ConvertTo-Json -Depth 2

$latestJson | Set-Content -Encoding UTF8 $latestJsonPath
Write-Host "latest_version.json atualizado com link: $apkUrl"

# Adiciona latest_version.json ao Git se versao foi versionada
if ($gitConfirm -eq 's') {
    git add $latestJsonPath
    git commit --amend --no-edit
    git push --force-with-lease
}
