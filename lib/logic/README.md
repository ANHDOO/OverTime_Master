# Logic Layer

The Logic layer serves as the bridge between Data and Presentation. It manages the app's reactive state using the **Provider** pattern.

## Directory Structure

### `providers/`
- **`overtime_provider.dart`**: Orchestrates overtime records and calculations.
- **`cash_transaction_provider.dart`**: Manages project-based transactions and balances.
- **`debt_provider.dart`**: Handles debt-specific logic and repayment status.
- **`gold_provider.dart`**: Fetches and manages commodity price data (Gold, Fuel).
- **`theme_provider.dart`**: Manages application-wide theme switching (Light/Dark).
