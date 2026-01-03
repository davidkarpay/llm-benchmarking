<#
.SYNOPSIS
    LLM Vision Benchmark Script
.DESCRIPTION
    Tests vision model capabilities including:
    - OCR (text recognition)
    - Object counting
    - Color recognition
    - Spatial reasoning
    - Chart reading
    - Document understanding
.PARAMETER OutputDir
    Directory to save results. Default: C:\Users\14104\llm-benchmarks\results
.PARAMETER Models
    Array of vision models to benchmark
.PARAMETER Tests
    Specific tests to run. Default: all tests
.PARAMETER SkipPull
    Skip pulling models before testing
.PARAMETER RegenerateImages
    Force regeneration of test images
.EXAMPLE
    .\benchmark-vision.ps1
    Runs all vision tests on default models
.EXAMPLE
    .\benchmark-vision.ps1 -Models @("llava:13b") -Tests @("ocr_clear", "counting")
    Runs specific tests on specified model
#>

param(
    [string]$OutputDir = "C:\Users\14104\llm-benchmarks\results",
    [string[]]$Models = @("llava:7b", "llava:13b", "moondream"),
    [string[]]$Tests = @("ocr_clear", "ocr_small", "counting", "colors", "spatial", "chart"),
    [switch]$SkipPull,
    [switch]$RegenerateImages
)

# Import utility functions
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\utils\Export-BenchmarkResult.ps1"

# Asset directories
$assetDir = "C:\Users\14104\llm-benchmarks\test-assets\vision"
$generatedDir = "$assetDir\generated"
$staticDir = "$assetDir\static"

# Ensure directories exist
if (-not (Test-Path $generatedDir)) { New-Item -ItemType Directory -Path $generatedDir -Force | Out-Null }
if (-not (Test-Path $staticDir)) { New-Item -ItemType Directory -Path $staticDir -Force | Out-Null }

# ═══════════════════════════════════════════════════════════════
# IMAGE GENERATION FUNCTIONS
# ═══════════════════════════════════════════════════════════════

Add-Type -AssemblyName System.Drawing

function New-OcrTestImage {
    param(
        [string]$Text,
        [string]$OutputPath,
        [int]$FontSize = 48,
        [string]$FontName = "Arial"
    )

    $width = 400
    $height = 150
    $bitmap = New-Object System.Drawing.Bitmap($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    # White background
    $graphics.Clear([System.Drawing.Color]::White)

    # Draw text
    $font = New-Object System.Drawing.Font($FontName, $FontSize, [System.Drawing.FontStyle]::Bold)
    $brush = [System.Drawing.Brushes]::Black
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center

    $rect = New-Object System.Drawing.RectangleF(0, 0, $width, $height)
    $graphics.DrawString($Text, $font, $brush, $rect, $format)

    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
    $font.Dispose()

    return $OutputPath
}

function New-CountingTestImage {
    param(
        [string]$OutputPath,
        [int]$CircleCount = 5,
        [int]$SquareCount = 3
    )

    $width = 500
    $height = 400
    $bitmap = New-Object System.Drawing.Bitmap($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    # Light gray background
    $graphics.Clear([System.Drawing.Color]::FromArgb(240, 240, 240))

    $random = New-Object System.Random(42)  # Fixed seed for reproducibility

    # Draw circles (red)
    $redBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Red)
    for ($i = 0; $i -lt $CircleCount; $i++) {
        $x = $random.Next(30, $width - 60)
        $y = $random.Next(30, $height - 60)
        $graphics.FillEllipse($redBrush, $x, $y, 40, 40)
    }

    # Draw squares (blue)
    $blueBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Blue)
    for ($i = 0; $i -lt $SquareCount; $i++) {
        $x = $random.Next(30, $width - 60)
        $y = $random.Next(30, $height - 60)
        $graphics.FillRectangle($blueBrush, $x, $y, 40, 40)
    }

    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
    $redBrush.Dispose()
    $blueBrush.Dispose()

    return @{
        Path = $OutputPath
        CircleCount = $CircleCount
        SquareCount = $SquareCount
    }
}

