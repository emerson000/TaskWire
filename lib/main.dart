import 'package:flutter/material.dart';
import 'pages/list_page.dart';
import 'package:taskwire/database/database.dart';
import 'package:get_it/get_it.dart';
import 'package:taskwire/pages/printer_settings_page.dart';
import 'package:taskwire/repositories/printer_repository.dart';
import 'package:taskwire/repositories/task_repository.dart';
import 'package:taskwire/services/task_manager.dart';

final getIt = GetIt.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase();

  // Ensure database is properly initialized
  await db.close();
  final newDb = AppDatabase();

  getIt.registerSingleton<AppDatabase>(newDb);
  getIt.registerSingleton<TaskRepository>(TaskRepository(newDb));
  getIt.registerSingleton<TaskManager>(
    TaskManager(getIt.get<TaskRepository>()),
  );
  getIt.registerSingleton<PrinterRepository>(PrinterRepository(newDb));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskWire',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        navigationDrawerTheme: NavigationDrawerThemeData(
          indicatorColor: Colors.deepPurple.withOpacity(0.1),
          tileHeight: 56,
          indicatorShape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
        ),
      ),
      home: const MyHomePage(title: 'TaskWire'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  int _selectedIndex = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text('You have pushed the button this many times:'),
              Text(
                '$_counter',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        );
      case 1:
        return const ListPage();
      case 2:
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
      drawer: NavigationDrawer(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
          Navigator.pop(context);
        },
        children: [
          NavigationDrawerDestination(
            icon: Icon(
              Icons.home,
              color: _selectedIndex == 0 ? Colors.deepPurple : null,
            ),
            label: Text(
              'Home',
              style: TextStyle(
                color: _selectedIndex == 0 ? Colors.deepPurple : null,
              ),
            ),
          ),
          NavigationDrawerDestination(
            icon: Icon(
              Icons.list,
              color: _selectedIndex == 1 ? Colors.deepPurple : null,
            ),
            label: Text(
              'Lists',
              style: TextStyle(
                color: _selectedIndex == 1 ? Colors.deepPurple : null,
              ),
            ),
          ),
          NavigationDrawerDestination(
            icon: Icon(
              Icons.print,
              color: _selectedIndex == 2 ? Colors.deepPurple : null,
            ),
            label: Text(
              'Print Settings',
              style: TextStyle(
                color: _selectedIndex == 2 ? Colors.deepPurple : null,
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: _incrementCounter,
              tooltip: 'Increment',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
