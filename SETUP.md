# GiggleLab Setup Instructions

## 🔐 API Key Setup (IMPORTANT)

Before running the app, you need to add your Gemini API key:

### Step 1: Get your Gemini API Key
1. Go to https://aistudio.google.com/apikey
2. Click "Create API Key"
3. Copy the key (it will look like: `AIzaSyA...`)

### Step 2: Add the key to Config.swift
1. Open `GiggleLab/Config.swift`
2. Replace `"YOUR_GEMINI_API_KEY_HERE"` with your actual API key
3. Save the file

**Example:**
```swift
static let geminiAPIKey = "YOUR_GEMINI_API_KEY_HERE"
```

### Step 3: Build and Run
1. Open `GiggleLab.xcodeproj` in Xcode
2. Select your simulator (iPhone 17 Pro recommended)
3. Click Run (⌘R)

## 🎯 How to Use

1. Type a message in the text area
2. Select a target language (Esp, Kor, Fra)
3. Tap "Get Giggling" button
4. Wait for the AI to translate with humor and style!

## ✨ Features

- **AI-Powered Translation**: Uses Google Gemini API
- **Playful Tone**: Adds humor, emojis, and personality
- **Multiple Languages**: Spanish, Korean, French
- **Custom Keyboard**: Full keyboard interface
- **Rate Limiting**: Built-in protection (15 req/min)

## 🔒 Security Notes

- **NEVER commit your API key to git**
- `Config.swift` is already in `.gitignore`
- If you accidentally expose your key, regenerate it immediately at https://aistudio.google.com/apikey

## 📊 API Usage

### Free Tier Limits:
- 15 requests/minute
- 1,500 requests/day
- 1M tokens/month

### For Exhibition (7 days):
- Expected: 50-100 visitors/day
- ~1,750-7,000 total requests
- **Should stay within free tier!**

## 🚨 Troubleshooting

**Error: "API key not configured"**
- Make sure you added your key to `Config.swift`
- Check that you replaced the placeholder text

**Error: "Rate limit exceeded"**
- Wait 60 seconds
- Free tier allows 15 requests/minute

**Error: "API error (code: 400)"**
- Check your API key is valid
- Verify the key hasn't been deleted

**Error: "API error (code: 404)"**
- Usually means the URL uses a retired model (for example `gemini-pro` on `v1`) or the wrong API version. `Config.geminiAPIEndpoint` should look like `.../v1beta/models/gemini-2.0-flash:generateContent` (or another [listed model](https://ai.google.dev/gemini-api/docs/models/gemini)).

## 📝 Project Structure

```
GiggleLab/
├── Config.swift              ← ADD YOUR API KEY HERE
├── Theme.swift               (Colors & spacing)
├── Services/
│   └── GeminiService.swift   (API integration)
├── Views/
│   ├── RoughComposerView.swift
│   └── Keyboard/
│       └── GiggleLabKeyboard.swift
├── Models/
│   └── KeyboardScreenMode.swift
└── Extensions/
    └── Color+Hex.swift
```

## 🎨 Customization

### Change Translation Style:
In `RoughComposerView.swift`, modify the `style` parameter:
```swift
let translatedText = try await GeminiService.shared.translateWithGiggle(
    text: message,
    to: fullLanguageName,
    style: .playful  // Options: .funny, .casual, .emojiRich, .playful
)
```

### Add More Languages:
1. Add to `languages` array in `RoughComposerView.swift`
2. Add mapping in `languageMapping` dictionary

---

**Ready to giggle? 😄**
