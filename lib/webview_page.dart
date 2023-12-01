import 'dart:collection';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:liriktv/vod_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';
import 'package:timeago/timeago.dart' as timeago;

class WebViewLirikTv extends StatefulWidget {
  const WebViewLirikTv({Key? key}) : super(key: key);

  @override
  State<WebViewLirikTv> createState() => _WebViewLirikTvState();
}

class _WebViewLirikTvState extends State<WebViewLirikTv> {
  late SharedPreferences _appsettings;

  String sLastVodProgress = '';
  String sLastVod = '';

  String sWebViewUrl = '';

  late WebViewController _controller;
  bool bVisibilityWebview = false;
  bool bVisibilityLoadingPage = true;
  bool bFistLoadedCards = false;
  bool bVisibilityLoadingCards = false;

  late bool? isLogged;

  int _selectedIndex = 0;
  int iWebViewScrollIndex = 0;
  int iAppViewScrollIndex = 0;

  final List<Widget> _cardList = [];
  final _scrollController = ScrollController();

  void addNewCard(
    String sVodTitle,
    sVodUrl,
    sRecordedAt,
    sYoutubeUrl,
    sYoutubeThumb,
    Duration dVodDuration,
    SplayTreeMap<int, Map<String, String>> mChapters,
  ) {
    setState(() {
      _cardList.add(_card(sVodTitle, sVodUrl, sRecordedAt, sYoutubeUrl,
          sYoutubeThumb, dVodDuration, mChapters));
    });
  }

  Duration parseDuration(String s) {
    int hours = 0;
    int minutes = 0;
    int micros;
    List<String> parts = s.split(':');
    if (parts.length > 2) {
      hours = int.parse(parts[parts.length - 3]);
    }
    if (parts.length > 1) {
      minutes = int.parse(parts[parts.length - 2]);
    }
    micros = (double.parse(parts[parts.length - 1]) * 1000000).round();
    return Duration(hours: hours, minutes: minutes, microseconds: micros);
  }

  @override
  void initState() {
    _loadSettings();

    super.initState();
    if (Platform.isAndroid) WebView.platform = AndroidWebView();

    _scrollController.addListener(infiniteScrolling);
  }

  _loadSettings() async {
    _appsettings = await SharedPreferences.getInstance();

    isLogged = _appsettings.getBool('isLogged') ?? false;
    String sVodProgressAt = _appsettings.getString('VodProgressAt') ?? '';
    if (sVodProgressAt.isNotEmpty) {
      setState(() {
        sLastVod = sVodProgressAt.split('||')[0];
        sLastVodProgress =
            Duration(seconds: int.parse(sVodProgressAt.split('||')[1]))
                .toString();
      });
    }
  }

  _updateLastVodProgress() async {
    String sVodProgressAt = _appsettings.getString('VodProgressAt') ?? '';
    if (sVodProgressAt.isNotEmpty) {
      setState(() {
        sLastVod = sVodProgressAt.split('||')[0];
        sLastVodProgress =
            Duration(seconds: int.parse(sVodProgressAt.split('||')[1]))
                .toString();
      });
    }
  }

  _setIsLogged(bool isLogged) async {
    await _appsettings.setBool('isLogged', isLogged);
    _getIsLogged();
  }

  _setAuthKey(String sAuthKey) async {
    await _appsettings.setString('AuthKey', sAuthKey);
  }

  _getAuthKey() {
    return _appsettings.getString('AuthKey')??'';
  }

  Future<bool?> _getIsLogged() async {
    isLogged = _appsettings.getBool('isLogged');
    return isLogged;
  }

