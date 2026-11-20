# ZaRa ↔ Maya 5.2.63 — A to Z ফিচার/ওয়ার্কফ্লো ম্যাপ

ভিত্তি: `../Maya_5.2.63_feature_workflows.md` (স্ট্যাটিক RE, ১২ সেকশন) + বর্তমান ZaRa কোড।
কোনো Maya endpoint, HMAC secret, cert pin, OAuth client ID, voice/TTS মডেল অ্যাসেট,
বিল্ট-ইন dialogue string বা server-pushed tool bundle ব্যবহার করা হয়নি।

**চিহ্ন:** ✅ আছে · 🛡️ নিজস্ব সমতুল্য · 🔧 ব্যবহারকারীর নিজস্ব key/config দিয়ে চলে · ⏳ এখনো নেই · ❌ সীমার বাইরে

---

## ১. অ্যাপ জীবনচক্র — স্টার্টআপ ও বুট

| Maya | ZaRa | অবস্থা |
|---|---|---|
| Crash-safe মোড (১২ঘণ্টায় ৩ ক্র্যাশে wake/3D বন্ধ) | `RestartGuard` — ১ মিনিটে ৫ বার রিস্টার্ট হলে নীরব | 🛡️ |
| License / signature / tamper check | Maya-র লাইসেন্স সার্ভার ব্যবহার করা হয়নি | ❌ infrastructure |
| Foreground engine service | `VoiceService` (microphone) + `ScreenCaptureService` (mediaProjection) | ✅ |
| Wake rearm / task-removed টিকে থাকা | `START_STICKY` + foreground notification | ✅ |
| `BOOT_COMPLETED` দিয়ে পুনরারম্ভ | `BootReceiver` — শুধু ব্যবহারকারী স্পষ্টভাবে চালু রাখলে (boot rearm switch) | 🛡️ |
| `open_route` / assistant picker intent | `AssistantActivity` (`ACTION_ASSIST`) + `VoiceInteractionService` + `RecognitionService` | 🛡️ |

## ২. ভয়েস পাইপলাইন

| Maya | ZaRa | অবস্থা |
|---|---|---|
| Wake word | `WakeWordDetector` — `ও জারা / জারা / zara / ok zara`, strips করে `বলো, শুনছি।` | 🛡️ |
| মাইক ক্যাপচার | `AudioCapture` + `FOREGROUND_SERVICE_MICROPHONE` + দৃশ্যমান notification | ✅ |
| STT | `ApiSttEngine` (user key) + `SystemSttEngine` (কী-বিহীন `bn-BD`) + `OnDeviceEngines.installStt()` | ✅+🔧 |
| Turn detect / barge-in | `Vad` + `StopWordDetector` + `TurnTakingGate` + `VoiceSession.bargeIn()` → কাজ ও কন্ঠ দুটো থামে | 🛡️ |
| AEC3 / Silero VAD native | বান্ডেল করা হয়নি; `Vad` আছে, মডেল বসানোর hook আছে | 🔧 |
| LLM provider | `ModelClient` — user-দেওয়া `baseUrl`/`apiKey` দিয়ে যেকোনো OpenAI-সামঞ্জস্যপূর্ণ provider | 🔧 |
| Tool-call parse | `AgentLoop.parseToolCall()` (`tool`/`name`/`arguments`) | ✅ |
| Tool dispatch + dedupe/latency | `ToolRegistry.call()` — dedupe hint + ৩০-এন্ট্রি latency/success log (কনসোলে দৃশ্যমান, কোথাও আপলোড নেই) | ✅ |
| TTS | `CloudTtsEngine` (neural `/audio/speech`, user key) → system TTS fallback → `OnDeviceEngines.installTts()` | ✅+🔧 |
| Maya PocketTts voice pack | কপি করা হয়নি (IP); বদলে নিজস্ব/লাইসেন্সকৃত মডেল বসানোর hook | ❌ / 🔧 |

## ৩. টুল সিস্টেম

