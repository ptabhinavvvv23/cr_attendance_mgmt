import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'data/repositories/repository_container.dart';
import 'data/repositories/repository_provider.dart';
import 'routes/app_routes.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = ThemeController();
  final repositoryContainer = RepositoryContainer.create();
  runApp(
    MyApp(
      themeController: themeController,
      repositoryContainer: repositoryContainer,
    ),
  );
}

class MyApp extends StatelessWidget {
  final ThemeController themeController;
  final RepositoryContainer repositoryContainer;

  MyApp({
    super.key,
    required this.themeController,
    RepositoryContainer? repositoryContainer,
  }) : repositoryContainer =
           repositoryContainer ?? RepositoryContainer.create();

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      container: repositoryContainer,
      child: ThemeControllerProvider(
        controller: themeController,
        child: AnimatedBuilder(
          animation: themeController,
          builder: (context, _) {
            return MaterialApp(
              title: 'CR Attendance Management',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeController.themeMode,
              initialRoute: AppRoutes.splash,
              onGenerateRoute: AppRoutes.onGenerateRoute,
            );
          },
        ),
      ),
    );
  }
}
