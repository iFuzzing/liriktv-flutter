import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';

class VodPage extends StatefulWidget {
  const VodPage({
    Key? key,
    required this.youtubeurl,
    required this.vodurl,
    required this.werbview,
    required this.startAt,
    required this.appsettings,
  }) : super(key: key);

  final String youtubeurl;
  final String vodurl;
  final WebViewController werbview;
  final Duration startAt;
  final SharedPreferences appsettings;

  @override
  State<VodPage> createState() => _VodPageState();
}

class _VodPageState extends State<VodPage> {
  late YoutubePlayerController _ytControler;
  bool isVideoPlaying = false;
  bool isProgressBarClicked = false;
  bool isSliderVisi = false;
  bool isSliderChanging = false;

  bool isChatAutoScrolling = true;
  late bool isFullScreen;

  late Timer tChatHandling;
  late Duration dVideoPostion;
  late Duration dVodProgressAt;
  Duration startAtChange = Duration.zero;

  Duration dPrevVideoPosition = const Duration(seconds: 0);
  Duration dNextChatPosition = const Duration(seconds: 10);

  dynamic jsonBttvEmotes;
  dynamic jsonFzzEmotes;
  dynamic jsonLirikBadges;

  final ScrollController _scrollController = ScrollController();

  final List<Widget> lwchat = [];

  Map<String, String> emoteSrc = {};
  Map<String, String> badgeSrc = {};

  @override
  void deactivate() {
    _ytControler.pause();

    super.deactivate();
  }

  @override
  void dispose() {
    super.dispose();
    tChatHandling.cancel();
  }

  Future<void> setProgressAt(Duration dProgressAt) async {
    widget.appsettings.setString('VodProgressAt',
        '${widget.vodurl}||${dProgressAt.inSeconds.toString()}');
  }

  Future<String?> getProgressAt() async {
    return widget.appsettings.getString('VodProgressAt');
  }


  getAuthKey(){
    return widget.appsettings.getString('AuthKey')??'';
  }