| Maya | ZaRa | অবস্থা |
|---|---|---|
| বড় টুল ক্যাটালগ | `ToolRegistry` — সময়, ব্যাটারি, নোট/মেমরি, রিমাইন্ডার, ভলিউম, রিংগার, ব্রাইটনেস, টর্চ, অ্যাপ, সেটিংস, ওয়েব সার্চ, মিডিয়া, ক্লিপবোর্ড, নোটিফিকেশন, SMS, কল, মোড | 🛡️ |
| নিরাপদ/বিপজ্জনক গ্রুপ | `Tool.requiresConfirmation` + `Guardian` + `VoiceGuardian` | ✅ |
| Intent classifier (fast-path) | `IntentRouter` — ২০+ নিজস্ব বাংলা/ইংরেজি rule, মডেল না ডাকেই চলে | 🛡️ |
| Priority table | `ModeManager` (জরুরি/সাধারণ) + `Guardian` rate-limit | 🛡️ |
| দুই-ধাপ কনফার্মেশন | `SecureGate` (BiometricPrompt) + `ConsentManager` (এক-বারের ৬০সে grant) | 🛡️ |
| Password/OTP redaction | `Guardian.check()` + `Guardian.redact()` | ✅ |
| Server-pushed tools / skill bundle | **দেওয়া হয়নি** (backdoor-মতো)। বদলে `SkillEngine` — শুধু ডিভাইসে, ব্যবহারকারী নিজে লেখে, ইনস্টলে যাচাই | ❌ / 🛡️ |
| Macro recorder | `SkillEngine` + `MissionEngine` (fixed registry, shell-নিষিদ্ধ) | 🛡️ |
| Maya builtin_macros.json | কপি করা হয়নি; নিজেরা লিখে নাও | ❌ |
| Weather / news / market / email / PC-relay | `ConnectorTools` — ৬টি dedicated টুল, শুধু user-দেওয়া `https://` endpoint/key; absent হলে স্পষ্ট বার্তা | 🔧 |

## ৪. ডিভাইস অটোমেশন ও কন্ট্রোল

| Maya | ZaRa | অবস্থা |
|---|---|---|
| Accessibility tap/swipe/type | `ZaraAccessibilityService` + `AccessibilityTools` (read/tap/back-home-recents/swipe) — সবসময় দৃশ্যমান notification, প্রতি ধাপে biometric + consent + রোল-গেট | 🛡️ |
| Unlock | Android `BiometricPrompt` দিয়ে নিজে unlock; PIN/pattern replay নেই | 🛡️ / ❌ |
| নোটিফিকেশন পড়া | `ZaraNotificationListener` (system BIND permission) + `get_notifications` | 🛡️ |
| স্ক্রিন ক্যাপচার/শেয়ার | `MediaProjectionGate` + `ScreenCaptureService` — system consent + সবসময় দৃশ্যমান notification, ফ্রেম শুধু on-device sink | 🛡️ |
| গোপন ক্যাপচার/আপলোড | **দেওয়া হয়নি** | ❌ malware-like |
| ক্যামেরা / টর্চ | `set_torch` + `take_photo` (Android camera intent, FileProvider, ছবি শুধু ডিভাইসে, কোথাও আপলোড নেই) | 🛡️ |
| কল / SMS | `make_call`, `send_sms` — runtime permission + biometric + consent | 🛡️ |
| কনট্যাক্ট | `ContactTools` — `find_contact` / `save_contact`, runtime permission + biometric + consent | 🛡️ |
| সিস্টেম সেটিংস | volume, ringer, brightness (system permission সাপেক্ষে), torch, lock (admin সাপেক্ষে), open_app, open_settings, clipboard, media | 🛡️ |
| Termux `bash -lc` / arbitrary shell | **দেওয়া হয়নি** — এটা remote backdoor-র মতো | ❌ |
| HunterCode bridge / setup curl\|bash | কোনো বাহ্যিক ব্রিজের সাথে যোগাযোগ করা হয়নি | ❌ |
| ওয়ালপেপার / 3D character | `ZaraWallpaperService` — নিজস্ব হালকা canvas wallpaper (কোনো Maya 3D অ্যাসেট নয়) | 🛡️ |

## ৫. দীর্ঘ-চলা এজেন্টিক ফ্লো

| Maya | ZaRa | অবস্থা |
|---|---|---|
| `/v1/agentic/plan` + token/usage/unlock | Maya-র endpoint ব্যবহার করা হয়নি; বদলে স্থানীয় `AgentLoop` | ❌ / 🛡️ |
| Mission / chainer / cancel | `MissionEngine` — ধাপে ধাপে, প্রতি সংবেদনশীল ধাপে অনুমতি, যেকোনো সময় বাতিল | 🛡️ |
| Coding / website / deploy | `ResearchTools` — app-এর নিজস্ব sandbox-এ `write/read/list_work_file`; shell/deploy নেই | 🛡️ |
| Deep research / competitor / keyword | `deep_research` — user-দেওয়া `https://` search endpoint + user LLM key দিয়ে বাংলা সংক্ষেপ | 🔧 |
| Marketing / social / content calendar | `OAuthState` (PKCE S256) + `SocialAlarmReceiver` + `MarketingAlarmReceiver` (শুধু রিমাইন্ডার, স্বয়ংক্রিয় পোস্ট নয়) + user connectors | 🛡️ / 🔧 |
| PC bridge (`sync.hunterislive.online`) | Maya gateway-এর সাথে যোগাযোগ নেই; শুধু user-দেওয়া relay URL | ❌ / 🔧 |
| Browser `read_page` | কনসোলে in-app `WebView` + `document.body.innerText` (শুধু দেখা; নীরব আপলোড নেই) + `search_web` | 🛡️ |

