
import 'package:flutter/material.dart';
import '../features/user/view/user_page.dart';
import '../features/navigator/view/navigator_page.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}
class MyApp extends StatelessWidget{
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AR Navigator',
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      
      appBar: AppBar(title: const Text('AR Navigator')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const UserPage())),
              child: const Text("User"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NavigatorPage())),
              child: const Text("Navigator"),
            ),
          ],
        ),
      ),
    );
  }
}
