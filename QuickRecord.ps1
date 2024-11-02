# Parameters
param (
    [string]$Language = "en",  # Default language set to English
    [switch]$ToClipboard = $false,
    [switch]$ListDevices = $false,
    [int]$MicId = 0
)

# Configuration
$ffmpegPath = "C:\ProgramData\chocolatey\bin\ffmpeg.exe"
$AudioFile = Join-Path $env:TEMP "recording_$(Get-Date -Format 'yyyyMMdd_HHmmss').wav"
$TranscriptFolder = "C:\Temp\Transcripts"
$TranscriptFile = Join-Path $TranscriptFolder "transcript_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$MaxDuration = 3600

# Get script directory and key file path
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$KeyFile = Join-Path $ScriptDir "deepgram.key"

# Function to get available audio devices
function Get-AudioDevices {
    $deviceList = & $ffmpegPath -list_devices true -f dshow -i dummy 2>&1 | 
                 Select-String ".*\(audio\)" | 
                 ForEach-Object { $_.Line.Trim() }
    return $deviceList
}

# Function to display available devices
function Show-AudioDevices {
    $deviceList = Get-AudioDevices
    
    if ($deviceList.Count -eq 0) {
        Write-Host "No audio devices found."
        return $false
    }

    Write-Host "`nAvailable audio devices:"
    for ($i = 0; $i -lt $deviceList.Count; $i++) {
        Write-Host "$($i + 1). $($deviceList[$i])"
    }
    return $true
}

# Check if only listing devices
if ($ListDevices) {
    if (-not (Test-Path $ffmpegPath)) {
        Write-Host "Error: FFmpeg not found at: $ffmpegPath" -ForegroundColor Red
        exit 1
    }
    Show-AudioDevices
    exit 0
}

# Load API key from file
try {
    if (-not (Test-Path $KeyFile)) {
        throw "API key file not found at: $KeyFile"
    }
    $DeepgramAPIKey = Get-Content $KeyFile -ErrorAction Stop | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($DeepgramAPIKey)) {
        throw "API key file is empty"
    }
}
catch {
    Write-Host "Error loading API key: $_" -ForegroundColor Red
    exit 1
}

# Deepgram API URL with language parameter
$DeepgramURL = "https://api.deepgram.com/v1/listen?model=nova-2&smart_format=true&language=$Language"

# Create Transcripts directory if it doesn't exist
if (-not (Test-Path $TranscriptFolder)) {
    New-Item -ItemType Directory -Path $TranscriptFolder -Force | Out-Null
    Write-Host "Created transcripts directory at: $TranscriptFolder"
}

# Function to record audio
function Start-AudioRecording {
    param (
        [string]$Device,
        [string]$OutputFile
    )
    
    # Kill any existing ffmpeg processes
    Get-Process | Where-Object { $_.ProcessName -eq "ffmpeg" } | Stop-Process -Force

    $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
    $ProcessInfo.FileName = $ffmpegPath
    $ProcessInfo.Arguments = "-y -f dshow -i audio=`"$Device`" `"$OutputFile`""
    $ProcessInfo.RedirectStandardOutput = $true
    $ProcessInfo.RedirectStandardError = $true
    $ProcessInfo.UseShellExecute = $false
    $ProcessInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $ProcessInfo
    return $process
}

# Function to ensure file is released
function Wait-FileRelease {
    param (
        [string]$FilePath,
        [int]$MaxAttempts = 10
    )
    
    Write-Host "Ensuring file is released..."
    
    # Kill any running ffmpeg processes
    Get-Process | Where-Object { $_.ProcessName -eq "ffmpeg" } | Stop-Process -Force
    
    for ($i = 1; $i -le $MaxAttempts; $i++) {
        try {
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            
            # Try to open and close the file
            $stream = [System.IO.File]::Open($FilePath, 'Open', 'Read', 'None')
            $stream.Close()
            $stream.Dispose()
            
            return $true
        }
        catch {
            Write-Host "Attempt $i of $MaxAttempts to release file..."
            Start-Sleep -Seconds 1
        }
    }
    
    return $false
}

# Function to cleanup temporary files
function Remove-TempFiles {
    param (
        [string]$WavFile
    )
    
    try {
        if (Test-Path $WavFile) {
            Remove-Item -Path $WavFile -Force
            Write-Host "Temporary audio file cleaned up."
        }
    }
    catch {
        Write-Host "Warning: Could not remove temporary file: $_"
    }
}