## ৬. গার্ডিয়ান / ফেস-লক / ভয়েস-রোল

| Maya | ZaRa | অবস্থা |
|---|---|---|
| Voice guardian + roles | `VoiceGuardian` — মালিক/বন্ধু/অতিথি/ব্লক + speaker-verifier hook (ব্যবহারকারীর মডেল) | 🛡️ |
| Maya guardian models/manifest | ডাউনলোড বা ব্যবহার করা হয়নি | ❌ IP |
| Face lock / enroll | Android `BiometricPrompt`; নিজস্ব face-model hook যোগ করা যাবে | 🛡️ / 🔧 |
| Touch Guard — অনধিকৃত স্পর্শে ছবি + siren | **দেওয়া হয়নি** (covert capture) | ❌ |
| `whose_voice` / voice gate | `VoiceGuardian.allows()` + `identify()`; confidence দাবি করা হয় না | 🛡️ |

## ৭. মেমরি সিস্টেম

| Maya | ZaRa | অবস্থা |
|---|---|---|
| `remember_fact` / `recall_memory` / `forget_memory` | `MemoryStore` + টুল — সব স্থানীয় JSON | ✅ |
| `remember_document` / `my_details` / `set_my_detail` | `MemoryStore` সমতুল্য টুল আছে | ✅ |
| Embedding semantic search | `MemoryStore.embedder` hook + keyword fallback | 🔧 |
| `/sync/facts` ক্লাউড সিঙ্ক | **করা হয়নি** — কোনো ক্লাউড আপলোড নেই | ❌ privacy |
| কথোপকথন ইতিহাস | `ChatHistoryStore` (স্থানীয়, ৪০০ বার্তা) — কনসোলে দেখা/মুছা/এক্সপোর্ট, চ্যাটের সাথে সংরক্ষিত | ✅ |
| Export / import | `DataImporter` — user-owned JSON/CSV/text, কনসোলে import/export বাটন; API key কখনো export করা হয় না | ✅ |

## ৮. নেটওয়ার্ক / ব্যাকএন্ড

| Maya | ZaRa | অবস্থা |
|---|---|---|
| License / provisioning / heartbeat | কোনো Maya সার্ভারের সাথে যোগাযোগ নেই | ❌ |
| Integrity telemetry (android_id, signature hash) | **পাঠানো হয়নি** | ❌ privacy |
| Ops ingest / periodic upload | নেই | ❌ |
| Gateway / relay / ticket | Maya relay ব্যবহার নেই; user-দেওয়া `baseUrl`-এ সরাসরি কল | 🔧 |
| Cert pinning / host obfuscation | replicates করা হয়নি (user config + Android/network stack) | ❌ |
| OAuth connectors | `OAuthState` PKCE; client ID ব্যবহারকারীর নিজস্ব | 🔧 |

## ৯. শেডিউলড ওয়ার্কার

| Maya | ZaRa | অবস্থা |
|---|---|---|
| Reminder / alarm | `ReminderReceiver` + AlarmManager (`set_reminder`) | ✅ |
| Proactive nudge | `ProactiveWorker` — স্থানীয় মেমরি থেকে ছোট নোটিফিকেশন, কোনো ক্লাউড পুশ নেই | 🛡️ |
| Social / marketing alarm | `SocialAlarmReceiver` + `MarketingAlarmReceiver` — শুধু অনুমতি-ভিত্তিক রিমাইন্ডার | 🛡️ |
| Wiki / notice worker | `NoticeWorker` — স্থানীয় নোটিফিকেশন (কোনো notice সার্ভার নেই) | 🛡️ |
| Phone-state / mic event | `VoiceService` + `bargeIn` | 🛡️ |

## ১০. ইউজার-ফেসিং স্ক্রিন — ১৩টি রুট ✅

`MainActivity` + `ZaRaApp` কম্পোজ হোস্টে Maya-র ১৩টি Activity-র নিজস্ব সমতুল্য ১৩টি স্ক্রিন:

