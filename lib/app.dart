import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:talker_bloc_logger/talker_bloc_logger.dart';
import 'core/constants/app_strings.dart';
import 'core/logger/app_logger.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/local_database.dart';
import 'data/repositories/clipboard_repository_impl.dart';
import 'domain/repositories/clipboard_repository.dart';
import 'presentation/bloc/clipboard/clipboard_bloc.dart';
import 'presentation/bloc/settings/settings_bloc.dart';
import 'presentation/screens/bookmarks_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/settings_screen.dart';

class SniptApp extends StatelessWidget {
  const SniptApp({super.key});

  @override
  Widget build(BuildContext context) {
    Bloc.observer = TalkerBlocObserver(talker: talker);

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<LocalDatabase>(
          create: (_) => LocalDatabase(),
        ),
        RepositoryProvider<ClipboardRepository>(
          create: (context) => ClipboardRepositoryImpl(
            context.read<LocalDatabase>(),
          ),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ClipboardBloc>(
            create: (context) => ClipboardBloc(
              context.read<ClipboardRepository>(),
            ),
          ),
          BlocProvider<SettingsBloc>(
            create: (_) => SettingsBloc(),
          ),
        ],
        child: MaterialApp(
          title: AppStrings.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: const MainScreen(),
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    BookmarksScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: AppStrings.recent,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark),
            label: AppStrings.bookmarks,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: AppStrings.settings,
          ),
        ],
      ),
    );
  }
}
