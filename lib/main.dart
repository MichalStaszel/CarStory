import 'package:material_ui/material_ui.dart';

import 'app_services.dart';
import 'ui/library_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await AppServices.load();
  runApp(CarStoryApp(services: services));
}

class CarStoryApp extends StatelessWidget {
  const CarStoryApp({super.key, required this.services});
  final AppServices services;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Road Stories',
        debugShowCheckedModeBanner: false,
        theme: Noir.theme(),
        home: LibraryScreen(services: services),
      );
}
