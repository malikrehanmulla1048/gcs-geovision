# Comprehensive Flutter Migration Task for GeoVision Web App

**Project Context**: This repository contains the "GCS - GeoVision" web application. It is a highly styled, dark-mode Campus Security Command Centre with components for admins (`/admin`), users (`/user`), and students (`/student`). 

**Your Goal**: Convert the ENTIRE web application into a fully functioning, standalone Flutter application located in the existing `flutter_app` directory. The final Flutter app must be a pixel-perfect, 1:1 replica of the web app, maintaining all visual aesthetics, animations, responsive layouts, and logic.

## Phase 1: Deep Project Analysis & Visual Mapping
Before writing any Flutter code, you must deeply understand the existing web application.
1. **Codebase Scan**: Analyze the entire project directory line-by-line. Read through `index.html`, all files in `/admin`, `/user`, `/student`, and `/assets`, as well as the stylesheets in `/css` and logic in `/js` / `.py`.
2. **Visual Assessment (MANDATORY)**: You MUST open the local HTML files in your integrated browser (e.g., `file:///[Absolute_Path_To_Repo]/index.html`). 
   - Take screenshots of EVERY single page, including different states (hover states, active states, modals, dropdowns).
   - Click on every button, open every menu, and capture the UI changes.
   - Pay extreme attention to the dark-mode aesthetic, grid-textured backgrounds, glow effects, gradients, and custom fonts.
   - Record the exact hex codes, padding/margin values, and animation timings from the CSS.

## Phase 2: Flutter Scaffolding
1. Navigate into the `flutter_app` directory.
2. If it is empty, initialize a new Flutter project (`flutter create .`).
3. Ensure the `flutter_app` is completely standalone. Copy any required databases (like `face_db.db`, `users.db`), images, fonts, and other static assets from the parent `GCS - GeoVision` folder into the `flutter_app/assets` directory. Update the `pubspec.yaml` to include these assets.
4. Set up a robust folder structure within `flutter_app/lib` (e.g., `/screens`, `/widgets`, `/services`, `/models`, `/theme`, `/utils`).

## Phase 3: Pixel-Perfect Translation
1. **Theming**: Create a comprehensive `ThemeData` file in Flutter that perfectly encapsulates the CSS variables and styles found in the web app (colors, typography, gradients, glassmorphism effects).
2. **Screen-by-Screen Recreation**:
   - Begin with the authentication portal (`index.html`).
   - Recreate the User screens (`user/profile.html`, `user/face_capture_system.html`, etc.).
   - Recreate the Admin dashboard (`admin/dashboard.html`, `admin/cctv-feed.html`, `admin/security-threats.html`, etc.).
3. **Logic & Routing**: Implement Flutter routing (`go_router` or standard Navigator) to match the navigation flow of the web app. Connect the frontend UI to any existing backend logic (Python/Flask) using HTTP requests, or replicate local JS logic in Dart.

## Phase 4: Rigorous Self-Verification (The 10-Check Process)
You must execute a rigorous QA process. For every screen you build, check it against your original screenshots AT LEAST 10 TIMES:
- **Check 1**: Do the background gradients and textures match exactly?
- **Check 2**: Are the fonts exactly the same weight, size, and family?
- **Check 3**: Are all padding, margins, and borders identical to the web version?
- **Check 4**: Do the buttons have the exact same hover/active effects?
- **Check 5**: Are the shadows, glow effects, and glassmorphism (backdrop filter) applied correctly?
- **Check 6**: Are all assets (images/icons) rendering cleanly?
- **Check 7**: Does the layout respond to screen resizing identically to the web app?
- **Check 8**: Does the navigation flow exactly map to the web app's UX?
- **Check 9**: Is the state management robust and functioning without errors?
- **Check 10**: Is the code modular, maintainable, and strictly following Flutter best practices?

**IMPORTANT**: Take your time and think deeply before writing code. Do not hallucinate or skip pages. Ensure every single page, function, and feature from the web app is present and fully working in the new standalone Flutter app.
