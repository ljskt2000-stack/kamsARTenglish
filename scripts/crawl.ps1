param(
    [string]$BlogId = 'ljskt',
    [int]$CategoryNo = 3,
    [string]$ExcludedLogNo = '224374497783',
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\data\posts.json')
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$utf8 = [System.Text.UTF8Encoding]::new($false)
$headers = @{
    'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    'Referer' = "https://blog.naver.com/$BlogId"
}

function Decode-UrlText([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    return [Uri]::UnescapeDataString($Value.Replace('+', ' '))
}

function Strip-Html([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    $text = [regex]::Replace($Value, '<br\s*/?>', ' ', 'IgnoreCase')
    $text = [regex]::Replace($text, '<[^>]+>', '')
    $text = [Net.WebUtility]::HtmlDecode($text)
    return ([regex]::Replace($text, '\s+', ' ')).Trim()
}

function Get-Meta([string]$Html, [string]$Property) {
    $pattern = '<meta\s+property="' + [regex]::Escape($Property) + '"\s+content="([^"]*)"'
    return [Net.WebUtility]::HtmlDecode(([regex]::Match($Html, $pattern, 'IgnoreCase')).Groups[1].Value)
}

function Get-Paragraphs([string]$Html) {
    $result = [System.Collections.Generic.List[string]]::new()
    foreach ($match in [regex]::Matches($Html, '<p class="se-text-paragraph[^>]*>([\s\S]*?)</p>', 'IgnoreCase')) {
        $text = Strip-Html $match.Groups[1].Value
        if ($text -and $text -ne [char]0x200B) { $result.Add($text) }
    }
    return @($result)
}

function Get-Hashtags([string]$Html) {
    $values = foreach ($match in [regex]::Matches($Html, '<span class="__se-hash-tag">#([^<]+)</span>', 'IgnoreCase')) {
        (Strip-Html $match.Groups[1].Value).TrimStart('#')
    }
    return @($values | Where-Object { $_ } | Select-Object -Unique)
}

function Get-PublishedDate([string]$AddDate, [string]$Html) {
    $candidate = $AddDate
    if ($candidate -notmatch '^\d{4}\.\s*\d{1,2}\.\s*\d{1,2}\.') {
        $candidate = ([regex]::Match($Html, '<span class="se_publishDate pcol2">\s*([^<]+)')).Groups[1].Value.Trim()
    }
    $m = [regex]::Match($candidate, '^(\d{4})\.\s*(\d{1,2})\.\s*(\d{1,2})\.')
    if (-not $m.Success) { return '' }
    return '{0}-{1:D2}-{2:D2}' -f [int]$m.Groups[1].Value, [int]$m.Groups[2].Value, [int]$m.Groups[3].Value
}

function Get-Summary([string[]]$Paragraphs, [string]$Title, [string]$OgDescription) {
    $description = Strip-Html $OgDescription
    $description = [regex]::Replace($description, '\.{3,}\s*$', '')
    if ($description -and $description.Length -ge 30) {
        return $description.Substring(0, [Math]::Min(220, $description.Length)).Trim()
    }
    foreach ($paragraph in $Paragraphs) {
        if ($paragraph -ne $Title -and $paragraph.Length -ge 25) {
            return $paragraph.Substring(0, [Math]::Min(220, $paragraph.Length)).Trim()
        }
    }
    return ''
}

function Get-Ages([string]$BodyText) {
    $values = foreach ($match in [regex]::Matches($BodyText, '(?<!\d)(\d{1,2}\s*[~～-]\s*\d{1,2}\s*세|\d{1,2}\s*세)')) {
        ([regex]::Replace($match.Value, '\s+', '')).Replace('-', '~')
    }
    return @($values | Select-Object -Unique | Select-Object -First 3) -join ', '
}

function Get-InlineMaterials([string[]]$Paragraphs) {
    $materials = [System.Collections.Generic.List[string]]::new()
    foreach ($paragraph in $Paragraphs) {
        $m = [regex]::Match($paragraph, '^준비물\s*[:：]\s*(.+)$')
        if (-not $m.Success) { continue }
        foreach ($value in ($m.Groups[1].Value -split '[,，·/]')) {
            $item = $value.Trim()
            if ($item -and $item.Length -le 40) { $materials.Add($item) }
        }
    }
    return @($materials | Select-Object -Unique)
}

function Get-KeyEnglish([string[]]$Paragraphs) {
    $words = [System.Collections.Generic.List[string]]::new()
    $sentences = [System.Collections.Generic.List[string]]::new()
    $mode = ''
    $remaining = 0
    foreach ($paragraph in $Paragraphs) {
        if ($paragraph -match '(?i)Key\s*Words?|핵심\s*영어\s*단어') { $mode = 'words'; $remaining = 30; continue }
        if ($paragraph -match '(?i)Key\s*Sentences?|핵심\s*영어\s*문장') { $mode = 'sentences'; $remaining = 30; continue }
        if (($mode -and $paragraph -match '^\d+[\.\)]\s*') -or $paragraph -match '^\d+\.\s*[가-힣]') { $mode = ''; continue }
        if (-not $mode) { continue }
        $remaining--
        if ($remaining -lt 0) { $mode = ''; continue }
        if ($paragraph -notmatch "^[A-Za-z][A-Za-z\s'’!?.,-]{0,80}`$") { continue }
        $value = $paragraph.Trim()
        if ($mode -eq 'words' -and $value -notmatch '[.!?]$' -and ($value -split '\s+').Count -le 4) {
            $words.Add($value)
        }
        elseif ($mode -eq 'sentences' -and (($value -split '\s+').Count -ge 2 -or $value -match '[.!?]$')) {
            $sentences.Add($value)
        }
    }
    return @{
        words = @($words | Select-Object -Unique | Select-Object -First 15)
        sentences = @($sentences | Select-Object -Unique | Select-Object -First 12)
    }
}

function Get-ExplicitMatches([string]$Text, [string[]]$Candidates) {
    $values = foreach ($candidate in $Candidates) {
        if ($Text.IndexOf($candidate, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $candidate }
    }
    return @($values | Select-Object -Unique)
}

$page = 1
$countPerPage = 30
$list = [System.Collections.Generic.List[object]]::new()
$totalCount = 0

do {
    $listUrl = "https://blog.naver.com/PostTitleListAsync.naver?blogId=$BlogId&viewdate=&currentPage=$page&categoryNo=$CategoryNo&parentCategoryNo=&countPerPage=$countPerPage"
    $response = Invoke-RestMethod -Uri $listUrl -Headers $headers
    if ($response.resultCode -ne 'S') { throw "목록 수집 실패: page=$page" }
    $totalCount = [int]$response.totalCount
    foreach ($item in $response.postList) {
        if ([string]$item.categoryNo -ne [string]$CategoryNo) { continue }
        if ([string]$item.logNo -eq $ExcludedLogNo) { continue }
        $list.Add($item)
    }
    Write-Output "LIST page=$page collected=$($list.Count) total=$totalCount"
    $page++
} while ((($page - 1) * $countPerPage) -lt $totalCount)

$samplePath = Join-Path $PSScriptRoot '..\data\posts.sample.json'
$sampleOverrides = @{}
if (Test-Path -LiteralPath $samplePath) {
    foreach ($sample in (Get-Content -LiteralPath $samplePath -Raw -Encoding UTF8 | ConvertFrom-Json)) {
        if ([string]$sample.id -ne $ExcludedLogNo) { $sampleOverrides[[string]$sample.id] = $sample }
    }
}

$posts = [System.Collections.Generic.List[object]]::new()
$index = 0
foreach ($item in $list) {
    $index++
    $logNo = [string]$item.logNo
    if ($sampleOverrides.ContainsKey($logNo)) {
        $posts.Add($sampleOverrides[$logNo])
        Write-Output "POST $index/$($list.Count) $logNo sample-override"
        continue
    }

    $url = "https://blog.naver.com/PostView.naver?blogId=$BlogId&logNo=$logNo&redirect=Dlog"
    try {
        $html = (Invoke-WebRequest -UseBasicParsing -Uri $url -Headers $headers -TimeoutSec 30).Content
        $title = Decode-UrlText ([string]$item.title)
        $paragraphs = Get-Paragraphs $html
        $bodyText = $paragraphs -join ' '
        $ogDescription = Get-Meta $html 'og:description'
        $thumbnail = Get-Meta $html 'og:image'
        $summary = Get-Summary $paragraphs $title $ogDescription
        $english = Get-KeyEnglish $paragraphs
        $titleAndSummary = "$title $summary"

        $activityTypes = Get-ExplicitMatches $titleAndSummary @(
            '물감놀이', '역할놀이', '가위질', '그리기', '색칠하기', '오리기', '만들기',
            '종이접기', '푸드 아트', '클레이', '점토', '콜라주', '판화', '드로잉', '촉감놀이'
        )
        $seasons = Get-ExplicitMatches $titleAndSummary @(
            '봄', '여름', '가을', '겨울', '여름방학', '겨울방학', '크리스마스', '할로윈', '설날', '추석'
        )
        $learningPoints = Get-ExplicitMatches $bodyText @(
            '소근육 발달', '관찰력', '창의성', '집중력', '눈과 손의 협응', '영어 노출',
            '영어 말하기', '자기표현', '색채 경험', '감각 발달', '상호작용'
        )

        $post = [ordered]@{
            id = $logNo
            title = $title
            originalUrl = "https://blog.naver.com/$BlogId/$logNo"
            publishedDate = Get-PublishedDate ([string]$item.addDate) $html
            thumbnail = $thumbnail
            theme = $title
            summary = $summary
            age = Get-Ages $titleAndSummary
            category = '엄마표 영어미술놀이'
            materials = @(Get-InlineMaterials $paragraphs)
            englishWords = @($english.words)
            englishSentences = @($english.sentences)
            activityType = @($activityTypes)
            season = @($seasons)
            learningPoint = @($learningPoints)
            tags = @(Get-Hashtags $html)
        }
        $posts.Add([pscustomobject]$post)
        Write-Output "POST $index/$($list.Count) $logNo ok"
    }
    catch {
        Write-Warning "POST $index/$($list.Count) $logNo failed: $($_.Exception.Message)"
        $posts.Add([pscustomobject][ordered]@{
            id = $logNo
            title = Decode-UrlText ([string]$item.title)
            originalUrl = "https://blog.naver.com/$BlogId/$logNo"
            publishedDate = ''
            thumbnail = ''
            theme = ''
            summary = ''
            age = ''
            category = '엄마표 영어미술놀이'
            materials = @()
            englishWords = @()
            englishSentences = @()
            activityType = @()
            season = @()
            learningPoint = @()
            tags = @()
        })
    }
    Start-Sleep -Milliseconds 120
}

$posts = @($posts | Sort-Object publishedDate, id -Descending)
$outputDirectory = Split-Path -Parent $OutputPath
[IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
$json = $posts | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText([IO.Path]::GetFullPath($OutputPath), $json, $utf8)

Write-Output "DONE totalCategory=$totalCount excluded=$ExcludedLogNo outputCount=$($posts.Count) output=$OutputPath"