  infiniteScrolling() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !bVisibilityLoadingCards) {
      setState(() {
        bVisibilityLoadingCards = true;
      });
      getAPICards().then((value) {
        if (!value) {
          setState(() {
            _setIsLogged(false);
            bVisibilityWebview = true;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const TextStyle optionStyle =
        TextStyle(fontSize: 30, fontWeight: FontWeight.bold);

    return Scaffold(
      bottomNavigationBar: !bVisibilityWebview
          ? BottomNavigationBar(
              type: BottomNavigationBarType.shifting,
              unselectedItemColor: const Color.fromARGB(255, 228, 228, 228),
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                    icon: Icon(Icons.sports_esports),
                    label: 'Vods',
                    backgroundColor: Color(0xFF00CCFF)),
                BottomNavigationBarItem(
                    icon: Icon(Icons.star),
                    label: 'Favorite vods',
                    backgroundColor: Color(0xFF00CCFF)),
                BottomNavigationBarItem(
                    icon: Icon(Icons.slow_motion_video),
                    label: 'Favorite moments',
                    backgroundColor: Color(0xFF00CCFF)),
                BottomNavigationBarItem(
                    icon: Icon(Icons.settings),
                    label: 'Settings',
                    backgroundColor: Color(0xFF00CCFF)),
              ],
              currentIndex: _selectedIndex,
              selectedItemColor: Colors.black,
              onTap: (index) {
                if (index == 0) {
                  if (_scrollController.position.pixels ==
                          _scrollController.position.minScrollExtent &&
                      !bVisibilityLoadingCards) {
                    _updateLastVodProgress();
                    _cardList.clear();
                    setState(() {
                      bVisibilityLoadingCards = true;
                      iWebViewScrollIndex = 0;
                      bFistLoadedCards = true;
                    });
                    getAPICards().then((value) {
                      if (!value) {
                        setState(() {
                          _setIsLogged(false);
                          bVisibilityWebview = true;
                        });
                      }
                    });
                  }
                }
                if (index == _selectedIndex && _selectedIndex == 0) {
                  _scrollController.animateTo(
                      _scrollController.position.minScrollExtent,
                      duration: const Duration(seconds: 2),
                      curve: Curves.fastOutSlowIn);
                }
                setState(() {
                  _selectedIndex = index;
                });
              },
            )
          : null,
      appBar: !bVisibilityWebview
          ? AppBar(
              actions: [
                IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
                Container(
                  width: 20,
                ),
              ],
              backgroundColor: const Color(0xFF00CCFF),
              title: Builder(
                builder: (context) {
                  return Row(
                    children: const [
                      Text(
                        "Lirik",
                        style: TextStyle(fontSize: 25, color: Colors.white),
                      ),
                      Text(
                        ".TV",
                        style: TextStyle(fontSize: 15, color: Colors.white),
                      ),
                    ],
                  );
                },
              ),
              flexibleSpace: Stack(
                children: [
                  const Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 300,
                      child: Image(
                        image:
                            AssetImage('assets/imagens/lirik_logo_dark2.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Container(
                    color: const Color.fromARGB(17, 0, 13, 29),
                  ),
                ],
              ),
            )
          : null,
      body: Stack(children: [
        Visibility(
          visible: _selectedIndex == 0 ? true : false,
          maintainState: true,
          child: Stack(
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: Container(
                  color: const Color(0xFF0d0d10),
                  child: Center(
                      child: Stack(children: [
                    Center(
                      child: bVisibilityLoadingPage
                          ? const CircularProgressIndicator(
                              semanticsLabel: 'Linear progress indicator',
                            )
                          : Container(),
                    ),
                    Scrollbar(
                      child: ListView.builder(
                          key: const PageStorageKey(0),
                          controller: _scrollController,
                          itemCount: _cardList.length,
                          itemBuilder: (context, index) {
                            return _cardList[index];
                          }),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: bVisibilityLoadingCards
                            ? const CircularProgressIndicator(
                                semanticsLabel: 'Linear progress indicator',
                              )
                            : null,
                      ),
                    )
                  ])),
                ),
              ),
            ],
          ),
        ),
        Visibility(
          visible: _selectedIndex == 1 ? true : false,
          maintainState: true,
          child: const Text(
            'Index 2',
            style: optionStyle,
          ),
        ),
        Visibility(
          visible: _selectedIndex == 2 ? true : false,
          maintainState: true,
          child: const Text(
            'Index 3',
            style: optionStyle,
          ),
        ),
        Visibility(
          visible: _selectedIndex == 3 ? true : false,
          maintainState: true,
          child: const Text(
            'Index 4',
            style: optionStyle,
          ),
        ),
        SizedBox(
          height: MediaQuery.of(context).size.height,
          child: Visibility(
            visible: bVisibilityWebview,
            maintainState: true,
            child: WebView(
                initialUrl: 'https://lirik.tv',
                javascriptMode: JavascriptMode.unrestricted,
                onWebViewCreated: (WebViewController webViewController) {
                  _controller = webViewController;
                  //_controller.clearCache();
                  // _setAuthKey('');
                  // _setIsLogged(false);
                  String authkey = _getAuthKey()??'';

                  print("Auth: $authkey");
                  print('IsLogged: $isLogged');
                },
                javascriptChannels: <JavascriptChannel>{
                  _extractDataJSChannel(context),
                },
                navigationDelegate: (NavigationRequest request) {
                  if (request.url
                      .startsWith('https://lirik.tv/login/auth?code=')) {
                    String sCode = request.url.substring(
                        request.url.indexOf('code=') + 5,
                        request.url.indexOf('&'));

                    postAPIAuth(sCode).then(
                      (response) {
                        setState(() {
                          bVisibilityWebview = false;
                          bVisibilityLoadingPage = false;
                        });

                        dynamic dyResponse = json.decode(response!);
                        String sBearer = 'Bearer ${dyResponse['jwt']}';

                        _setAuthKey(sBearer);
                        _setIsLogged(true);
                        _controller.loadUrl('https://lirik.tv/');
                      },
                    );
                    return NavigationDecision.prevent;
                  }
                  return NavigationDecision.navigate;
                },
                onPageStarted: (String url) {
                  if (url == 'https://lirik.tv/' && isLogged!) {
                    getAPICards().then((value) {
                      print('GetCards result: $value');
                      if (value == false) {
                        setState(() {
                          _setIsLogged(false);
                          bVisibilityWebview = true;
                        });
                      } else {
                        setState(() {
                          bVisibilityLoadingPage = false;
                        });
                      }
                    });
                  } else if (url == 'https://lirik.tv/' && !isLogged!) {
                    setState(() {
                      bVisibilityWebview = true;
                    });
                  }
                },
                onPageFinished: (String url) {}),
          ),
        ),
      ]),
    );
  }

//   void getJSAuth() async {
//     await _controller.runJavascriptReturningResult("""
// var req = new XMLHttpRequest();
// req.open('GET', document.location, false);
// req.send(null);
// var headers = req.getAllResponseHeaders().toLowerCase();
// headers;
// """).then((value) {
//       print(value);
//     });
//   }

  // void getUrlFromVod(int vodid) async {
  //   String youtubeurl = "";
  //   String vodurl = "";
  //   _controller
  //       .runJavascriptReturningResult(
  //           'window.document.getElementsByClassName("card-info")[$vodid].childNodes[0].click();')
  //       .then((value) {
  //     Future.delayed(const Duration(seconds: 1), () async {
  //       youtubeurl = await _controller.runJavascriptReturningResult(
  //           'window.document.getElementsByTagName("iframe")[0].src;');
  //       vodurl = await _controller
  //           .runJavascriptReturningResult('window.location.href;');
  //       pushVodPage(
  //           vodid, youtubeurl.replaceAll('"', ''), vodurl.replaceAll('"', ''));
  //     });
  //   });
  // }

  // void pushVodPage(int vodid, String youtubeurl, vodurl) {
  //   Navigator.of(context)
  //       .push(MaterialPageRoute(
  //           builder: (context) => VodPage(
  //                 youtubeurl: youtubeurl,
  //                 vodurl: vodurl,
  //                 werbview: _controller,
  //               )))
  //       .then((value) {
  //     _controller.runJavascriptReturningResult('window.history.go(-1);');
  //     iWebViewScrollIndex = 0;
  //     setState(() {
  //       _cardList.clear();

  //       bVisibilityLoadingCards = true;
  //       bFistLoadedCards = false;
  //     });
  //     //getcardsinfos();
  //   });
  // }

  Future<String?> postAPIAuth(String sCode) async {
    Response response;
    Map data = {'code': sCode};
    var body = json.encode(data);

    try {
      response = await post(Uri.parse('https://lirik.tv/api/auth'),
          headers: {
            "Content-Type": "application/json",
          },
          body: body);
    } catch (indentifer) {
      return null;
    }

    return response.body;
  }

  Future<bool> getAPICards() async {
    String authkey = _getAuthKey();

    int offset = iWebViewScrollIndex * 16;
    int take = 16;
    Response response;
    if (authkey == '') {
      log('Error: authkey empty');
      return false;
    }
    try {
      response = await get(
          Uri.parse(
              'https://lirik.tv/api/video/channel/ab4b0664-00c0-4624-b603-7ea1da2ff084?data=true&offset=$offset&take=$take'),
          headers: {'Authorization': authkey});
    } catch (identifer) {
      log('Error: $identifer');
      return false;
    }

    if (response.body.contains('Unauthorized')) {
      log(response.body);
      return false;
    }

    final cardsJson = json.decode(response.body);
    for (var card in cardsJson) {
      String sVodTitle = card['data']['title'];
      String sVodUrl = 'https://lirik.tv/vod/${card['guid']}';
      String sYoutubeUrl =
          'https://www.youtube.com/watch?v=${card['youTubeId']}';
      String? sYoutubeThumb = card['youTubeId'] == null
          ? null
          : 'https://img.youtube.com/vi/${card['youTubeId']}/0.jpg';
      Duration dVodDuration = Duration(seconds: card['data']['lengthSeconds']);
      String sRecordedAt = card['data']['recordedAt'];

      SplayTreeMap<int, Map<String, String>> mChapters =
          SplayTreeMap<int, Map<String, String>>();
      int iKeyCount = 0;
      for (var chapter in card['games']) {
        for (var item in mChapters.entries) {
          if (iKeyCount > 0) {
            if ('${item.value.keys.first} $iKeyCount' ==
                chapter['game']['name'] + ' ' + iKeyCount.toString()) {
              iKeyCount++;
            }
          } else {
            if (item.value.keys.first == chapter['game']['name']) {
              iKeyCount++;
            }
          }
        }
        if (iKeyCount > 0) {
          mChapters[chapter['positionMilliseconds']] = {
            chapter['game']['name'] + ' ' + iKeyCount.toString():
                chapter['game']['boxArtUrl']
          };
        } else {
          mChapters[chapter['positionMilliseconds']] = {
            chapter['game']['name']: chapter['game']['boxArtUrl']
          };
        }
      }

      addNewCard(sVodTitle, sVodUrl, sRecordedAt, sYoutubeUrl, sYoutubeThumb,
          dVodDuration, mChapters);
    }
    bVisibilityLoadingCards = false;

    iWebViewScrollIndex++;
    return true;
  }

  JavascriptChannel _extractDataJSChannel(BuildContext context) {
    return JavascriptChannel(
      name: 'Flutter',
      onMessageReceived: (JavascriptMessage message) {},
    );
  }

  Widget _card(
    String sVodTitle,
    sVodUrl,
    sRecordedAt,
    sYoutubeUrl,
    sYoutubeThumb,
    Duration dVodDuration,
    SplayTreeMap<int, Map<String, String>> mChapters,
  ) {
    return Center(
      child: Card(
        child: SizedBox(
          width: 400,
          height: 175,
          child: Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  if (sYoutubeThumb != null) {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => VodPage(
                              youtubeurl: sYoutubeUrl,
                              vodurl: sVodUrl,
                              werbview: _controller,
                              startAt: Duration.zero,
                              appsettings: _appsettings,
                            )));
                  }
                },
                child: SizedBox(
                  width: 400,
                  child: Image.network(
                      sYoutubeThumb ??
                          'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTqXJajTxMv2BV0YOQutYSI0bjqdTw2NldawA&usqp=CAU',
                      fit: BoxFit.cover),
                ),
              ),
              Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 160,
                  height: double.infinity,
                  child: Container(
                    color: const Color.fromARGB(72, 0, 0, 0),
                    child: Column(
                      children: [
                        const Padding(padding: EdgeInsets.all(5.0)),
                        SizedBox(
                          child: GestureDetector(
                            onTap: (){
                              _setAuthKey('Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJuYW1laWQiOiIxNmQwN2U2Yi1jNGUyLTQ1OGEtOWFkZS1jMTEzMDkxYTlmN2UiLCJuYW1lIjoiaUZ1enppbmciLCJuYmYiOjE2NTcyODg5MjMsImV4cCI6MTY1NzU0ODE4MywiaWF0IjoxNjU3Mjg4OTgzLCJpc3MiOiJodHRwczovL2xpcmlrLnR2In0.hpPonwzO6gomMSfCXv1ah-Zi4KaZHLwdQ0ebF9YaJB-MX3BeMK5vr-caWrb7V1_g6iUJwHOUcAySV-L8XrYM3Y');
                            },
                            child: Text(
                              sVodTitle.length > 20
                                  ? '${sVodTitle.substring(0, 20)}...'
                                  : sVodTitle,
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ),
                        const Padding(padding: EdgeInsets.all(5.0)),
                        SizedBox(
                          width: 145,
                          height: 110,
                          child: Container(
                              color: const Color.fromARGB(104, 0, 204, 255),
                              child: ListView.builder(
                                key: const PageStorageKey(0),
                                itemCount: mChapters.entries.length,
                                itemBuilder: (context, index) {
                                  MapEntry<int, Map<String, String>> mChap =
                                      mChapters.entries.toList()[index];
                                  String sChapTitle = mChap.value.keys.first;
                                  String sChapSrc = mChap.value.values.first;

                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.of(context)
                                          .push(MaterialPageRoute(
                                              builder: (context) => VodPage(
                                                    youtubeurl: sYoutubeUrl,
                                                    vodurl: sVodUrl,
                                                    werbview: _controller,
                                                    startAt: Duration(
                                                        milliseconds:
                                                            mChap.key),
                                                    appsettings: _appsettings,
                                                  )));
                                    },
                                    child: Card(
                                      color:
                                          const Color.fromARGB(209, 19, 19, 19),
                                      child: Row(children: [
                                        SizedBox(
                                            width: 30,
                                            height: 40,
                                            child: Image.network(
                                              sChapSrc,
                                              fit: BoxFit.cover,
                                            )),
                                        const Padding(
                                            padding: EdgeInsets.all(5.0)),
                                        Text(
                                          sChapTitle.length > 13
                                              ? '${sChapTitle.substring(0, 10)}...'
                                              : sChapTitle,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ]),
                                    ),
                                  );
                                },
                              )),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(!timeago
                                    .format(DateTime.parse(sRecordedAt))
                                    .contains('day') &&
                                !timeago
                                    .format(DateTime.parse(sRecordedAt))
                                    .contains('hour')
                            ? sRecordedAt
                            : timeago.format(DateTime.parse(sRecordedAt))),
                      )),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            sLastVod == sVodUrl
                                ? Container(
                                    color: const Color.fromARGB(82, 0, 0, 0),
                                    child: Padding(
                                      padding: const EdgeInsets.all(5.0),
                                      child: Text(sLastVodProgress.replaceAll(
                                          '.000000', '')),
                                    ))
                                : const SizedBox(),
                            Container(
                              width: 5,
                            ),
                            Container(
                              color: const Color.fromARGB(82, 0, 0, 0),
                              child: Padding(
                                padding: const EdgeInsets.all(5.0),
                                child: Text(dVodDuration
                                    .toString()
                                    .replaceAll('.000000', '')),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: sLastVod == sVodUrl
                    ? LinearProgressIndicator(
                        value: sLastVod == sVodUrl && sLastVod.isNotEmpty
                            ? (parseDuration(sLastVodProgress).inSeconds /
                                    dVodDuration.inSeconds)
                                .toDouble()
                            : 0.0,
                        semanticsLabel: 'Linear progress indicator',
                      )
                    : const SizedBox(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