| # | ZaRa স্ক্রিন | কাজ |
|---|---|---|
| ১ | হোম (`ZaraScreen`) মাইক/টেক্সট/মোড/স্কিল/মিশন/সেটিংস + confirmation dialog |
| ২ | সহকারী (`AssistantScreen`) — `ACTION_ASSIST` এন্ট্রি |
| ৩ | শ্রবণ (`RecognitionScreen`) — কী-বিহীন `bn-BD` স্টেটাস |
| ৪ | ভয়েস (`VoiceInteractionScreen`) — ভয়েস-ইন্টারঅ্যাকশন/কন্ঠ পরীক্ষা |
| ৫ | কনেক্টর (`ConnectorsScreen`) — user-owned endpoint + PKCE state |
| ৬ | ব্রাউজার (`BrowserScreen`) — in-app `read_page` |
| ৭ | কনসোল (`TaskConsoleScreen`) — টুল log/latency, মিশন, import/export |
| ৮ | ফেস গার্ড (`FaceGuardScreen`) — BiometricPrompt + role |
| ৯ | গার্ড (`WatchGuardScreen`) — দৃশ্যমান ইঙ্গিত, covert capture নেই |
| ১০ | আনলক (`UnlockScreen`) — সিস্টেম unlock, PIN/pattern replay নেই |
| ১১ | স্ক্রিন (`ScreenShareScreen`) — MediaProjection consent/stop |
| ১২ | অনুমতি (`ToolPermissionScreen`) — accessibility/notification/boot/worker |
| ১৩ | PC তে পাঠাও (`SendToPcScreen`) — শুধু user-দেওয়া relay |

সব স্ক্রিনে একই `ZaraViewModel` + guardian/consent gate; কোনো Maya Activity/লেআউট/স্ট্রিং কপি করা হয়নি।

## ১১. Persona ও সেটিংস

| Maya | ZaRa | অবস্থা |
|---|---|---|
| `maya / myra / jarvis / friday / venom / hunter` | নামগুলো ব্যবহার করা হয়নি (impersonation)। বদলে ৪টি কথার মোড: চটপট/শান্ত/কড়া/মজার + ৪টি রোল | ❌ / 🛡️ |
| System prompt + tone | `ZaraPersona.system(mode)` + `ZaraBehavior` — সব নিজস্ব বাংলা | 🛡️ |
| Settings store | `Settings` (DataStore) — key, URL, model, voice, speed, pitch, TTS model/voice | ✅ |

## ১২. শেষ থেকে শেষ — "কথা বলা → কাজ"

```
ও জারা / মাইক → WakeWordDetector → Vad → STT (user key | সিস্টেম | on-device)
  → IntentRouter fast-path  →  হলে: Guardian + BiometricPrompt + ConsentManager → টুল
  → না হলে: ZaraPersona + Memory + fixed tool schema → ModelClient (user key)
  → tool parse → ToolRegistry → VoiceGuardian role gate → biometric confirm
  → TTS (neural user key | system | on-device) → barge-in-এ থামে
  → MemoryStore (স্থানীয়) + কোনো telemetry/worker নেই
```

---

## কঠিন সীমা — যা ZaRa-তে আসবে না

| বাদ দেওয়া হয়েছে | কারণ | নিজস্ব বিকল্প |
|---|---|---|
| Maya voice model / PocketTts pack | মালিকানা (IP) | `OnDeviceEngines.installTts()` + neural TTS (user key) |
| Maya বিল্ট-ইন dialogue string | শাব্দিক কপি | `ZaraBehavior` — নতুন বাংলা, একই আত্মবিশ্বাসী ভঙ্গি |
| Maya name / persona / identity | impersonation | `ZaRa`, নিজস্ব পরিচয় |
| Maya endpoint / HMAC / cert pin / OAuth ID | infrastructure reuse | user-দেওয়া `baseUrl`/key + `OAuthState` |
| Server-pushed tool/skill bundle | অ্যাপ আপডেট ছাড়াই নতুন কোড আসে → backdoor | স্থানীয় `SkillEngine`, ইনস্টলে যাচাই |
| Termux `bash -lc` / remote shell | arbitrary code execution | fixed `ToolRegistry` + per-action consent |
| Covert screen/photo capture + upload | malware-মতো | MediaProjection + system consent + দৃশ্যমান notification |
| PIN/pattern replay / spoofable receiver | security flaw | `BiometricPrompt` + BIND-permission service |
| Telemetry / cloud memory sync | privacy | সব কিছু শুধু ডিভাইসে |

---

## এখনো key/config-নির্ভর (🔧) বা সীমার বাইরে (❌)

1. OAuth connector-গুলোর নিজস্ব client ID (Google/GitHub/Notion…) — ব্যবহারকারী বসাবেন
2. Silero VAD / TFLite wake word / Piper-Kokoro STT-TTS — মডেল ব্যবহারকারী বসাবেন (IP কপি করা হয়নি)
3. কোনো Maya endpoint/HMAC/telemetry/remote shell/covert capture — **কখনো যোগ করা হবে না**

> **কম্পাইল অবস্থা:** gradle/kotlinc এই পরিবেশে নেই — Android Studio-তে build করে যাচাই করতে হবে।
