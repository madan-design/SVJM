# SVJM Quote Generator App

A Flutter application for SVJM Mould & Solutions to generate, manage, and track quotes and projects.

---

## Features

- Generate professional PDF quotes
- Save and manage quote history
- Confirm quotes → auto-move to Projects
- Track project expenses with live budget calculations
- Generate and share expense sheet PDFs
- Draft auto-save (persists across app switches)
- Dark/Light theme support
- **Multi-user login** — Admin and Mould Design Engineer (MDE) roles
- **Cloud sync** — all quotes, projects and expenses stored in Supabase, synced across devices
- **Archive system** — archive and restore quotes/projects
- **Assign Project** — admin assigns projects to MDEs with token system
- **MDE Dashboard** — designers see assigned/completed work and upload files
- **Cross-platform** — Android app + Web browser support

---

## File Descriptions

### `lib/main.dart`
App entry point. Configures Material3 theme with SVJM brand color (`#C40000`), light/dark theme support, and launches `SplashScreen`.

### `lib/models/quote_model.dart`
Data model for a quote. Contains fields: `date`, `company`, `address`, `subject`, `components`. Provides `toJson()` for serialization.

### `lib/screens/splash_screen.dart`
Animated splash screen shown on app launch. Displays the app logo with a fade-in animation and app version number. Navigates to `HomeScreen` after 3.2 seconds.

### `lib/screens/home_screen.dart`
Main landing page with SVJM top bar. Contains two card-style navigation buttons:
- **Quote Generator** → navigates to `_QuoteMenuScreen` (Create Quote + History)
- **Projects** → navigates to `ProjectsScreen`

### `lib/screens/form_slides.dart`
Multi-page form (3 slides) for creating a new quote:
- Page 1: Date picker + Company name (with autocomplete from history)
- Page 2: Address + Subject
- Page 3: Add/Edit/Delete components with machine toggle
- Auto-saves draft to `SharedPreferences` on every change
- Restores draft when app is resumed
- Clears draft after successful quote generation

### `lib/screens/preview_screen.dart`
PDF preview screen after quote generation. Allows renaming, saving, sharing, and sending via email. Navigates to `MailPreviewScreen` after saving.

### `lib/screens/history_screen.dart`
Displays all **draft and confirmed** quotes grouped by company in expandable folder cards. Each draft quote has:
- View, Share, Mail, Delete actions
- **Confirm Quote** button → changes status to `confirmed` and moves quote to Projects tab

Confirmed quotes show an **✓ Approved** badge with no delete/edit/mail options.

### `lib/screens/projects_screen.dart`
Displays all confirmed projects grouped by company as card-style buttons. Each company card shows live/completed badge counts. Navigates to `CompanyProjectsScreen`.

### `lib/screens/company_projects_screen.dart`
Shows all projects under a specific company, split into:
- 🟡 Live Projects
- 🟢 Completed Projects

Each project card shows company name, auto-generated Project ID, and total cost.

### `lib/screens/project_detail_screen.dart`
Full project dashboard. Displays:
- Company name, Project ID, Quote date
- Total Budget, Total Spent, Remaining Budget (live)
- View Quote PDF button
- Expense Sheet (view/download/share as PDF) — shows popup if no expenses added
- Compact Add Expense form (date + amount in one row, note + Add button in second row)
- Expense list with delete option
- Mark as Completed button (green, prominent in AppBar)

### `lib/screens/mail_preview_screen.dart`
Email preview screen with AI-generated subject and body (via Gemini). Allows editing before sending.

### `lib/services/storage_service.dart`
Handles all cloud persistence via Supabase:
- Save/load/delete quotes (PDF in `quotes-pdf` bucket + metadata in `quotes` table)
- `confirmQuote()` — sets status to `confirmed`
- `completeProject()` — sets status to `completed`
- `getAllProjects()` — returns only confirmed/completed quotes
- `getExpenses()` / `addExpense()` / `deleteExpense()` / `updateExpense()` — expense CRUD in `expenses` table
- `archiveItem()` / `unarchiveItem()` / `getAllArchived()` — archive management
- `moveToQuote()` / `reactivateProject()` — status transitions
- `DraftService` — saves/loads/clears form draft locally via `SharedPreferences`

