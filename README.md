# TaskWire

A cross-platform to-do app with integrated thermal printer support. TaskWire allows you to create, organize, and print checklists and task slips directly to thermal printers. 

> **Inspiration**: This project was inspired by [Laurie Hérault's article](https://www.laurieherault.com/articles/a-thermal-receipt-printer-cured-my-procrastination) about using thermal receipt printers to boost productivity and overcome procrastination through tangible task management.

## Features

- **Task Management**: Create, edit, and organize tasks with hierarchical subtask support
- **Cross-Platform**: Available on Windows, iOS, and Android
- **Thermal Printing**: Direct printing to USB and network thermal printers
- **Responsive Design**: Adaptive UI that works on desktop and mobile devices
- **Local Storage**: SQLite database for reliable offline task management
- **Modern UI**: Clean, intuitive interface with Material Design 3

## Printer Support

TaskWire supports ESC/POS thermal printers across different platforms with the following connectivity options:

| Platform | USB | Network | Bluetooth |
|----------|-----|---------|-----------|
| **Windows** | ✅ | ✅ | 🔄 Planned |
| **iOS** | ❌ | ✅ | 🔄 Planned |
| **Android** | ✅ | ✅ | 🔄 Planned |
| **macOS** | 🔄 Planned | 🔄 Planned | 🔄 Planned |

Most Epson ESC/POS should work, however, more testing is needed to confirm compatiblity with various thermal printers.

## Getting Started

**Prerequisites**
- Flutter SDK
- Dart SDK

```bash
git clone https://github.com/emerson000/taskwire.git
cd taskwire
flutter run
```
