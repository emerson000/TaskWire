# TaskWire

A Flutter task management application with Drift database persistence.

## Features

- **Hierarchical Tasks**: Create tasks with unlimited nested subtasks
- **Persistent Storage**: Uses Drift (SQLite) for reliable data persistence
- **Task Management**: Create, update, delete, and mark tasks as complete
- **Task Organization**: Move tasks between parents and reorder them

## Architecture

The application follows a clean architecture pattern with:

- **Models**: Domain models representing tasks (`lib/models/task.dart`)
- **Database**: Drift database setup and table definitions (`lib/database/database.dart`)
- **Repository**: Data access layer bridging domain models and database (`lib/repositories/task_repository.dart`)
- **Service**: Business logic layer (`lib/services/task_manager.dart`)
- **UI**: Flutter widgets for the user interface (`lib/main.dart`)

## Database Structure

The application uses a single `tasks` table with the following structure:

```sql
CREATE TABLE tasks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  is_completed BOOLEAN DEFAULT FALSE,
  parent_id TEXT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

## Getting Started

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Generate Drift code:
   ```bash
   dart run build_runner build
   ```

3. Run the application:
   ```bash
   flutter run
   ```

## Key Dependencies

- `drift: ^2.27.0` - Type-safe database access layer
- `sqlite3_flutter_libs: ^0.5.0` - SQLite3 native libraries
- `path_provider: ^2.1.4` - Access to commonly used locations on the filesystem
- `path: ^1.9.0` - Path manipulation utilities

## Sample Data

The application includes sample data with three main task categories:
- Plan vacation (with nested accommodation options)
- Work project (with testing phases)
- Personal goals (with learning objectives)

This data is automatically loaded when the app runs for the first time.
