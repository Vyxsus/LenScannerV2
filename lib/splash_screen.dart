import 'dart:async';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget{
  const SplashScreen ({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState(); 
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin{
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent : _controller, curve: Curves.easeIn);

    _controller.forward();
    
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacementNamed('/home');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: FadeTransition(
              opacity: _animation,
              child: Text(
                "LensScanner",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[900],
                ),
              ),
            ),
          ),
          const Positioned(
            bottom: 20,
            right: 20,
            child: Text(
              "v 1.0",
              style: TextStyle(fontSize: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}