function New-ColorTestImage {
    param([string]$OutputPath)

    $width = 400
    $height = 100
    $bitmap = New-Object System.Drawing.Bitmap($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    $graphics.Clear([System.Drawing.Color]::White)

    # Draw colored squares with labels
    $colors = @(
        @{ Name = "RED"; Color = [System.Drawing.Color]::Red },
        @{ Name = "GREEN"; Color = [System.Drawing.Color]::Green },
        @{ Name = "BLUE"; Color = [System.Drawing.Color]::Blue },
        @{ Name = "YELLOW"; Color = [System.Drawing.Color]::Yellow }
    )

    $font = New-Object System.Drawing.Font("Arial", 10)
    $blackBrush = [System.Drawing.Brushes]::Black
    $squareSize = 60
    $spacing = 100

    for ($i = 0; $i -lt $colors.Count; $i++) {
        $x = ($i * $spacing) + 10
        $brush = New-Object System.Drawing.SolidBrush($colors[$i].Color)
        $graphics.FillRectangle($brush, $x, 10, $squareSize, $squareSize)
        $graphics.DrawString(($i + 1).ToString(), $font, $blackBrush, ($x + 25), 75)
        $brush.Dispose()
    }

    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
    $font.Dispose()

    return @{
        Path = $OutputPath
        Colors = @("RED", "GREEN", "BLUE", "YELLOW")
    }
}

function New-SpatialTestImage {
    param([string]$OutputPath)

    $width = 400
    $height = 300
    $bitmap = New-Object System.Drawing.Bitmap($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    $graphics.Clear([System.Drawing.Color]::White)

    # Draw shapes in specific positions
    # Circle on LEFT, Square in CENTER, Triangle on RIGHT
    $redBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Red)
    $blueBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Blue)
    $greenBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Green)

    # Red circle on left
    $graphics.FillEllipse($redBrush, 50, 100, 80, 80)

    # Blue square in center
    $graphics.FillRectangle($blueBrush, 160, 100, 80, 80)

    # Green triangle on right
    $trianglePoints = @(
        (New-Object System.Drawing.Point(310, 180)),
        (New-Object System.Drawing.Point(350, 100)),
        (New-Object System.Drawing.Point(390, 180))
    )
    $graphics.FillPolygon($greenBrush, $trianglePoints)

    # Labels
    $font = New-Object System.Drawing.Font("Arial", 12)
    $blackBrush = [System.Drawing.Brushes]::Black
    $graphics.DrawString("CIRCLE", $font, $blackBrush, 55, 190)
    $graphics.DrawString("SQUARE", $font, $blackBrush, 160, 190)
    $graphics.DrawString("TRIANGLE", $font, $blackBrush, 300, 190)

    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
    $redBrush.Dispose()
    $blueBrush.Dispose()
    $greenBrush.Dispose()
    $font.Dispose()

    return @{
        Path = $OutputPath
        LeftShape = "CIRCLE"
        CenterShape = "SQUARE"
        RightShape = "TRIANGLE"
    }
}

function New-ChartTestImage {
    param([string]$OutputPath)

    $width = 500
    $height = 350
    $bitmap = New-Object System.Drawing.Bitmap($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    $graphics.Clear([System.Drawing.Color]::White)

    # Chart data
    $data = @(
        @{ Label = "Jan"; Value = 45 },
        @{ Label = "Feb"; Value = 72 },
        @{ Label = "Mar"; Value = 58 },
        @{ Label = "Apr"; Value = 91 }
    )

    $maxValue = 100
    $chartLeft = 60
    $chartBottom = 280
    $chartHeight = 220
    $barWidth = 60
    $barSpacing = 100

    # Draw axes
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 2)
    $graphics.DrawLine($pen, $chartLeft, $chartBottom, $chartLeft, 40)  # Y-axis
    $graphics.DrawLine($pen, $chartLeft, $chartBottom, 460, $chartBottom)  # X-axis

    # Draw title
    $titleFont = New-Object System.Drawing.Font("Arial", 14, [System.Drawing.FontStyle]::Bold)
    $graphics.DrawString("Monthly Sales", $titleFont, [System.Drawing.Brushes]::Black, 180, 10)

    # Draw bars and labels
    $font = New-Object System.Drawing.Font("Arial", 10)
    $barBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::SteelBlue)

    for ($i = 0; $i -lt $data.Count; $i++) {
        $barHeight = [int](($data[$i].Value / $maxValue) * $chartHeight)
        $x = $chartLeft + 20 + ($i * $barSpacing)
        $y = $chartBottom - $barHeight

        $graphics.FillRectangle($barBrush, $x, $y, $barWidth, $barHeight)

        # Value label on top of bar
        $graphics.DrawString($data[$i].Value.ToString(), $font, [System.Drawing.Brushes]::Black, ($x + 20), ($y - 20))

        # Month label below bar
        $graphics.DrawString($data[$i].Label, $font, [System.Drawing.Brushes]::Black, ($x + 15), ($chartBottom + 10))
    }

    # Y-axis label
    $graphics.DrawString("Sales", $font, [System.Drawing.Brushes]::Black, 10, 130)

    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
    $pen.Dispose()
    $barBrush.Dispose()
    $font.Dispose()
    $titleFont.Dispose()

    return @{
        Path = $OutputPath
        Data = $data
        HighestMonth = "Apr"
        HighestValue = 91
        LowestMonth = "Jan"
        LowestValue = 45
    }
}

