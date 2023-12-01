import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liriktv/login_page.dart';
import 'package:liriktv/webview_page.dart';

class MainLirikTv extends StatelessWidget {
  const MainLirikTv({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {    
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [
      //SystemUiOverlay.top
    ]);
    return MaterialApp(
      //debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/webviewliriktv': (context) => const WebViewLirikTv(),
        //'/vodpage':(context) => VodPage(url: 'https://www.youtube.com/watch?v=IcIvQjeyBX8',),
      },
    );
  }
}