### `lib/services/auth_service.dart`
Supabase authentication wrapper:
- `login()` / `logout()` — email/password auth
- `getRole()` — reads role from JWT metadata (instant, no DB call)
- `getProfile()` — fetches name and role from `profiles` table
- Session persists across app restarts automatically

### `lib/services/supabase_service.dart`
Handles MDE token and file operations:
- `createToken()` / `getAllTokens()` / `getMyTokens()` / `deleteToken()` — project assignment CRUD
- `uploadFile()` / `getFilesForToken()` / `getSignedUrl()` / `deleteFile()` — file management in `project-files` bucket
- `getMdeList()` — fetches all MDE profiles for admin assignment dropdown

### `lib/screens/login_screen.dart`
Login page shown on every app launch. Email/password only (no signup). Remembers session — auto-navigates to correct dashboard on next open.

### `lib/screens/admin/admin_home_screen.dart`
Admin dashboard with 4 navigation cards: Quote Generator, Projects, Archive, Assign Project. Shows admin name in header.

### `lib/screens/admin/assign_project_screen.dart`
Two-tab screen:
- **Assign tab** — create tokens from approved quotes or custom names, assign to MDE designers
- **View Files tab** — accordion list of all tokens showing files uploaded by MDEs

### `lib/screens/mde/mde_home_screen.dart`
MDE dashboard showing designer name, stats cards (assigned/completed count), and two accordion folders for Assigned and Completed projects.

### `lib/screens/mde/mde_project_screen.dart`
Per-project file manager for MDEs. Shows uploaded files, allows uploading new files (any 3D/document/image format), delete files, and mark project as complete.

### `lib/services/project_service.dart`
Utility service for project logic:
- `generateProjectId()` — generates `SVJM-{initials}-{number}` from company name and file name
- `totalBudget()` — sums component amounts from quote
- `totalSpent()` — sums all expenses
- `formatAmount()` — Indian number formatting with ₹ symbol

### `lib/services/expense_pdf_service.dart`
Generates expense sheet PDF matching the HTML template design (`expense_template.html`). Includes SVJM header, company/project info, budget summary box, expense table, and footer. PDF is named `Expense of {projectId}.pdf`.

### `lib/services/pdf_service.dart`
Generates quote PDF with SVJM branding, watermark, components table, terms & conditions, bank details, and signature.

### `lib/services/gemini_service.dart`
Calls Google Gemini API to generate professional email subject and body content for a given quote.

### `lib/services/api_service.dart`
Base HTTP service for API calls.

### `lib/widgets/component_table.dart`
Reusable widget to display a list of quote components as cards.

### `lib/widgets/capitalize_formatter.dart`
`TextInputFormatter` that auto-capitalizes the first letter of each word.

### `lib/widgets/input_formatters.dart`
Custom input formatters:
- `IndianAmountFormatter` — formats numbers in Indian currency style
- `MachineFormatter` — formats machine tonnage input

### `lib/config/app_config.dart`
App-level configuration constants (API keys, endpoints).

### `templates/quote_template.html`
HTML reference template for the quote PDF layout.

### `templates/expense_template.html`
HTML reference template for the expense sheet PDF layout. Used as design reference for `ExpensePdfService`.

### `assets/`
- `app_logo.png` — SVJM logo used in splash screen and PDF header
- `logo.png` — alternate logo used in PDF
- `bg.png` — watermark background for quote PDF
- `sign.png` — proprietor signature image for quote PDF
- `Quote generator.png` — icon used in the Quote Generator home card
- `projects.png` — icon used in the Projects home card
- `fonts/` — Times New Roman font variants (regular, bold, italic, bold-italic) used in PDFs

---

## Version History

| Version | Changes |
|---------|---------|
| v1.0.0 | Initial release |
| v1.1.0 | History screen, PDF sharing, email integration |
| v1.2.0 | Dark mode, component edit, draft auto-save, home screen redesign |
| v1.2.1 | Projects tab, Confirm Quote, expense tracking, expense sheet PDF |
| v2.0.0 | Multi-user login (Admin / MDE roles), Supabase backend, cloud sync across devices, Archive system, Assign Project with file uploads, MDE dashboard, cross-platform (Android + Web) |
