import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:workout_analyzer/screens/capture/photo_capture_screen.dart';
import 'package:workout_analyzer/screens/controllers/capture_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Welcome ${FirebaseAuth.instance.currentUser!.displayName!}"),
        actions: [
          IconButton(onPressed: () async{
            await GoogleSignIn().signOut();
            FirebaseAuth.instance.signOut();
          }, icon: Icon(Icons.power_settings_new))
        ],
      ),
      body: SafeArea(child: ElevatedButton(
          onPressed: () async{
            CaptureController();
          },
          child: Text("Capture Image"),
        )
      ),
    );
  }
}
