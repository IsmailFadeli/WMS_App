import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart'; // Generated by flutterfire configure
import 'src/routing/app_router.dart'; // Import the router provider

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter bindings are ready
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Use generated options
  );
  runApp(
    // Wrap the entire app in a ProviderScope for Riverpod state management
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

// Use ConsumerWidget to access Riverpod providers
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the goRouterProvider to get the router configuration
    final goRouter = ref.watch(goRouterProvider);

    // Use MaterialApp.router to integrate go_router
    return MaterialApp.router(
      title: 'Warehouse Management',
      theme: ThemeData(
        // Define a consistent color scheme
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true, // Enable Material 3 design
        // Customize input decoration for text fields globally
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
             borderRadius: BorderRadius.all(Radius.circular(8.0)),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        ),
        // Customize elevated button style globally
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
             shape: RoundedRectangleBorder(
               borderRadius: BorderRadius.circular(8.0),
             ),
             padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          ),
        ),
      ),
      // Provide the router configuration to MaterialApp.router
      routerConfig: goRouter,
      debugShowCheckedModeBanner: false, // Hide the debug banner
    );
  }
}
