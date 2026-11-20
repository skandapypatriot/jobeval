import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jobeval/app/router.dart';
import 'package:jobeval/app/theme.dart';
import 'package:jobeval/core/providers.dart';

class JobEvalApp extends ConsumerWidget {
  const JobEvalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'JobEval',
      debugShowCheckedModeBanner: false,
      theme: JobEvalTheme.lightTheme,
      darkTheme: JobEvalTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              MediaQuery.of(context).textScaler.scale(1.0).clamp(0.8, 1.3),
            ),
          ),
          child: child!,
        );
      },
    );
  }
}