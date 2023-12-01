import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late SharedPreferences _appsettings;

  @override
  void initState() {
    super.initState();
    _loadAppSettings().then((value) {
      _setIsLogged(true);
      _getIsLogged().then((value) {
        Navigator.of(context).pushReplacementNamed('/webviewliriktv');
      });
    });
  }

  Future<void> _loadAppSettings() async {
    _appsettings = await SharedPreferences.getInstance();
  }

  Future<bool> _getIsLogged() async {
    return _appsettings.getBool('isLogged') ?? false;
  }

  Future<void> _setIsLogged(bool isLogged) async {
    _appsettings.setBool('isLogged', isLogged);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          Stack(
            children: [
              SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: Image.asset(
                    'assets/imagens/night.png',
                    fit: BoxFit.fill,
                  )),
              Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                color: Colors.black.withOpacity(0.7),
              ),
              Container(
                alignment: Alignment.center,
                height: 600,
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 30),
                          child: SizedBox(
                              width: 200,
                              height: 200,
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(200),
                                  child: Image.asset(
                                      'assets/imagens/lirik_logo_dark.png'))),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text(
                                "Lirik",
                                style: TextStyle(
                                  fontSize: 30,
                                ),
                              ),
                              Text(
                                ".TV",
                                style:
                                    TextStyle(fontSize: 30, color: Colors.blue),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 300.0,
                          child: Column(
                            children: [
                              // const TextField(
                              //   decoration: InputDecoration(
                              //       labelText: "Twitch username:",
                              //       border: OutlineInputBorder()),
                              // ),
                              // Container(
                              //   height: 20.0,
                              // ),
                              // const TextField(
                              //   obscureText: true,
                              //   decoration: InputDecoration(
                              //       labelText: "Twitch password:",
                              //       border: OutlineInputBorder()),
                              // ),
                              // Padding(
                              //   padding: const EdgeInsets.only(top: 10.0),
                              //   child: SizedBox(
                              //     width: double.infinity,
                              //     child: ElevatedButton.icon(
                              //       label: const Text("Login",
                              //           style: TextStyle(color: Colors.white)),
                              //       icon: const Icon(
                              //         Icons.login,
                              //         color: Colors.white,
                              //       ),
                              //       onPressed: () {
                              //         // Login

                              //       },
                              //     ),
                              //   ),
                              // ),
                              // const Padding(
                              //   padding: EdgeInsets.only(top: 8.0),
                              //   child: Text("Or"),
                              // )
                              // ,
                              Padding(
                                padding: const EdgeInsets.only(top: 10.0),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                      label: const Text("Login with WebView",
                                          style:
                                              TextStyle(color: Colors.white)),
                                      icon: const Icon(
                                        Icons.link,
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        Navigator.of(context)
                                            .pushReplacementNamed(
                                                '/webviewliriktv');
                                      }),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
