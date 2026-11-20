# ZaRa

> **Maya-র সাথে A-to-Z ফিচার/ওয়ার্কফ্লো ম্যাপ:** [`PARITY.md`](PARITY.md) — প্রতিটি সেকশনে কী আছে, কী নিজস্ব সমতুল্য, কী key/config-নির্ভর, আর কী সীমার বাইরে তা লিস্ট করা আছে।

# ZaRa — বাংলা-প্রথম ভয়েস অ্যাসিস্টেন্ট (v0.1)

- **অ্যাপ:** ZaRa · **প্যাকেজ:** `com.zaraai.app` · **প্রধান ভাষা:** বাংলা (`bn-BD`)
- নতুন পরিচয়, নিজস্ব infrastructure। Maya-র কোনো name, endpoint, secret, pin,
  OAuth client ID বা মডেল অ্যাসেট এখানে ব্যবহার করা হয়নি।

## বাংলা-প্রথম নীতি
- TTS locale `bn-BD`; STT-তে `language=bn`; wake word `ও জারা` / `জারা` / `zara`
- Stop-word ডিটেক্টরে বাংলা `থামো / থাম / রুক / বন্ধ / বাদ দাও / চলো না` প্রথম
- মডেল system prompt বাংলা উত্তর বাধ্যতামূলক করে; UI-র সব string বাংলা

## v1 (এখন আছে)
- ন্যূনতম manifest: RECORD_AUDIO, INTERNET, microphone foreground service
- **মাইক wiring**: `VoiceService` foreground capture → `AudioCapture` (16 kHz + AEC)
  → `Vad` → `VoiceSession` → ViewModel → STT → Agent → TTS; UI-তে "কথা বলুন / থামো" বাটন
- STT: user-key OpenAI-compatible `/audio/transcriptions` (`language=bn`)
- TTS: system `bn-BD`; wake word `ও জারা / জারা`
- **ZaRa persona**: Maya-র মতো আত্মবিশ্বাসী, চটপট, কড়া-মজার স্বর —
  নিজস্ব লেখা বাংলা system prompt (`ZaraPersona.kt`); কোনো Maya string কপি নয়
- **মানুষের মতো কন্ঠ (`CloudTtsEngine.kt` + `TtsEngine`)**: তোমার নিজস্ব API key দিয়ে
  OpenAI-সামঞ্জস্যপূর্ণ `/audio/speech`-এ neural TTS কল হয় (মডেল `gpt-4o-mini-tts` / `tts-1`,
  কন্ঠ `nova / shimmer / onyx / alloy / echo / fable`) → MP3 MediaPlayer-এ বাজে; barge-in-এ থামে।
  কোনো key/নেটওয়ার্ক না থাকলে সিস্টেম TTS-এ ফলব্যাক; তোমার বসানো on-device মডেল সবার আগে চলে।
  **কোনো Maya voice pack/native মডেল বান্ডেল নেই**
- **কথা বলার মোড (`SpeechMode.kt`)**: UI-তে ৪টি বাটন — **চটপট / শান্ত / কড়া / মজার**।
  মোড বদলালেই system prompt-এর স্বর-নির্দেশ + TTS গতি/স্বর দুটোই বদলে যায়;
  "কন্ঠ শুনে দেখো" বাটনে বর্তমান কন্ঠে এক লাইন শোনা যায়
- **স্থায়ী আচরণকোষ (`ZaraBehavior.kt`)**: LLM না থাকলেও ZaRa একই স্বরে কথা বলে —
  অভিবাদন, পরিচয়, সামর্থ্য, থামা, সময় শেষ, অনুমতি না পাওয়া, ত্রুটি — সব নিজস্ব বাংলা বাক্য।
  মডেলের উত্তর `polish()` দিয়ে markdown বাদ, ৩ ছোট বাক্য, ফল-প্রথম করা হয়