  Future<void> loadJsonData() async {
    // FZZ LIRIK
    rootBundle.loadString('assets/sources/ffz_lirik_emotes.json').then((value) {
      setState(() => jsonFzzEmotes = json.decode(value));
      for (var emote in jsonFzzEmotes['sets']['135169']['emoticons']) {
        if (!emoteSrc.containsKey(emote['name'])) {
          emoteSrc[emote['name']] =
              'https://cdn.frankerfacez.com/emote/${emote['id'].toString()}/1';
        }
      }
    });

    // BTTV
    rootBundle
        .loadString('assets/sources/bttv_emotes.json')
        .then((value) => setState(() {
              jsonBttvEmotes = json.decode(value);
              for (var emote in jsonBttvEmotes['channelEmotes']) {
                if (!emoteSrc.containsKey(emote['code'])) {
                  emoteSrc[emote['code']] =
                      'https://cdn.betterttv.net/emote/${emote['id']}/1x';
                }
              }

              for (var emote in jsonBttvEmotes['sharedEmotes']) {
                if (!emoteSrc.containsKey(emote['code'])) {
                  emoteSrc[emote['code']] =
                      'https://cdn.betterttv.net/emote/${emote['id']}/1x';
                }
              }
            }));

    // FZZ
    rootBundle.loadString('assets/sources/fzz_emotes.json').then((value) {
      setState(() => jsonFzzEmotes = json.decode(value));
      for (var emote in jsonFzzEmotes['sets']['355397']['emoticons']) {
        if (!emoteSrc.containsKey(emote['name'])) {
          emoteSrc[emote['name']] =
              'https://cdn.frankerfacez.com/emote/${emote['id'].toString()}/1';
        }
      }
    });

    // LIRIK BADGES
    rootBundle.loadString('assets/sources/lirik_badges.json').then((value) {
      setState(() {
        jsonLirikBadges = json.decode(value);
        Map<String, dynamic> mBadgesSets = json.decode(value);
        Map<String, dynamic> mSubscriber = mBadgesSets.values.first;
        Map<String, dynamic> mVersions = mSubscriber.values.last;
        for (var version in mVersions.entries) {
          Map<String, dynamic> mVersion = version.value;
          for (var mVersionValue in mVersion.entries) {
            Map<String, dynamic> mSrc = mVersionValue.value;
            int x = 0;
            for (var src in mSrc.entries) {
              if (x == 1) {
                badgeSrc[mVersionValue.key] = src.value;
                break;
              }
              x++;
            }
          }
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();

    _ytControler = YoutubePlayerController(
      initialVideoId:
          YoutubePlayerController.convertUrlToId(widget.youtubeurl)!,
      params: YoutubePlayerParams(
        autoPlay: true,
        mute: false,
        loop: false,
        strictRelatedVideos: false,
        privacyEnhanced: true,
        startAt: widget.startAt,
      ),
    );

    getProgressAt().then((sProgressAt) {
      if (sProgressAt != null) {
        String sVodUrlFromSettings = sProgressAt.split('||')[0];
        String sVodProgress = sProgressAt.split('||')[1];

        if (sVodUrlFromSettings == widget.vodurl) {
          setState(() {
            startAtChange = Duration(seconds: int.parse(sVodProgress));
          });
        }
      }
    });

    setState(() {
      isFullScreen = false;
    });

    tChatHandling = Timer.periodic(const Duration(seconds: 5), ((timer) {}));
    loadJsonData();
  }

  void addChatMessage(List<Widget> lWidgetBadges, String username,
      List<Widget> lWidgetsMessage, String userColor) {
    if (isChatAutoScrolling) {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent,
          duration: const Duration(seconds: 1), curve: Curves.fastOutSlowIn);
    }

    setState(() {
      lwchat.add(
          chatMessage(lWidgetBadges, username, lWidgetsMessage, userColor));
    });
  }

  Future<void> chatHandling(chatJson) async {
    List<String> offsetsBuf = [''];
    tChatHandling = Timer.periodic(const Duration(seconds: 1), (tChatHandling) {
      if (dVideoPostion <= dNextChatPosition && isVideoPlaying) {
        for (var user in chatJson) {
          if (int.parse(user['offset'].toString().split('.')[0]) <=
                  dVideoPostion.inSeconds &&
              !offsetsBuf.any((String value) =>
                  value.contains(user['offset'].toString()))) {
            String usercolor = "#FFFFFF";
            String userMessage = user['body'].toString();
            if (user['data']['userColor'] != null) {
              usercolor = user['data']['userColor'].toString();
            }

            for (var emote in emoteSrc.keys) {
              userMessage =
                  userMessage.replaceAll(' $emote ', ' :|:$emote:|: ');
            }

            if (!userMessage.contains(':|:')) {
              userMessage = '$userMessage:|:';
            }

            List<String> usrMessageSplited = userMessage.split(':|:');
            List<Widget> lWidgetsMessage = [];
            List<Widget> lWidgetBadges = [];

            for (var split in usrMessageSplited) {
              bool isEmote = false;
              for (var emote in emoteSrc.keys) {
                if (split == emote) {
                  lWidgetsMessage.add(SizedBox(
                      width: 30,
                      height: 30,
                      child: Image.network(emoteSrc[emote].toString())));
                  isEmote = true;
                }
              }
              if (!isEmote) {
                lWidgetsMessage.add(Text(split));
              }
            }

            for (var badgechat in user['badges']) {
              if (badgechat['id'] == 'subscriber') {
                var badge = badgeSrc.entries.firstWhere(
                    (element) => element.key == badgechat['version']);
                if (badge.value.isNotEmpty) {
                  lWidgetBadges.add(SizedBox(
                      width: 20,
                      height: 20,
                      child: Image.network(badge.value)));
                }
              }
            }

            addChatMessage(lWidgetBadges, user['commenter']['displayName'],
                lWidgetsMessage, usercolor.replaceAll('#', ''));
            offsetsBuf.add(user['offset'].toString());
          }
        }
      }
    });
  }

  Widget chatMessage(List<Widget> lWidgetBadges, String username,
      List<Widget> lWidgetsMessage, usrcolor) {
    String hexcolor = '0xFF$usrcolor';
    return Wrap(
      children: [
        Container(
          height: 10,
        ),
        // Image.network('https://cdn.frankerfacez.com/emote/381875/1'),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: lWidgetBadges)),
        Container(
          width: 2,
        ),
        Text(
          '$username: ',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: Color(int.parse(hexcolor))),
        ),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: lWidgetsMessage))
      ],
    );
  }

  // Future<String> getVodChat(int start, int end) async {
  //   String sChat = await widget.werbview.runJavascriptReturningResult("""
  //     var url = "https://lirik.tv/api/chat/video/adfd8712-830e-4404-9459-f00e70c009fc?start=$start&end=$end";
  //     var result = "";

  //     var xhr = new XMLHttpRequest();
  //     xhr.open("GET", url, false);

  //     xhr.setRequestHeader("Authorization", "Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJuYW1laWQiOiIxNmQwN2U2Yi1jNGUyLTQ1OGEtOWFkZS1jMTEzMDkxYTlmN2UiLCJuYW1lIjoiaUZ1enppbmciLCJuYmYiOjE2NTY3NjI5NzUsImV4cCI6MTY1NzAyMjIzNSwiaWF0IjoxNjU2NzYzMDM1LCJpc3MiOiJodHRwczovL2xpcmlrLnR2In0.SLZuV_Q6GLNCoTbNlW8RZEYe-MAB9HfSqYcnTaW3JSivNZw4t-4XKjrDhrST-EgZoicr9cJqLKg37chkDenZAg");

  //     xhr.onreadystatechange = function () {
  //       if (xhr.readyState === 4) {
  //           console.log(xhr.response);
  //           result = xhr.response;
  //       }};
  //     xhr.send();
  //     result;
  //     """);
  //   return sChat.substring(1, sChat.length - 1).replaceAll('\\"', '"');
  // }

  Future<String> getAPIVodChat(int start, int end) async {
    String authkey = getAuthKey();
    final header = {
      'Authorization': authkey
    };

    final url = Uri.parse(
        'https://lirik.tv/api/chat/video/${widget.vodurl.split('/')[4]}?start=$start&end=$end');
    Response response = await get(url, headers: header);
    return response.body;
  }

  Future<String> javascripttest() async {
    String sRequest = await widget.werbview.runJavascriptReturningResult("""
      var url = "https://lirik.tv/api/chat/video/4a5f9692-e59c-4279-9269-3e59f5d9b11d?start=8&end=18";
      var result = "";

      var xhr = new XMLHttpRequest();
      xhr.open("GET", url, false);

      xhr.setRequestHeader("Authorization", "Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJuYW1laWQiOiIxNmQwN2U2Yi1jNGUyLTQ1OGEtOWFkZS1jMTEzMDkxYTlmN2UiLCJuYW1lIjoiaUZ1enppbmciLCJuYmYiOjE2NTY1MTI4NzksImV4cCI6MTY1Njc3MjEzOSwiaWF0IjoxNjU2NTEyOTM5LCJpc3MiOiJodHRwczovL2xpcmlrLnR2In0.Wx6egg4zXv8tWfFhx3dt12YWBUdFkzEg1glrDKLtap1SNj7u0gl1H7a3nVB4NcM8UlC1VYrU4-SGLupcj9Gf4w");

      xhr.onreadystatechange = function () {
        if (xhr.readyState === 4) {
            result = xhr.response;
        }};
      xhr.send();
      result;
      """);

    return sRequest.substring(1, sRequest.length - 1).replaceAll('\\"', '"');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: !isVideoPlaying
          ? AppBar(
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
      body: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: OrientationBuilder(
          builder: (context, orientation) {
            return StaggeredGrid.count(
              crossAxisCount:
                  MediaQuery.of(context).orientation == Orientation.portrait
                      ? 1
                      : 4,
              children: [
                StaggeredGridTile.extent(
                  mainAxisExtent:
                      MediaQuery.of(context).orientation == Orientation.portrait
                          ? 250
                          : MediaQuery.of(context).size.height,
                  crossAxisCellCount:
                      MediaQuery.of(context).orientation == Orientation.portrait
                          ? 1
                          : !isFullScreen
                              ? 3
                              : 4,
                  child: YoutubePlayerControllerProvider(
                    controller: _ytControler,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        YoutubePlayerIFrame(
                          controller: _ytControler,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                            children: [
                              YoutubeValueBuilder(
                                controller: _ytControler,
                                builder: (context, value) {
                                  if (startAtChange != Duration.zero) {
                                    Future.delayed(const Duration(seconds: 2),
                                        () {
                                      _ytControler.seekTo(startAtChange);
                                      startAtChange = Duration.zero;
                                    });
                                  }
                                  setProgressAt(value.position);
                                  dVideoPostion = value.position;
                                  if (dVideoPostion.inSeconds >=
                                          dNextChatPosition.inSeconds ||
                                      dVideoPostion.inSeconds <
                                          dPrevVideoPosition.inSeconds) {
                                    getAPIVodChat(dVideoPostion.inSeconds,
                                            dVideoPostion.inSeconds + 10)
                                        .then((sChat) {
                                      final chatJson = json.decode(sChat);

                                      if (tChatHandling.isActive) {
                                        tChatHandling.cancel();
                                      }
                                      chatHandling(chatJson);
                                    });
                                    dNextChatPosition = Duration(
                                        seconds: value.position.inSeconds + 10);
                                    dPrevVideoPosition = dVideoPostion;
                                  }
                                  if (value.isReady) {
                                    if (value.playerState ==
                                        PlayerState.playing) {
                                      setState(() {
                                        isVideoPlaying = true;
                                      });
                                    } else {
                                      setState(() {
                                        isVideoPlaying = false;
                                      });
                                    }
                                  }

                                  return MediaQuery.of(context).orientation ==
                                          Orientation.landscape
                                      ? Column(
                                          children: [
                                            IconButton(
                                                onPressed: () {
                                                  setState(() {
                                                    isFullScreen =
                                                        !isFullScreen;
                                                  });
                                                },
                                                icon: const Icon(
                                                    Icons.fullscreen)),
                                          ],
                                        )
                                      : Container();
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Visibility(
                  visible: !isFullScreen,
                  child: StaggeredGridTile.extent(
                    crossAxisCellCount: 1,
                    mainAxisExtent: MediaQuery.of(context).orientation ==
                            Orientation.portrait
                        ? MediaQuery.of(context).size.height - 250
                        : MediaQuery.of(context).size.height - 20,
                    child: Column(
                      children: [
                        SizedBox(
                          width: MediaQuery.of(context).size.width,
                          height: 50,
                          child: Container(
                            color: const Color.fromARGB(255, 36, 36, 36),
                            child: Padding(
                              padding: const EdgeInsets.all(3.0),
                              child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Vod replay chat',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                            padding: const EdgeInsets.all(0),
                                            onPressed: () {
                                              setState(() {
                                                lwchat.clear();
                                              });
                                            },
                                            icon: const Icon(Icons.tune)),
                                        IconButton(
                                            padding: const EdgeInsets.all(0),
                                            onPressed: () {},
                                            icon:
                                                const Icon(Icons.view_stream)),
                                      ],
                                    )
                                  ]),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  Fluttertoast.showToast(
                                      msg: isChatAutoScrolling
                                          ? 'auto scroll off'
                                          : 'auto scroll on',
                                      toastLength: Toast.LENGTH_SHORT,
                                      gravity: ToastGravity.BOTTOM,
                                      timeInSecForIosWeb: 1,
                                      backgroundColor: const Color.fromARGB(
                                          255, 19, 90, 148),
                                      textColor: Colors.white,
                                      fontSize: 16.0);
                                  isChatAutoScrolling = !isChatAutoScrolling;
                                });
                              },
                              child: ListView.builder(
                                  controller: _scrollController,
                                  key: const PageStorageKey(0),
                                  itemCount: lwchat.length,
                                  itemBuilder: (context, index) {
                                    return lwchat[index];
                                  }),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