# ═══════════════════════════════════════════════════════════════
# GENERATE TEST IMAGES
# ═══════════════════════════════════════════════════════════════

Write-Host @"

╔═══════════════════════════════════════════════════════════════╗
║           LLM VISION BENCHMARK SUITE v1.0                     ║
║           Testing Visual Understanding & Reasoning            ║
╚═══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

Write-Host "Models: $($Models -join ', ')" -ForegroundColor Yellow
Write-Host "Tests: $($Tests -join ', ')`n" -ForegroundColor Yellow

# Generate images if needed
Write-Host "Preparing test images..." -ForegroundColor DarkGray

$ocrClearPath = "$generatedDir\ocr_clear.png"
$ocrSmallPath = "$generatedDir\ocr_small.png"
$countingPath = "$generatedDir\counting.png"
$colorsPath = "$generatedDir\colors.png"
$spatialPath = "$generatedDir\spatial.png"
$chartPath = "$generatedDir\chart.png"

$ocrClearText = "ALPHA-7829"
$ocrSmallText = "XJ-42-BETA"

if ($RegenerateImages -or -not (Test-Path $ocrClearPath)) {
    Write-Host "  Generating OCR test images..." -ForegroundColor DarkGray
    New-OcrTestImage -Text $ocrClearText -OutputPath $ocrClearPath -FontSize 48 | Out-Null
    New-OcrTestImage -Text $ocrSmallText -OutputPath $ocrSmallPath -FontSize 24 | Out-Null
}

if ($RegenerateImages -or -not (Test-Path $countingPath)) {
    Write-Host "  Generating counting test image..." -ForegroundColor DarkGray
    $countingData = New-CountingTestImage -OutputPath $countingPath -CircleCount 5 -SquareCount 3
}

if ($RegenerateImages -or -not (Test-Path $colorsPath)) {
    Write-Host "  Generating color test image..." -ForegroundColor DarkGray
    $colorData = New-ColorTestImage -OutputPath $colorsPath
}

if ($RegenerateImages -or -not (Test-Path $spatialPath)) {
    Write-Host "  Generating spatial test image..." -ForegroundColor DarkGray
    $spatialData = New-SpatialTestImage -OutputPath $spatialPath
}

if ($RegenerateImages -or -not (Test-Path $chartPath)) {
    Write-Host "  Generating chart test image..." -ForegroundColor DarkGray
    $chartData = New-ChartTestImage -OutputPath $chartPath
}

Write-Host "  Test images ready.`n" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════
# RUN BENCHMARKS
# ═══════════════════════════════════════════════════════════════

$allResults = @()