- **Barge-in**: কথা বলার মাঝে ব্যবহারকারী কথা বললেই `VoiceService` → `VoiceSession.bargeIn()`
  → চলতি agentJob বাতিল + TTS `stop()` + "থামলাম। বাকিটা কাটা দিলাম।"
- **Turn-taking**: `TurnTakingGate` এখন কার্যকরভাবে ব্যবহৃত — ব্যবহারকারী কথা বলছে কি না (VAD `isSpeech`)
  দেখে SPEAK / DEFER / SUPPRESS সিদ্ধান্ত; ওভারল্যাপ করে কথা বলা হয় না
- **Wake gate**: `ও জারা` / `জারা` শোনা গেলে prefix কেটে "বলো, শুনছি।" — পরে কমান্ড চালানো হয়
- **Local fallback**: সময়/পরিচয়/সামর্থ্যের মতো দ্রুত প্রশ্ন API ছাড়াই উত্তর পায়;
  UI-তে "লিখে বলো" ফিল্ড দিয়ে API key ছাড়া persona টেস্ট করা যায়
- Agent core: StopWordDetector (৬-টোকন cancel window), fixed ToolRegistry,
  ModelClient (user-key chat endpoint),
  AgentLoop (tool call → **বাংলা confirmation dialog** → result → history, 180 s timeout)
- **Dialogue coverage (`ZaraBehavior.kt`)**: অভিবাদন, পরিচয়, সামর্থ্য, "কেমন আছো", ধন্যবাদ,
  নতুন কী, বিদায়, সময়, ব্যাটারি, টুল-সমাপ্তি, ত্রুটি, নেটওয়ার্ক — সব নিজস্ব বাংলা বাক্য,
  একই আত্মবিশ্বাসী ভঙ্গি। কোনো Maya string কপি নয়
- **On-device model hook (`OnDeviceEngines.kt`)**: তোমার নিজস্ব Piper/Kokoro/Whisper/Silero মডেল
  `installStt()` / `installTts()` দিয়ে বসানো যায়। **কোনো মডেল অ্যাপে বান্ডেল করা নেই**
- **Unlock (`SecureGate.kt` + `BiometricPrompt`)**: সংবেদনশীল টুলের আগে Android-র নিজস unlock
  যাচাই; ZaRa কোনো PIN/pattern সংরক্ষণ বা replay করে না (spoofable receiver নেই)
- Settings: DataStore-এ ব্যবহারকারীর নিজস্ব API key / endpoint / voice / speed / pitch
- Compose UI (Bangla)

## বাকি ধাপ — এই ব্যাচে যোগ হয়েছে
- **কী-বিহীন STT (`SystemSttEngine.kt`)**: Android-র নিজস্ব SpeechRecognizer (`bn-BD`) —
  API key ছাড়াই "কী ছাড়া শুনো" বাটনে কথা বুঝে; নেট/কী থাকলে neural `/audio/transcriptions` ব্যবহার হয়
- **Consent framework (`ConsentManager.kt`)**: প্রতিটি সংবেদনশীল টুলের আগে biometric + এক-বারের,
  ৬০ সেকেন্ডের grant; ব্যবহারের সাথে সাথে consume, barge-in-এ revoke
- **Guardian (`Guardian.kt`)**: PIN/OTP/password-মতো argument বাতিল, ১২ কল/মিনিট রেট লিমিট,
  privileged টুলে ২ সেকেন্ড cooldown, লগে redaction
- **অটোমেশন টুল (`AutomationTools.kt`)**: আসল ব্যাটারি লেভেল, রিমাইন্ডার (AlarmManager +
  `ReminderReceiver`), স্থানীয় নোট যোগ/খোঁজা — প্রতিটি ফিক্সড + consent-গেটেড
- **Memory (`MemoryStore.kt`)**: সম্পূর্ণ স্থানীয় JSON, keyword scoring + embedding hook;
  কোনো ক্লাউড আপলোড নেই
