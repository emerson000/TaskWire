import 'package:flutter/material.dart';
import 'pages/list_page.dart';
import 'package:taskwire/database/database.dart';
import 'package:get_it/get_it.dart';
import 'package:taskwire/pages/printer_settings_page.dart';
import 'package:taskwire/repositories/printer_repository.dart';
import 'package:taskwire/repositories/task_repository.dart';
import 'package:taskwire/services/task_manager.dart';
import 'package:taskwire/services/preference_service.dart';

final getIt = GetIt.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase();

  await db.close();
  final newDb = AppDatabase();

  getIt.registerSingleton<AppDatabase>(newDb);
  getIt.registerSingleton<TaskRepository>(TaskRepository(newDb));
  getIt.registerSingleton<TaskManager>(
    TaskManager(getIt.get<TaskRepository>()),
  );
  getIt.registerSingleton<PrinterRepository>(PrinterRepository(newDb));

  runApp(AppWrapper());
}

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final savedThemeMode = await PreferenceService.getThemeMode();
    setState(() {
      _themeMode = savedThemeMode;
      _isLoading = false;
    });
  }

  void toggleThemeMode() async {
    setState(() {
      final currentIndex = ThemeMode.values.indexOf(_themeMode);
      final nextIndex = (currentIndex + 1) % ThemeMode.values.length;
      _themeMode = ThemeMode.values[nextIndex];
    });
    await PreferenceService.saveThemeMode(_themeMode);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MyApp(themeMode: _themeMode, onThemeModeChanged: toggleThemeMode);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final VoidCallback onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    final currentThemeMode = themeMode;
    return MaterialApp(
      title: 'TaskWire',
      debugShowCheckedModeBanner: false,
      themeMode: currentThemeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        navigationDrawerTheme: NavigationDrawerThemeData(
          indicatorColor: Colors.deepPurple.withValues(alpha: 0.1),
          tileHeight: 56,
          indicatorShape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        navigationDrawerTheme: NavigationDrawerThemeData(
          indicatorColor: Colors.deepPurple.withValues(alpha: 0.1),
          tileHeight: 56,
          indicatorShape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
        ),
      ),
      home: MyHomePage(
        title: 'TaskWire',
        themeMode: currentThemeMode,
        onThemeModeChanged: onThemeModeChanged,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;
  final ThemeMode themeMode;
  final VoidCallback onThemeModeChanged;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const ListPage();
      case 1:
        return const PrinterSettingsPage();
      default:
        return const Center(child: Text('Unknown Page'));
    }
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 32),
              ListTile(
                leading: Icon(
                  Icons.list,
                  color: _selectedIndex == 0 ? Colors.deepPurple : null,
                ),
                title: Text(
                  'Tasks',
                  style: TextStyle(
                    color: _selectedIndex == 0 ? Colors.deepPurple : null,
                    fontWeight: _selectedIndex == 0 ? FontWeight.bold : null,
                  ),
                ),
                selected: _selectedIndex == 0,
                selectedTileColor: Colors.deepPurple.withValues(alpha: 0.1),
                onTap: () {
                  setState(() {
                    _selectedIndex = 0;
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.print,
                  color: _selectedIndex == 1 ? Colors.deepPurple : null,
                ),
                title: Text(
                  'Print Settings',
                  style: TextStyle(
                    color: _selectedIndex == 1 ? Colors.deepPurple : null,
                    fontWeight: _selectedIndex == 1 ? FontWeight.bold : null,
                  ),
                ),
                selected: _selectedIndex == 1,
                selectedTileColor: Colors.deepPurple.withValues(alpha: 0.1),
                onTap: () {
                  setState(() {
                    _selectedIndex = 1;
                  });
                  Navigator.pop(context);
                },
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: Icon(
                      widget.themeMode == ThemeMode.light
                          ? Icons.light_mode
                          : widget.themeMode == ThemeMode.dark
                          ? Icons.dark_mode
                          : Icons.brightness_auto,
                    ),
                    onPressed: () {
                      widget.onThemeModeChanged();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      body: _buildBody(),
    );
  }
}