foreach ($model in $Models) {
    Write-Host "`n$('═' * 60)" -ForegroundColor Cyan
    Write-Host "MODEL: $model" -ForegroundColor Cyan
    Write-Host "$('═' * 60)" -ForegroundColor Cyan

    # Pull model if needed
    if (-not $SkipPull) {
        Write-Host "  Ensuring model is available..." -ForegroundColor DarkGray
        ollama pull $model 2>&1 | Out-Null
    }

    # Warm up
    Write-Host "  Warming up model..." -ForegroundColor DarkGray
    ollama run $model "Hello" 2>&1 | Out-Null

    $modelResults = @()

    # ─────────────────────────────────────────────────────────────
    # TEST: OCR Clear Text
    # ─────────────────────────────────────────────────────────────
    if ("ocr_clear" -in $Tests) {
        Write-Host "`n$('─' * 60)" -ForegroundColor DarkGray
        Write-Host "TEST: OCR - Clear Text" -ForegroundColor Cyan
        Write-Host "Purpose: Can the model read large clear text?" -ForegroundColor DarkGray
        Write-Host "$('─' * 60)" -ForegroundColor DarkGray

        Write-Host "  Running test..." -ForegroundColor DarkGray
        $prompt = "Read the text in this image. Reply with ONLY the text, nothing else. $ocrClearPath"
        $response = ollama run $model $prompt 2>&1 | Out-String
        $response = $response.Trim()

        $pass = $response -match [regex]::Escape($ocrClearText)

        $modelResults += @{
            test_name = "ocr_clear"
            model = $model
            metrics = @{
                expected_text = $ocrClearText
                detected_text = $response.Substring(0, [Math]::Min(50, $response.Length))
                image_path = $ocrClearPath
            }
            pass = $pass
            response = $response.Substring(0, [Math]::Min(100, $response.Length))
        }

        $color = if ($pass) { "Green" } else { "Red" }
        $status = if ($pass) { "PASS" } else { "FAIL" }
        Write-Host "  Result: " -NoNewline; Write-Host $status -ForegroundColor $color
        Write-Host "  Expected: $ocrClearText"
        Write-Host "  Got: $($response.Substring(0, [Math]::Min(50, $response.Length)))"
    }

    # ─────────────────────────────────────────────────────────────
    # TEST: OCR Small Text
    # ─────────────────────────────────────────────────────────────
    if ("ocr_small" -in $Tests) {
        Write-Host "`n$('─' * 60)" -ForegroundColor DarkGray
        Write-Host "TEST: OCR - Small Text" -ForegroundColor Cyan
        Write-Host "Purpose: Can the model read smaller text?" -ForegroundColor DarkGray
        Write-Host "$('─' * 60)" -ForegroundColor DarkGray

        Write-Host "  Running test..." -ForegroundColor DarkGray
        $prompt = "Read the text in this image. Reply with ONLY the text, nothing else. $ocrSmallPath"
        $response = ollama run $model $prompt 2>&1 | Out-String
        $response = $response.Trim()

        $pass = $response -match [regex]::Escape($ocrSmallText)

        $modelResults += @{
            test_name = "ocr_small"
            model = $model
            metrics = @{
                expected_text = $ocrSmallText
                detected_text = $response.Substring(0, [Math]::Min(50, $response.Length))
                image_path = $ocrSmallPath
            }
            pass = $pass
            response = $response.Substring(0, [Math]::Min(100, $response.Length))
        }

        $color = if ($pass) { "Green" } else { "Red" }
        $status = if ($pass) { "PASS" } else { "FAIL" }
        Write-Host "  Result: " -NoNewline; Write-Host $status -ForegroundColor $color
        Write-Host "  Expected: $ocrSmallText"
        Write-Host "  Got: $($response.Substring(0, [Math]::Min(50, $response.Length)))"
    }

    # ─────────────────────────────────────────────────────────────
    # TEST: Counting
    # ─────────────────────────────────────────────────────────────
    if ("counting" -in $Tests) {
        Write-Host "`n$('─' * 60)" -ForegroundColor DarkGray
        Write-Host "TEST: Object Counting" -ForegroundColor Cyan
        Write-Host "Purpose: Can the model count objects accurately?" -ForegroundColor DarkGray
        Write-Host "$('─' * 60)" -ForegroundColor DarkGray

        Write-Host "  Running test..." -ForegroundColor DarkGray
        $prompt = "Count the shapes in this image. How many red circles are there? How many blue squares? Reply in format: 'Circles: N, Squares: N' $countingPath"
        $response = ollama run $model $prompt 2>&1 | Out-String
        $response = $response.Trim()

        # Check for correct counts
        $circleCorrect = $response -match "5" -or $response -match "five"
        $squareCorrect = $response -match "3" -or $response -match "three"
        $pass = $circleCorrect -and $squareCorrect

        $modelResults += @{
            test_name = "counting"
            model = $model
            metrics = @{
                expected_circles = 5
                expected_squares = 3
                circle_correct = $circleCorrect
                square_correct = $squareCorrect
                image_path = $countingPath
            }
            pass = $pass
            response = $response.Substring(0, [Math]::Min(150, $response.Length))
        }

        $color = if ($pass) { "Green" } elseif ($circleCorrect -or $squareCorrect) { "Yellow" } else { "Red" }
        $status = if ($pass) { "PASS" } else { "FAIL" }
        Write-Host "  Result: " -NoNewline; Write-Host "$status (Circles: $circleCorrect, Squares: $squareCorrect)" -ForegroundColor $color
        Write-Host "  Expected: 5 circles, 3 squares"
    }

    # ─────────────────────────────────────────────────────────────
    # TEST: Color Recognition
    # ─────────────────────────────────────────────────────────────
    if ("colors" -in $Tests) {
        Write-Host "`n$('─' * 60)" -ForegroundColor DarkGray
        Write-Host "TEST: Color Recognition" -ForegroundColor Cyan
        Write-Host "Purpose: Can the model identify colors?" -ForegroundColor DarkGray
        Write-Host "$('─' * 60)" -ForegroundColor DarkGray

        Write-Host "  Running test..." -ForegroundColor DarkGray
        $prompt = "List the colors of the 4 squares from left to right. Reply with just the color names separated by commas. $colorsPath"
        $response = ollama run $model $prompt 2>&1 | Out-String
        $response = $response.Trim().ToUpper()

        # Check for colors
        $redFound = $response -match "RED"
        $greenFound = $response -match "GREEN"
        $blueFound = $response -match "BLUE"
        $yellowFound = $response -match "YELLOW"
        $correctCount = @($redFound, $greenFound, $blueFound, $yellowFound) | Where-Object { $_ } | Measure-Object | Select-Object -ExpandProperty Count
        $pass = $correctCount -eq 4

        $modelResults += @{
            test_name = "colors"
            model = $model
            metrics = @{
                expected_colors = @("RED", "GREEN", "BLUE", "YELLOW")
                colors_correct = $correctCount
                image_path = $colorsPath
            }
            pass = $pass
            response = $response.Substring(0, [Math]::Min(100, $response.Length))
        }

        $color = if ($pass) { "Green" } elseif ($correctCount -ge 2) { "Yellow" } else { "Red" }
        $status = if ($pass) { "PASS" } else { "FAIL" }
        Write-Host "  Result: " -NoNewline; Write-Host "$status ($correctCount/4 colors identified)" -ForegroundColor $color
    }

    # ─────────────────────────────────────────────────────────────
    # TEST: Spatial Reasoning
    # ─────────────────────────────────────────────────────────────
    if ("spatial" -in $Tests) {
        Write-Host "`n$('─' * 60)" -ForegroundColor DarkGray
        Write-Host "TEST: Spatial Reasoning" -ForegroundColor Cyan
        Write-Host "Purpose: Can the model understand spatial relationships?" -ForegroundColor DarkGray
        Write-Host "$('─' * 60)" -ForegroundColor DarkGray

        Write-Host "  Running test..." -ForegroundColor DarkGray
        $prompt = "In this image, what shape is on the LEFT side? Reply with just the shape name. $spatialPath"
        $response = ollama run $model $prompt 2>&1 | Out-String
        $response = $response.Trim().ToUpper()

        $pass = $response -match "CIRCLE"

        $modelResults += @{
            test_name = "spatial"
            model = $model
            metrics = @{
                question = "What shape is on the LEFT?"
                expected_answer = "CIRCLE"
                image_path = $spatialPath
            }
            pass = $pass
            response = $response.Substring(0, [Math]::Min(100, $response.Length))
        }

        $color = if ($pass) { "Green" } else { "Red" }
        $status = if ($pass) { "PASS" } else { "FAIL" }
        Write-Host "  Result: " -NoNewline; Write-Host $status -ForegroundColor $color
        Write-Host "  Expected: CIRCLE"
        Write-Host "  Got: $($response.Substring(0, [Math]::Min(30, $response.Length)))"
    }

    # ─────────────────────────────────────────────────────────────
    # TEST: Chart Reading
    # ─────────────────────────────────────────────────────────────
    if ("chart" -in $Tests) {
        Write-Host "`n$('─' * 60)" -ForegroundColor DarkGray
        Write-Host "TEST: Chart Reading" -ForegroundColor Cyan
        Write-Host "Purpose: Can the model extract data from charts?" -ForegroundColor DarkGray
        Write-Host "$('─' * 60)" -ForegroundColor DarkGray

        Write-Host "  Running test..." -ForegroundColor DarkGray
        $prompt = "This is a bar chart showing monthly sales. Which month had the highest sales and what was the value? Reply in format: 'Month: VALUE' $chartPath"
        $response = ollama run $model $prompt 2>&1 | Out-String
        $response = $response.Trim()

        # Check for correct answer (Apr: 91)
        $monthCorrect = $response -match "Apr"
        $valueCorrect = $response -match "91"
        $pass = $monthCorrect -and $valueCorrect

        $modelResults += @{
            test_name = "chart"
            model = $model
            metrics = @{
                expected_month = "Apr"
                expected_value = 91
                month_correct = $monthCorrect
                value_correct = $valueCorrect
                image_path = $chartPath
            }
            pass = $pass
            response = $response.Substring(0, [Math]::Min(150, $response.Length))
        }

        $color = if ($pass) { "Green" } elseif ($monthCorrect -or $valueCorrect) { "Yellow" } else { "Red" }
        $status = if ($pass) { "PASS" } else { "FAIL" }
        Write-Host "  Result: " -NoNewline; Write-Host "$status (Month: $monthCorrect, Value: $valueCorrect)" -ForegroundColor $color
        Write-Host "  Expected: Apr, 91"
    }

    # Add model results to all results
    $allResults += $modelResults

    # Model summary
    $passCount = ($modelResults | Where-Object { $_.pass }).Count
    $totalCount = $modelResults.Count
    Write-Host "`n  Model Summary: " -NoNewline
    $summaryColor = if ($passCount -eq $totalCount) { "Green" } elseif ($passCount -ge $totalCount/2) { "Yellow" } else { "Red" }
    Write-Host "$passCount / $totalCount tests passed" -ForegroundColor $summaryColor
}

