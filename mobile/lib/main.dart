import 'package:flutter/material.dart';
import 'services/crypto_service.dart';
import 'services/network_service.dart';
import 'services/storage_service.dart';
import 'screens/dashboard_screen.dart';
import 'theme/kiwi_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cryptoService = CryptoService();
  final storageService = StorageService(cryptoService);
  await storageService.init();
  final networkService = NetworkService(cryptoService, storageService);

  runApp(KiwiApp(networkService: networkService));
}

class KiwiApp extends StatelessWidget {
  final NetworkService networkService;

  const KiwiApp({super.key, required this.networkService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KIWI',
      debugShowCheckedModeBanner: false,
      theme: KiwiTheme.lightTheme,
      home: DashboardScreen(networkService: networkService),
    );
  }
}