- **Restart-storm guard (`RestartGuard.kt`)**: ১ মিনিটে ৫ বারের বেশি রিস্টার্ট হলে নীরব
- **OAuth state (`OAuthState.kt`)**: নিজস্ব connector-এর জন্য random state + PKCE S256 + ১০ মিনিট expiry
- **MediaProjection (`MediaProjectionGate.kt` + `ScreenCaptureService.kt`)**: শুধু Android-র
  consent dialog; সবসময় দৃশ্যমান notification; ফ্রেম শুধু on-device sink-এ, কোনো আপলোড নেই

## A-to-Z প্যারিটি ব্যাচ — নতুন করে যোগ হয়েছে
- **১৩টি স্ক্রিন** (`ZaRaScreens.kt` + `ZaRaApp` হোস্ট): হোম, সহকারী, শ্রবণ, ভয়েস,
  কনেক্টর, ব্রাউজার, কনসোল, ফেস গার্ড, গার্ড, আনলক, স্ক্রিন শেয়ার, অনুমতি, PC-তে পাঠাও
- **বুট/সার্ভিস**: `BootReceiver` (ব্যবহারকারীর সুইচে rearm), `AssistantActivity` (`ACTION_ASSIST`),
  `ZaraRecognitionService` (`bn-BD`), `ZaraVoiceInteractionService`, `ZaraWallpaperService`
- **অটোমেশন**: `ZaraAccessibilityService` + `AccessibilityTools` (read/tap/key/swipe) —
  দৃশ্যমান notification + প্রতি ধাপে biometric/consent; `CameraTools` (ছবি শুধু ডিভাইসে),
  `ContactTools` (খোঁজা/যোগ করা, runtime permission সহ)
- **কনেক্টর**: `ConnectorTools` — weather/news/search/market/email/`send_to_pc`, শুধু তোমার নিজস্ব `https://` URL/key
- **ResearchTools**: `deep_research` (search + তোমার LLM key দিয়ে বাংলা সংক্ষেপ) + sandbox-এ ফাইল লেখা/পড়া — কোনো shell/deploy নেই
- **ওয়ার্কার**: `ProactiveWorker`, `NoticeWorker`, `SocialAlarmReceiver`, `MarketingAlarmReceiver` —
  কোনো সার্ভার পুশ নেই, শুধু স্থানীয় রিমাইন্ডার
- **টুল কনসোল**: dedupe hint + latency/success log + in-app `read_page` + import/export
- **ডাটা**: `ChatHistoryStore` এখন চ্যাটের সাথে সংরক্ষিত; `DataImporter` UI-তে wire;
  export-এ API key কখনো লেখা হয় না

## এখনো তোমার নিজস্ব key/config ছাড়া পূর্ণ নয়
- Google/GitHub/Notion-এর মতো OAuth connector-এর client ID
- TFLite wake word / Silero VAD / Piper-Kokoro মডেল (মডেল তুমি বসাবে)

## যেগুলো ইচ্ছেকৃতভাবে দেওয়া হয়নি
- **Maya-র voice model / TTS অ্যাসেট** — IP কারণে কপি করা হয়নি; তার বদলে তোমার নিজস্ব ওপেন মডেল বসানোর hook আছে
- **Maya-র বিল্ট-ইন dialogue string** — শাব্দিকভাবে কপি করা হয়নি; একই ভঙ্গির নতুন বাংলা dialogue আছে
- **Remote `bash -lc` / server-pushed tool bundle** — এটা backdoor-র মতো; দেওয়া হয়নি। টুল fixed + প্রতি-অ্যাকশনে অনুমতি
- **PIN/pattern replay** — দেওয়া হয়নি; Android-র `BiometricPrompt` দিয়ে নিজে unlock করো
- কোনো embedded credential নেই — সব কিছু ব্যবহারকারীর নিজস্ব

## ডিজাইন সীমাবদ্ধতা (design limits)
- কোনো covert screen capture/upload নেই; MediaProjection হলে system consent + visible indicator থাকবে
- কোনো spoofable receiver নেই; সব service `exported=false`
