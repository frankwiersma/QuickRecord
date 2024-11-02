Here's the updated README with the new language selection feature:

---

# 🎙️ QuickRecord

**A simple, efficient tool to capture and transcribe audio using FFmpeg and Deepgram API. Perfect for quick voice notes.**

---

## 📄 Description
QuickRecord automates audio recording and transcription in a single script. With FFmpeg handling the audio capture and Deepgram's API providing transcription, this tool delivers accurate text directly to your clipboard or a file for easy access. Now, you can choose between English and Dutch transcriptions with a simple parameter!

## 🔧 Use Case
- **Record voice notes** with the option to copy the transcript to the clipboard or save it to a file.
- **Review audio devices** before recording with a simple parameter for device listing.
- **Select transcription language** for either English or Dutch based on your preference.

---

## ⚙️ Key Parameters
- **-ToClipboard**: Copies the transcript directly to the clipboard.
- **-ListDevices**: Lists available audio devices for easy selection.
- **-MicId**: Selects the audio device by ID for recording.
- **-Language**: Sets the transcription language. Use `"en"` for English (default) or `"nl"` for Dutch.

---

## 🚀 Quick Start
1. Press `Windows Key + R` to open the Run dialog.
2. Type: `powershell C:\path\QuickRecord.ps1 -ToClipboard -MicID 1 -Language "en"`
3. Press Enter and start speaking!

> **Note**: To transcribe in Dutch, simply change `-Language "en"` to `-Language "nl"` in the command above.

---
