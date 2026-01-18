# Presentation Layer

The Presentation layer contains all the UI components. It is built using Flutter widgets and follows a goal-oriented screen organization.

## Directory Structure

### `screens/`
- **`main_screen.dart`**: The primary dashboard/navigation hub.
- **`add_entry_screen.dart`**: Interactive form for adding/editing OT shifts.
- **`statistics_screen.dart`**: Data visualization using charts and summaries.
- **`citizen_search/`**: A specialized sub-directory containing lookup features (BHXH, MST, Traffic Fines).
- **`lock_screen.dart`**: Security layer for local PIN authentication.

### `widgets/`
Shared UI components such as custom buttons, input fields, and specialized list items (e.g., `OvertimeListTile`).
