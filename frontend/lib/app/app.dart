import 'package:flutter/material.dart';
import 'package:jobeval/app/router.dart';
import 'package:jobeval/app/theme.dart';

class JobEvalApp extends StatelessWidget {
  const JobEvalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'JobEval',
      debugShowCheckedModeBanner: false,
      theme: JobEvalTheme.light,
      darkTheme: JobEvalTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.35,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