# Function to transcribe audio using Deepgram
function Invoke-Transcription {
    param (
        [string]$AudioFile,
        [string]$TranscriptFile
    )

    $Headers = @{
        "Authorization" = "Token $DeepgramAPIKey"
        "Content-Type" = "audio/wav"
    }

    try {
        Write-Host "Transcribing audio..."
        # Use a MemoryStream to hold file contents
        $fileBytes = [System.IO.File]::ReadAllBytes($AudioFile)
        $memoryStream = New-Object System.IO.MemoryStream(,$fileBytes)
        
        $Response = Invoke-RestMethod -Uri $DeepgramURL -Headers $Headers -Body $memoryStream.ToArray() -Method Post
        $memoryStream.Dispose()
        
        $Transcript = $Response.results.channels[0].alternatives[0].transcript
        
        if ([string]::IsNullOrEmpty($Transcript)) {
            Write-Host "Warning: Received empty transcript"
            $Transcript = "No speech detected in the recording."
        }
        
        # Create parent directory if it doesn't exist
        $transcriptDir = Split-Path $TranscriptFile -Parent
        if (-not (Test-Path $transcriptDir)) {
            New-Item -ItemType Directory -Path $transcriptDir -Force | Out-Null
        }
        
        $Transcript | Out-File -FilePath $TranscriptFile -Encoding UTF8
        Write-Host "Transcription saved to: $TranscriptFile"
        
        # If ToClipboard is true, also copy the transcript to clipboard
        if ($ToClipboard) {
            $Transcript | Set-Clipboard
            Write-Host "Transcript copied to clipboard."
        }
        
        return $true
    }
    catch {
        Write-Host "Error during transcription: $_" -ForegroundColor Red
        return $false
    }
    finally {
        if ($memoryStream) {
            $memoryStream.Dispose()
        }
    }
}

# Main script execution
try {
    # Check if ffmpeg exists
    if (-not (Test-Path $ffmpegPath)) {
        throw "FFmpeg not found at: $ffmpegPath"
    }

    # Get available devices
    $deviceList = Get-AudioDevices

    if ($deviceList.Count -eq 0) {
        throw "No audio devices found. Please check your setup."
    }

    # Validate MicId
    if ($MicId -lt 1 -or $MicId -gt $deviceList.Count) {
        throw "Invalid MicId. Use -ListDevices to see available device IDs."
    }

    # Extract selected device name using MicId
    $selectedDevice = $deviceList[$MicId - 1] -replace '.*"(.*)" \(audio\)', '$1'
    Write-Host "Using device: $selectedDevice"

    # Start recording
    Write-Host "`nStarting recording... Press Enter to stop."
    $process = Start-AudioRecording -Device $selectedDevice -OutputFile $AudioFile
    $process.Start() | Out-Null

    # Wait for Enter key
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

    # Stop recording and ensure file is released
    Write-Host "Stopping recording..."
    if (!$process.HasExited) {
        $process.Kill()
    }
    
    $process.Close()
    $process.Dispose()

    # Wait for file to be released
    if (Wait-FileRelease -FilePath $AudioFile) {
        # Check if file exists and has content
        $fileInfo = Get-Item $AudioFile
        if ($fileInfo.Length -eq 0) {
            throw "Recording file is empty. Please try again."
        }

        Write-Host "Recording saved successfully."

        # Transcribe the audio
        $success = Invoke-Transcription -AudioFile $AudioFile -TranscriptFile $TranscriptFile

        if ($success) {
            # Clean up the WAV file after successful transcription
            Remove-TempFiles -WavFile $AudioFile

            if (-not $ToClipboard) {
                # Open transcript in notepad if not copying to clipboard
                Start-Process notepad.exe -ArgumentList $TranscriptFile
            }
            
            # Exit immediately after successful operation
            exit 0
        }
    }
    else {
        throw "Could not access the recording file after multiple attempts."
    }
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}
finally {
    # Final cleanup
    Get-Process | Where-Object { $_.ProcessName -eq "ffmpeg" } | Stop-Process -Force
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    
    # Ensure WAV file is removed even if there was an error
    Remove-TempFiles -WavFile $AudioFile
}
