$script:mischiefCatalog=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'assets/mischief.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($script:mischiefCatalog.version -ne 1) { throw 'Unsupported mischief dialogue version' }
foreach ($context in $script:mischiefCatalog.contexts.PSObject.Properties) {
    if (@($context.Value).Count -eq 0 -or @($context.Value | Where-Object { [string]::IsNullOrEmpty($_) }).Count -gt 0) { throw 'Empty mischief dialogue' }
}
$script:mischiefLevel='normal'
$script:nextMemeAt=0.0
$script:previousMemeLine=$null
$script:memeFaceEnd=0.0

function Get-MischiefLine([string]$context,[string]$fallback,[double]$time,[int]$roll,[int]$selection) {
    $chance=switch ($script:mischiefLevel) { 'normal' {60} 'mild' {20} default {0} }
    $property=$script:mischiefCatalog.contexts.PSObject.Properties[$context]
    if ($roll -ge $chance -or $time -lt $script:nextMemeAt -or $null -eq $property) {
        return [pscustomobject]@{text=$fallback;isMeme=$false}
    }
    $choices=@($property.Value)
    $available=@($choices | Where-Object { $_ -ne $script:previousMemeLine })
    if ($available.Count -eq 0) { $available=$choices }
    $text=$available[$selection % $available.Count]
    $script:previousMemeLine=$text
    $cooldown=if ($script:mischiefLevel -eq 'mild') {120} else {30}
    $script:nextMemeAt=$time+$cooldown
    return [pscustomobject]@{text=$text;isMeme=$true}
}

function Get-MischiefSettingsPath {
    return Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'Kikki/mischief.json'
}
function Read-MischiefSettings {
    $path=Get-MischiefSettingsPath
    if (Test-Path -LiteralPath $path) {
        try {
            $level=(Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json).level
            if ($level -in @('normal','mild','off')) { $script:mischiefLevel=$level }
        } catch { $script:mischiefLevel='normal' }
    }
}
function Set-MischiefLevel([string]$level,[switch]$NoSave) {
    if ($level -notin @('normal','mild','off')) { throw 'Unsupported mischief level' }
    $script:mischiefLevel=$level; $script:nextMemeAt=0; $script:memeFaceEnd=0
    if (-not $NoSave) {
        $path=Get-MischiefSettingsPath
        [void][IO.Directory]::CreateDirectory((Split-Path $path -Parent))
        $temporary=$path+'.tmp'
        @{level=$level} | ConvertTo-Json | Set-Content -LiteralPath $temporary -Encoding UTF8
        Move-Item -LiteralPath $temporary -Destination $path -Force
    }
}
