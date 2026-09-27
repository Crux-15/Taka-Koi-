<div align="center">

<h1>💛 Taka Koi?</h1>

<p><strong>"Taka Koi?"</strong> means <em>"Where's the money?"</em> in Bengali.</p>

<p>A smart, real-time <strong>group expense tracker</strong> built for friends on trips & tours.<br/>
Split bills, track who owes who, and settle up — without the awkward conversations.</p>

<img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white"/>
<img src="https://img.shields.io/badge/Firebase-Firestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black"/>
<img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge"/>
<img src="https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white"/>

<br/><br/>

<a href="https://github.com/Crux-15/Taka-Koi-/releases/latest/download/Taka-Koi.apk">
  <img src="https://img.shields.io/badge/⬇️%20Download%20APK-Taka%20Koi%3F%20v1.0.0-FFD700?style=for-the-badge&logoColor=black" alt="Download APK"/>
</a>

</div>

---

## 📲 Install on Android

> **No Play Store needed** — just download and install directly!

1. On your Android phone, open this link: **[⬇️ Download Taka Koi?.apk](https://github.com/Crux-15/Taka-Koi-/releases/latest/download/Taka-Koi.apk)**
2. If asked *"Allow from this source"* → tap **Allow**
3. Tap the downloaded file → tap **Install**
4. Done! Open **Taka Koi?** and sign in 🎉

> **Note:** If you see *"Install blocked"*, go to your phone's **Settings → Security → Install unknown apps** and allow your browser.

---

## ✨ Features

### 👥 Group Management
- Create a trip group and share a **6-character invite code** with friends
- Admin approval for join requests
- Real-time member list with expense rankings
- Request to leave group (admin approval required)
- Group history — view all past tours

### 💸 Expense Tracking
- Log expenses with amount, description & GPS location capture
- **Equal split** or **custom split** per member
- Admin approval workflow for all submitted expenses
- Members can request deletion — admin approves or rejects
- Full expense history with filters

### 🏦 Debt Settlement
- Automatically calculates **who owes who** after expenses
- "I Owe" and "Owed to Me" tabs
- Log payments with proof — admin approves
- Net debt calculation to simplify complex group balances

### 🔔 Smart Notifications
- In-app real-time notifications for every action
- Tappable notifications — tap to review, approve, or act
- Unread badge count on the notification tab

### 📲 bKash Integration
- Request a member's bKash number privately
- Member receives notification — Accept or Decline
- Once accepted, number shows with a **one-tap copy** button
- Number stays hidden from others unless explicitly shared

### 🔐 Authentication
- **Google Sign-In**
- **Email + OTP verification** → Password setup
- Profile photo upload (Firebase Storage)
- bKash number in profile

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter 3.x (Dart) |
| **State Management** | Provider |
| **Navigation** | GoRouter |
| **Backend** | Firebase Firestore (real-time) |
| **Auth** | Firebase Auth (Google + Email/Password) |
| **Storage** | Firebase Storage (avatars) |
| **Architecture** | MVC (Model–View–Controller) |

---

## 📁 Project Structure

```
lib/
├── controllers/     # Business logic (Auth, Group, Expense, Debt, Notification)
├── models/          # Data models (User, Group, Expense, Debt, Payment, Notification)
├── services/        # Firebase service layer
├── utils/           # Constants, theme, colors, router
├── views/           # UI screens
│   ├── auth/        # Login, Register, OTP, Profile Setup
│   ├── expenses/    # Home, Log Expense, History, Detail
│   ├── debts/       # Debt Overview, Log Payment, Payment Review
│   ├── group/       # Group Hub, Create, Join, Admin Dashboard
│   ├── notifications/
│   └── profile/
└── widgets/         # Reusable UI components
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK `>=3.0.0`
- Firebase project (Firestore, Auth, Storage enabled)
- Android Studio / VS Code

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/Crux-15/Taka-Koi-.git
   cd Taka-Koi-
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Add your Firebase config**
   - Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
   - Add an Android app and download `google-services.json`
   - Place it in `android/app/google-services.json`
   - Enable **Firestore**, **Authentication** (Google + Email/Password), and **Storage**

4. **Run the app**
   ```bash
   flutter run
   ```

---

## 🔒 Security Notes

- `google-services.json` is excluded from version control (`.gitignore`)
- All expense and payment approvals require admin authorization
- bKash numbers are hidden by default — only revealed after explicit consent
- Firestore security rules should be configured before production deployment

---

## 📸 App Flow

```
Splash → Login / Register (OTP)
      → Group Hub (no active group)
            → Create Group  OR  Join with code
      → Home (active group)
            → Log Expense → Admin Approves → Debts Auto-calculated
            → Debt Tab → Log Payment → Admin Approves → Settled
            → Notifications → Tap to Review / Approve / Act
            → Profile → Edit info, bKash number, leave group
```

---

## 👨‍💻 Author

**Sadman Sakib**
- GitHub: [@Crux-15](https://github.com/Crux-15)

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

<div align="center">
<p>Made with 💛 for friends who travel together</p>
</div>
