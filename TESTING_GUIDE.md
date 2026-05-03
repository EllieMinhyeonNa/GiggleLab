# GiggleBee Tone Testing Guide

## Quick Testing Methods

### Method 1: Use the Test Button in the App
1. Run the app
2. On the home screen, tap **"Test Tone (Check Console)"**
3. Check Xcode's console output for results
4. Default test: "I got the job!" with excited tone

### Method 2: Use Console Commands
Add this code anywhere in your app to test:

```swift
// Quick test with default message
GeminiService.quickTest()

// Test with custom message
GeminiService.quickTest(message: "This is amazing!", tone: .laughing)

// Test all tones
GeminiService.quickTest(message: "Hello", tone: .crying)
GeminiService.quickTest(message: "Hello", tone: .excited)
GeminiService.quickTest(message: "Hello", tone: .laughing)
GeminiService.quickTest(message: "Hello", tone: .loving)
GeminiService.quickTest(message: "Hello", tone: .nervous)
GeminiService.quickTest(message: "Hello", tone: .pleading)
GeminiService.quickTest(message: "Hello", tone: .surprised)
```

### Method 3: Direct API Call
```swift
Task {
    do {
        let results = try await GeminiService.shared.generateExpressiveAlternatives(
            text: "Your message here",
            tone: .excited,
            targetLanguage: "English",
            style: .playful
        )

        for (index, result) in results.enumerated() {
            print("[\(index + 1)] \(result)")
        }
    } catch {
        print("Error: \(error)")
    }
}
```

## Available Tones

| Tone | Emoji | Description |
|------|-------|-------------|
| `.crying` | 😢 | Dramatic devastation with attitude |
| `.excited` | 🤩 | Stunned excitement, overwhelmed |
| `.laughing` | 😂 | Full body laughter, unhinged |
| `.loving` | 🥰 | Soft, warm, genuinely tender |
| `.nervous` | 😅 | Trying to hold it together (but not) |
| `.pleading` | 🥺 | Soft power, charming, not desperate |
| `.surprised` | 😯 | Clean, pure shock, no feeling yet |

## Console Output Format

```
============================================================
GIGGLEB BEE QUICK TEST
============================================================
Input: "I got the job!"
Tone: Excited 🤩
------------------------------------------------------------
[1] First alternative...
[2] Second alternative...
[3] Third alternative...
============================================================
```

## Tips for Quality Testing

1. **Test varied inputs**: Short messages, long messages, different emotions
2. **Check tone consistency**: Do all 3 alternatives match the tone?
3. **Verify distinctiveness**: Are the 3 alternatives different enough?
4. **Length matching**: Do alternatives roughly match input length?
5. **Language check**: Are results in the correct language?

## Example Test Messages

```swift
// Positive
"I got the job!"
"You're the best!"
"This is perfect!"

// Negative
"I can't believe this happened"
"This is the worst"
"Everything is falling apart"

// Neutral
"I'll be there soon"
"Let me know what you think"
"See you tomorrow"

// Emotional
"You mean everything to me"
"I'm so scared right now"
"This is hilarious"
```

## Rate Limiting

- The service has a rate limit of 15 requests per minute
- When doing bulk testing, add delays between requests:
  ```swift
  try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
  ```