# ═══════════════════════════════════════════════════════════════
# EXPORT RESULTS
# ═══════════════════════════════════════════════════════════════
Write-Host "`n$('═' * 60)" -ForegroundColor Cyan
Write-Host "EXPORTING RESULTS" -ForegroundColor Cyan
Write-Host "$('═' * 60)`n" -ForegroundColor Cyan

Export-JsonResult -TestName "vision_benchmark" -Category "cognitive" -Results $allResults -OutputDir "$OutputDir\raw"

# ═══════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ═══════════════════════════════════════════════════════════════
Write-Host "`n$('═' * 60)" -ForegroundColor Cyan
Write-Host "VISION BENCHMARK SUMMARY" -ForegroundColor Cyan
Write-Host "$('═' * 60)`n" -ForegroundColor Cyan

# Group by model
$modelGroups = $allResults | Group-Object { $_.model }

Write-Host "  Model               | Tests Passed | Score" -ForegroundColor White
Write-Host "  $('-' * 50)" -ForegroundColor DarkGray

foreach ($group in $modelGroups) {
    $modelName = $group.Name
    $passed = ($group.Group | Where-Object { $_.pass }).Count
    $total = $group.Group.Count
    $score = [math]::Round(($passed / $total) * 100, 0)

    $color = if ($score -eq 100) { "Green" } elseif ($score -ge 50) { "Yellow" } else { "Red" }
    $modelPadded = $modelName.PadRight(20)
    $passedStr = "$passed/$total".PadRight(12)

    Write-Host "  $modelPadded | $passedStr | " -NoNewline
    Write-Host "$score%" -ForegroundColor $color
}

Write-Host ""
