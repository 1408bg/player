import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const String _ver = "0.3";

void main(){
  runApp(
      MaterialApp(
        title: "Player",
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: Colors.deepPurpleAccent[800],
          scaffoldBackgroundColor: Colors.black,
        ),
        home: const Player()
      )
  );
}

class Player extends StatefulWidget {
  const Player({super.key});

  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  final _player = AudioPlayer();
  bool isPlaying = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  int _num = 1;
  int _sel = 0;
  late int _min;
  late int _max;
  String _title = "Loading";
  Widget _main = const Column(
    children: [CircularProgressIndicator(), SizedBox(height: 30), Text("Wait a second..")]
  );
  double _volume = 0.5;
  bool _isMute = false;
  bool _loading = true;
  late List<String> _titles;

  @override
  void initState(){
    super.initState();

    _versionCheck();

    setAudio();
    initAudio();

    _player.onPlayerStateChanged.listen((state) {
      setState(() {
        isPlaying = (state == PlayerState.playing);
      });
    });
    _player.onDurationChanged.listen((dur) {
      setState(() {
        duration = dur;
      });
    });
    _player.onPositionChanged.listen((pos) {
      if (pos == duration){
        return;
      }
      setState(() {
        position = pos;
      });
    });

    Future.delayed(const Duration(seconds: 1), ()=>{
      _update()
    });
  }

  Future fetch(String address) async {
    var res;
    try {
      res = await http.get(
          Uri.parse(address)
      );
    } on Exception {
      Future.delayed(const Duration(seconds: 1), (){
        return fetch(address);
      });
    }
    return jsonDecode(res.body);
  }

  Future<void> _versionCheck() async {
    if (!mounted) return;
    var data = await fetch("https://1408bg.github.io/assets/audio.json");
    if (data["ver"] != _ver){
      _showUpdateDialog(context);
    }
  }

  Future<void> setAudio() async {
    _player.setReleaseMode(ReleaseMode.loop);
    _player.setVolume(0.5);
  }

  Future<void> initAudio() async{
    var data;
    try {
      data = await fetch("https://1408bg.github.io/assets/audio.json");
    } on Exception {
      data = {"titles" : []};
    }
    _titles = List.from(data["titles"]);
    _max = -1;
    await setRange(_titles[_sel]);
    _loading = false;
  }

  Future<void> setRange(String title) async {
    _num = 1;
    var data;
    try {
      data = await http.get(Uri.parse("https://1408bg.github.io/assets/audio.json"));
      data = jsonDecode(data.body);
      data = data[title];
    } on Exception {
      data = {"min" : "1", "max" : "1"};
    }
    setState(() {
      _min = int.parse(data["min"]);
      _max = int.parse(data["max"]);
      _num = _min;
    });
  }

  Future<void> setUrl(String address) async{
    _player.pause();
    position = Duration.zero;
    await _player.setSourceUrl(address);
    await _player.seek(position);
  }

  String formatTime(Duration duration){
    if (duration.inSeconds < 0){
      duration = Duration.zero;
    }
    String getTime(int n) => n.toString().padLeft(2, '0');
    final min = getTime(duration.inMinutes.remainder(60));
    final sec = getTime(duration.inSeconds.remainder(60));
    return "$min:$sec";
  }

  void _setVolume(){
    if (_volume == 0.0){
      _isMute = true;
    }
    else {
      _isMute = false;
    }
    _player.setVolume(_volume);
  }

  int increase(int num, int min, int max) {
    if (min == max){
      return min;
    }
    num++;
    if (num > max) {
      num = min;
    }
    return num;
  }

