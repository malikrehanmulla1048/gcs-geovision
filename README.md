# GeoVision Flutter App

A **pixel-perfect Flutter port** of the GeoVision Campus Security Command Centre web app.

## 📁 Project Structure

```
lib/
├── main.dart                          ← App entry, Provider, Router setup
├── theme/
│   └── app_theme.dart                 ← Design tokens (mirrors shell.css :root)
├── models/
│   ├── user_model.dart                ← User entity
│   ├── entry_log.dart                 ← Entry/exit log entity
│   └── visitor.dart                   ← Campus visitor entity
├── services/
│   ├── db_service.dart                ← SQLite DB (mirrors api/db.js IndexedDB)
│   └── auth_service.dart              ← Session management + auth logic
├── router/
│   └── app_router.dart                ← GoRouter with auth-based redirects
├── widgets/
│   ├── common_widgets.dart            ← StatCard, SectionCard, Toast, Badge, etc.
│   └── admin_sidebar.dart             ← Admin sidebar + AdminShell layout
└── screens/
    ├── login_screen.dart              ← Login + Register (mirrors index.html)
    ├── admin/
    │   ├── dashboard_screen.dart      ← Security Command Centre
    │   ├── cctv_feed_screen.dart      ← 4×3 CCTV grid + fullscreen modal
    │   ├── entry_history_screen.dart  ← Live entry log with filters + table
    │   ├── security_threats_screen.dart ← Threats + pie chart + detail panel
    │   └── visitor_management_screen.dart ← Visitor table + map tracker
    └── user/
        ├── profile_screen.dart        ← User profile + edit bottom sheet
        ├── my_entries_screen.dart     ← User entry history grouped by date
        └── face_enrol_screen.dart     ← Animated face capture flow
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK ≥ 3.10.0
- Android Studio or VS Code with Flutter extension
- A connected Android/iOS device or emulator

### Install & Run
```bash
# Get dependencies
flutter pub get

# Run on Chrome (Recommended for testing)
flutter run -d chrome

# Or run on an emulator/device
flutter run
```

### Demo Credentials
| Role    | Email                   | Password |
|---------|-------------------------|----------|
| Admin   | admin@reva.edu.in       | Admin    |
| Student | student@reva.edu.in     | Student  |

## ✅ Feature Parity Checklist

| Web Feature                        | Flutter Implementation                    |
|------------------------------------|-------------------------------------------|
| Dark / Light theme toggle          | ✅ ThemeNotifier ChangeNotifier            |
| Auth login + register              | ✅ LoginScreen with tabs                  |
| Admin sidebar navigation           | ✅ AdminSidebar + AdminShell              |
| Dashboard with live feed           | ✅ DashboardScreen with Timer simulation  |
| CCTV 4×3 grid                      | ✅ GridView + fullscreen Stack overlay    |
| Entry history live table           | ✅ EntryHistoryScreen + filters           |
| Threats with pie chart             | ✅ CustomPainter donut + detail panel     |
| Visitor management + map           | ✅ CustomPainter map + visitor table      |
| User profile + edit sheet          | ✅ Bottom sheet overlay                   |
| My entries grouped by date         | ✅ Grouped ListView with filter chips     |
| Face enrolment flow                | ✅ Step-by-step animated capture          |
| Persistent session (localStorage)  | ✅ SharedPreferences                      |
| IndexedDB storage                  | ✅ SharedPreferences (JSON store)          |
| BroadcastChannel / SSE live events | ✅ Dart Timer simulation                  |
| Role-based routing (admin/student) | ✅ GoRouter redirect guards               |

## 🎨 Design Tokens

All CSS variables from `shell.css` are mapped 1:1 in `lib/theme/app_theme.dart`:

| CSS Variable        | Flutter Equivalent           |
|---------------------|------------------------------|
| `--clr-primary`     | `GeoColors.primary`          |
| `--bg-card`         | `theme.bgCard`               |
| `--bg-body`         | `theme.bgBody`               |
| `--text-primary`    | `theme.textPrimary`          |
| `--border-light`    | `theme.border`               |
| `--clr-danger`      | `GeoColors.danger`           |
| `--clr-success`     | `GeoColors.success`          |
| `--radius-lg`       | `GeoRadius.lg` (14.0)        |
