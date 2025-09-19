import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterquiz/app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final appFuture = initializeApp();
  runApp(
    ProviderScope(
      child: _BootstrapApp(appFuture: appFuture),
    ),
  );
}

class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp({required this.appFuture});
  final Future<Widget> appFuture;
  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        return _buildMainApp(snapshot.connectionState);
      },
    );
  }

  Widget _buildMainApp(ConnectionState authState) {
    return FutureBuilder<Widget>(
      future: widget.appFuture,
      builder: (context, appSnapshot) {
        final loading =
            authState == ConnectionState.waiting ||
            appSnapshot.connectionState != ConnectionState.done;
        if (loading) {
          return const CupertinoApp(
            debugShowCheckedModeBanner: false,
            home: _LoadingScreen(),
          );
        }
        return appSnapshot.data!;
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();
  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(),
      child: Center(child: CupertinoActivityIndicator()),
    );
  }
}