  void _update(){
    _player.pause();
    _main = FutureBuilder(
            future: fetch("https://1408bg.github.io/assets/audio.json"),
            builder: (context, snap){
              if (!snap.hasData) { return const CircularProgressIndicator(); }
              var data = snap.data[_titles[_sel]]["tracks"][_num-1];
              setUrl(data["url"]);
              _title = data["title"];
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: Image.network(
                        data['img'],
                        fit: BoxFit.cover,
                        loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress){
                          if (loadingProgress == null){
                            return child;
                          }
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                    ),
                  ),
                  Text(
                    data["title"],
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold
                    ),
                  ),
                  const SizedBox(height: 4,),
                  Text(
                    data["artist"],
                    style: const TextStyle(
                        fontSize: 16
                    ),
                  )
                ],
              );
            }
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Music Player", style: TextStyle(fontSize: 16),),
            Text("Now Playing : $_title [$_num/${_loading ? "..." : _max}]", style: const TextStyle(fontSize: 12),),
          ],
        ),
        centerTitle: true,
        toolbarHeight: 90,
      ),
      body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _main,
              SizedBox(
                  width: MediaQuery.of(context).size.width - 120,
                  child: Slider(
                    min: 0,
                    max: duration.inSeconds.toDouble(),
                    value: (position.inSeconds.toDouble() >= duration.inSeconds.toDouble()) ? 0.0 : position.inSeconds.toDouble(),
                    onChanged: (value) async {
                      final position = Duration(seconds: value.toInt());
                      await _player.seek(position);
                      await _player.resume();
                    }
                  )
              ),
              SizedBox(
                  width: MediaQuery.of(context).size.width - 160,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formatTime(position)),
                      Text(formatTime(duration-position)),
                    ],
                  )
              ),
              CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.transparent,
                  child: IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                    tooltip: isPlaying ? "pause" : "play",
                    enableFeedback: _loading,
                    iconSize: 50,
                    onPressed: () async {
                      if (isPlaying){
                        await _player.pause();
                      }
                      else {
                        await _player.resume();
                      }
                    },
                  )
              )
            ],
          )
      ),
      floatingActionButton: Stack(
        children: [
          Align(
            alignment: Alignment.bottomRight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  tooltip: "Settings",
                  onPressed: () {
                    showDialog(context: context, builder: ((context) {
                      return StatefulBuilder(builder: (BuildContext context, StateSetter setState){
                        return Dialog(
                          alignment: Alignment.center,
                          shadowColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)
                          ),
                          elevation: 10,
                          child: SizedBox(
                            height: 300,
                            child: Column(
                              children: [
                                const Text("Settings", style: TextStyle(fontSize: 24)),
                                const SizedBox(height: 16),
                                const Text("Volume"),
                                SizedBox(
                                  width: 300,
                                  height: 22,
                                  child: Slider(
                                    min: 0.0,
                                    max: 1.0,
                                    thumbColor: _isMute ? Colors.grey : _volume >= 0.8 ? Colors.red[800] : Colors.deepPurpleAccent[800],
                                    activeColor: _volume >= 0.8 ? Colors.red[800] : Colors.deepPurple[800],
                                    value: _volume,
                                    onChanged: (value) async {
                                      setState(() {
                                        _volume = value;
                                      });
                                      _setVolume();
                                    },
                                  ),
                                ),
                                const SizedBox(
                                  height: 16,
                                ),
                                const Text("Playlist"),
                                DropdownButtonHideUnderline(
                                  child: DropdownButton(
                                    value: _titles.elementAt(_sel),
                                    focusColor: Colors.transparent,
                                    isDense: true,
                                    items: _titles.map((e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    )).toList(),
                                    onChanged: (value) async {
                                      setState(() {
                                        _sel = _titles.indexOf(value.toString());
                                      });
                                      setRange(_titles[_sel]);
                                      _update();
                                    },
                                  ),
                                ),
                                const SizedBox(
                                  height: 16,
                                ),
                                const Text("Mail"),
                                const Text("b_g@dsm.hs.kr", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                              ],
                            ),
                          ),
                        );
                      });
                    }));
                  },
                  child: const Icon(Icons.settings),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  tooltip: "Next",
                  onPressed: () {
                    _num = increase(_num, _min, _max);
                    _update();
                  },
                  child: const Icon(Icons.skip_next),
                )
              ]
            )
          )
        ]
      )
    );
  }

  void _showUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Available'),
          content: const Text('A new version of the app is available. Please update to the latest version.'),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                launchUrl(Uri.parse('https://1408bg.github.io/store'));
              },
              child: const Text('Update Now'),
            ),
          ],
        );
      },
    );
  }
}