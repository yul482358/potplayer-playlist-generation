# 视频文件扩展名过滤列表（常见视频格式）
$videoExtensions = @('.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.mpg', '.mpeg', '.3gp', '.ts', '.m2ts', '.divx', '.rmvb', '.asf', '.vob')

# 获取当前文件夹信息
$currentFolder = Get-Item -Path .
$folderName = $currentFolder.Name
$outputFile = Join-Path -Path $currentFolder.FullName -ChildPath "$folderName.dpl"

# 递归获取所有视频文件
$videoFiles = Get-ChildItem -Path $currentFolder.FullName -Recurse -File | 
              Where-Object { $videoExtensions -contains $_.Extension.ToLower() }

# 自定义排序函数，优先按文件夹结构排序，再按文件名中的数字排序
function CustomSort {
    param($Files)
    
    # 首先按目录深度排序，确保同一层级的文件在一起
    $sortedByDepth = $Files | Sort-Object -Property @{
        Expression = {
            $_.FullName.Split('\').Count
        }
    }
    
    # 然后按完整路径的自然顺序排序
    $sortedByPath = $sortedByDepth | Sort-Object -Property @{
        Expression = {
            # 提取路径中的数字部分，并填充零以确保正确排序
            $path = $_.FullName
            # 替换路径中的数字部分为固定长度格式
            [regex]::Replace($path, '\d+', { $args[0].Value.PadLeft(10, '0') })
        }
    }
    
    return $sortedByPath
}

# 使用自定义排序函数对视频文件排序
$sortedVideoFiles = CustomSort -Files $videoFiles

# 创建DPL文件内容
$dplContent = @()
$dplContent += "DAUMPLAYLIST"
$dplContent += "playname=$($currentFolder.FullName)"
$dplContent += "topindex=0"
$dplContent += "saveplaypos=0"

# 添加文件条目
$index = 0
foreach ($file in $sortedVideoFiles) {
    $index++
    # 对路径中的特殊字符进行转义处理
    $filePath = $file.FullName -replace '\\', '\\'
    $dplContent += "$index*file*$filePath"
    
    # 尝试获取视频时长（如果有的话）
    try {
        $shell = New-Object -ComObject Shell.Application
        $folder = $shell.Namespace($file.Directory.FullName)
        $item = $folder.ParseName($file.Name)
        $duration = $folder.GetDetailsOf($item, 27) # 27是时长属性的索引
        
        if ($duration -match '(\d+):(\d+):(\d+)') {
            $totalSeconds = [int]$matches[1] * 3600 + [int]$matches[2] * 60 + [int]$matches[3]
            $dplContent += "$index*duration2*$($totalSeconds * 1000)" # 转换为毫秒
        }
    } catch {
        # 如果无法获取时长，跳过
    }
}

# 使用UTF-8编码带BOM写入文件（兼容含中文、emoji等特殊字符的文件名）
$utf8WithBom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllLines($outputFile, $dplContent, $utf8WithBom)

Write-Host "已生成PotPlayer播放列表: $outputFile"
Write-Host "共包含 $index 个视频文件"