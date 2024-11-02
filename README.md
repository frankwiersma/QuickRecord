# 🎙️ QuickRecord

**A simple, efficient tool to capture and transcribe audio using FFmpeg and Deepgram API. Perfect for quick voice notes or meeting recaps.**

---

## 📄 Description
QuickRecord automates audio recording and transcription in a single script. With FFmpeg handling the audio capture and Deepgram's API providing transcription, this tool delivers accurate text directly to your clipboard or a file for easy access.

## 🔧 Use Case
- **Record voice notes or meetings** with the option to copy the transcript to the clipboard or save it to a file.
- **Review audio devices** before recording with a simple parameter for device listing.

---

## ⚙️ Key Parameters
- **-ToClipboard**: Copies the transcript directly to the clipboard.
- **-ListDevices**: Lists available audio devices for easy selection.
- **-MicId**: Selects the audio device by ID for recording.

---

## 🚀 Quick Start
1. Press `Windows Key + R` to open Run dialog
2. Type: `powershell C:\path\QuickRecord.ps1 -ToClipboard -MicID 1`
3. Press Enter and start speaking!