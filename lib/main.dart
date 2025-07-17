import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import "services/auth_service.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://dnzyanqetjiaqonvbxlt.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRuenlhbnFldGppYXFvbnZieGx0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDg0NTkyNDksImV4cCI6MjA2NDAzNTI0OX0.qC--HY4ccGNQ1rw0RFl61-6iSeuubGjGiT_gdsEx0X0',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'To-Do App',
      theme: ThemeData(primarySwatch: Colors.green),
      home: AuthGate(),
    );
  }
}
