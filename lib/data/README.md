# Data Layer

The Data layer manages state persistence, models, and interactions with external services (APIs, Google Drive, etc.).

## Directory Structure

### `models/`
Entities representing the data structure:
- `CashTransaction`: Project-based finances.
- `CitizenProfile`: Personal data for lookups.
- `DebtEntry`: Lending/borrowing records.
- `OvertimeEntry`: Work shift data.

### `services/`
Core business logic and external integrations:
- **`storage_service.dart`**: Local DB manager (Sqflite).
- **`auth_service.dart`**: User identity and Google Sign-In.
- **`backup_service.dart`**: Google Drive synchronization.
- **`excel_service.dart`**: Advanced report generation.
- **`notification_service.dart`**: Local and background notifications.
- **`update_service.dart`**: Automated update checks from GitHub.
