import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

import 'common.dart';

void main() {
  runApp(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: FiqhApp(),
      )
  );
}

class FiqhApp extends StatefulWidget {
  const FiqhApp({super.key});

  @override
  State<StatefulWidget> createState() {
    return FiqhAppState();
  }
}

enum ListLevel { SHEEKH, BOOK, SUB_BOOK, CHAPTER, INDEX }
enum PlayerStatus { Play, Pause, Buffering }
ListLevel currentLevel = ListLevel.SHEEKH;
PlayerStatus playerStatus = PlayerStatus.Play;
bool sheekhTab = true;

class FiqhAppState extends State<FiqhApp> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final List<Node> sheekhList = [];
  final List<Node> fiqhList = [];
  final List<Node> parent = [];
  String sheekhTitlePath = '';
  String fiqhTitlePath = '';
  late final AudioPlayer _player;
  static bool enableTile = true;
  late TabController _controller;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    ambiguate(WidgetsBinding.instance)!.addObserver(this);
    _init();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initList();
    });
    //SchedulerBinding.instance.addPostFrameCallback((_) {_init();});

    _controller = TabController(length: 2, vsync: this);
    _controller.addListener(() {
      if (!_controller.indexIsChanging) {
        //print("swap Index: " + _controller.index.toString());
        sheekhTab = (_controller.index == 0);
        _initList();
      }
    });
  }

  Future<void> _init() async {
    // Inform the operating system of our app's audio attributes etc.
    // We pick a reasonable default for an app that plays speech.
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    // Listen to errors during playback.
    _player.playbackEventStream.listen((event) {},
        onError: (Object e, StackTrace stackTrace) {
          print('A stream error occurred: $e');
        });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Release the player's resources when not in use. We use "stop" so that
      // if the app resumes later, it will still remember what position to
      // resume from
      _player.stop();
    }
  }

  // Collects the data useful for displaying in a seek bar, using a handy
  // feature of rx_dart to combine the 3 streams of interest into one.
  Stream<PositionData> get _positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
          _player.positionStream,
          _player.bufferedPositionStream,
          _player.durationStream,
              (position, bufferedPosition, duration) =>
              PositionData(
                  position, bufferedPosition, duration ?? Duration.zero));

  Future<void> _initList() async {
    enableTile = true;
    parent.clear();

    setState(() {
      fiqhList.clear();
      sheekhList.clear();
      fiqhTitlePath = '';
      sheekhTitlePath = '';
    });
    final response = await http.post(
      Uri.parse('https://fiqh.cc/db.php'),
      headers: <String, String>{'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode(<String, String>{
        'sql_id': sheekhTab ? '0' : '6',
      }),
    );

    if (response.statusCode == 200) {
      currentLevel = ListLevel.SHEEKH;
      parent.add(Node(0,'',0,'',false,'','',0,'','',0,0,0,'','','',0));
      final List<dynamic> data = jsonDecode(response.body);
      for (var map in data) {
        printMapContent(map);
      }
    } else {
      print('Failed to create list');
    }
    setState(() {});
  }

  void printMapContent(Map<String, dynamic> map) {
    String Category_name = '';
    int Category_id = 0;

    int Sheekh_id = 0;
    String Sheekh_name = '';
    int Book_id = 0;
    String Book_name = '';
    bool Multi_volume = false;
    String Title = '';
    String Sub_Book = '';

    int code = 0;
    String line = '';
    String tafreeg = '';
    int offset = 0;
    int seq = 0;
    int Duration = 0;

    String FileName = '';
    String Path = '';

    map.forEach((key, value) {
      switch (key) {
        case 'Sheekh_id':
          Sheekh_id = int.parse(value);
          break;
        case 'Sheekh_name':
          Sheekh_name = value;
          break;
        case 'Book_id':
          Book_id = int.parse(value);
          break;
        case 'Book_name':
          Book_name = value;
          break;
        case 'Multi_volume':
          Multi_volume = value == '0' ? false : true;
          break;
        case 'Title':
          Title = value;
          break;
        case 'FileName':
          FileName = value;
          break;
        case 'Duration':
          Duration = int.parse(value);
          break;
        case 'Path':
          Path = value;
          break;
        case 'Code':
          code = int.parse(value);
          break;
        case 'Line':
          line = value;
          break;
        case 'Sub_Book':
          Sub_Book = value;
          break;
        case 'Tafreeg':
          tafreeg = value;
          break;
        case 'Offset':
          offset = int.parse(value);
          break;
        case 'Seq':
          seq = int.parse(value);
          break;
        case 'Category_name':
          Category_name = value;
          break;
        case 'Category_id':
          Category_id = int.parse(value);
          break;
      }
    });

    (sheekhTab ? sheekhList : fiqhList).add(Node(
        Sheekh_id,
        Sheekh_name,
        Book_id,
        Book_name,
        Multi_volume,
        Title,
        Sub_Book,
        code,
        line,
        tafreeg,
        offset,
        seq,
        Duration,
        FileName,
        Path,
        Category_name,
        Category_id));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: TabBar(
              controller: _controller,
              onTap: (index) {
                if (!_controller.indexIsChanging) {
                  //print("Same Tab Clicked");
                  _initList();
                }
              },
              tabs: const <Widget>[
                Tab(text: 'المشايخ'),
                Tab(text: 'التصانيف'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _controller,
            children: <Widget>[
              Column(
                //mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                //crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Flexible(
                          flex: 1,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(1.0, 1.0, 4.0, 3.0),
                            child: Container(
                                width: double.infinity,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: Colors.black12),
                                  color: Colors.black.withAlpha(10),
                                ),
                                child: Text(sheekhTitlePath)
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: (currentLevel == ListLevel.SHEEKH) ? null : () async {
                              if (!enableTile) {
                                return;
                              } else {
                                enableTile = false;
                              }

                              if (currentLevel == ListLevel.INDEX) {
                                currentLevel = ListLevel.CHAPTER;
                              } else {
                                if (currentLevel == ListLevel.CHAPTER) {
                                  if (parent.last.Multi_volume) {
                                    currentLevel = ListLevel.SUB_BOOK;
                                  } else {
                                    currentLevel = ListLevel.BOOK;
                                  }
                                } else {
                                  if (currentLevel == ListLevel.SUB_BOOK) {
                                    currentLevel = ListLevel.BOOK;
                                  } else {
                                    if (currentLevel == ListLevel.BOOK) {
                                      currentLevel = ListLevel.SHEEKH;
                                    } else {
                                      // (currentLevel == ListLevel.SHEEKH)
                                      // return button should be disabled to not allow this
                                    }
                                  }
                                }
                              }

                              final response = await http.post(
                                Uri.parse('https://fiqh.cc/db.php'),
                                headers: <String, String>{'Content-Type': 'application/json; charset=UTF-8',},
                                body: jsonEncode(<String, String>{
                                  'Sheekh_id': parent.last.Sheekh_id.toString(),
                                  'Book_id': parent.last.Book_id.toString(),
                                  'Title': parent.last.Title,
                                  'Code': parent.last.code.toString(),
                                  'sql_id':
                                  (currentLevel == ListLevel.SHEEKH) ? '0' :
                                  ((currentLevel == ListLevel.BOOK) ? '1' :
                                  ((currentLevel == ListLevel.SUB_BOOK) ? '2' :
                                  (parent.last.Multi_volume ? '4' : '3'))),
                                }),
                              );

                              if (response.statusCode == 200) {
                                final List<dynamic> data = jsonDecode(response.body);
                                sheekhTitlePath = sheekhTitlePath.substring(0, sheekhTitlePath.lastIndexOf("←"));
                                parent.removeLast();
                                sheekhList.clear();
                                //print('data $data');
                                for (var map in data) {
                                  printMapContent(map);
                                }
                                setState(() {});
                              }
                              else {
                                print('Failed to create list');
                              }
                              enableTile = true;
                            }
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder( // ListView.separated( loading list in lazy style, slow
                      itemCount: sheekhList.length,
                      //prototypeItem: const ListTile(), // TODO: improve the performance but the list height is fixed on only one line even if text is multi line
                      itemBuilder: (BuildContext context, int index) {
                        return
                          Container(
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: Colors.black12)),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10.0),
                                // default is EdgeInsets.symmetric(horizontal: 16.0)
                                leading: (currentLevel != ListLevel.INDEX) ? const Icon(Icons.folder_outlined) : null,
                                trailing: sheekhList[index].tafreeg.isNotEmpty ? IconButton(
                                    icon: const Icon(Icons.paste),
                                    onPressed: () {
                                      showDialog(
                                          context: context,
                                          builder: (context) {
                                            return Directionality(
                                              textDirection: TextDirection.rtl,
                                              child: AlertDialog(
                                                scrollable: true,
                                                content: Text(sheekhList[index].tafreeg),
                                              ),
                                            );
                                          }
                                      );
                                    }) : null,
                                title: Text(sheekhList[index].getTitle()),
                                onTap: () async {
                                  if (!enableTile) {
                                    return;
                                  } else {
                                    enableTile = false;
                                  }
                                  if (currentLevel == ListLevel.INDEX) {
                                    final String src = "https://maknoon.com/audios.m4a/${sheekhList[index]
                                        .path}/${sheekhList[index].fileName}.m4a";
                                    try {
                                      await _player.setAudioSource(AudioSource.uri(Uri.parse(src)));
                                      _player.seek(Duration(milliseconds: sheekhList[index].offset));
                                      _player.play();
                                    } on PlayerException catch (e) {
                                      print("Error loading audio source: $e $src");
                                    }
                                  } else {
                                    final response = await http.post(
                                      Uri.parse('https://fiqh.cc/db.php'),
                                      headers: <String, String>{'Content-Type': 'application/json; charset=UTF-8',},
                                      body: jsonEncode(<String, String>{
                                        'Sheekh_id': sheekhList[index].Sheekh_id.toString(),
                                        'Book_id': sheekhList[index].Book_id.toString(),
                                        'Title': sheekhList[index].Title,
                                        'Code': sheekhList[index].code.toString(),
                                        'sql_id':
                                        (currentLevel == ListLevel.SHEEKH) ? '1' :
                                        ((currentLevel == ListLevel.BOOK) ?
                                        ((sheekhList[index].Multi_volume) ? '2' : '3') :
                                        ((currentLevel == ListLevel.SUB_BOOK) ? '4' : '5')
                                        ),
                                      }),
                                    );

                                    if (response.statusCode == 200) {
                                      final List<dynamic> data = jsonDecode(response.body);
                                      if (data.isEmpty) { // i.e. chapter has no indexes
                                        try {
                                          await _player.setAudioSource(AudioSource.uri(Uri.parse(
                                              "https://maknoon.com/audios.m4a/${sheekhList[index]
                                                  .path}/${sheekhList[index].fileName}.m4a")
                                          ));
                                          _player.seek(Duration.zero);
                                          _player.play();
                                        } on PlayerException catch (e) {
                                          print("Error loading audio source: $e");
                                        }
                                      } else {
                                        sheekhTitlePath = "$sheekhTitlePath ← ${sheekhList[index].getTitle()}";
                                        if (currentLevel == ListLevel.SHEEKH) {
                                          currentLevel = ListLevel.BOOK;
                                        } else {
                                          if (currentLevel == ListLevel.BOOK) {
                                            if (sheekhList[index].Multi_volume) {
                                              currentLevel = ListLevel.SUB_BOOK;
                                            } else {
                                              currentLevel = ListLevel.CHAPTER;
                                            }
                                          } else {
                                            if (currentLevel == ListLevel.SUB_BOOK) {
                                              currentLevel = ListLevel.CHAPTER;
                                            } else {
                                              if (currentLevel == ListLevel.CHAPTER) {
                                                currentLevel = ListLevel.INDEX;
                                              } else {
                                                // (currentLevel == ListLevel.INDEX)
                                                // We should not reach here
                                              }
                                            }
                                          }
                                        }

                                        parent.add(sheekhList[index]);
                                        sheekhList.clear();
                                        //print('data $data');
                                        for (var map in data) {
                                          printMapContent(map);
                                        }
                                        setState(() {});
                                      }
                                    }
                                    else {
                                      print('Failed to create list');
                                    }
                                  }
                                  enableTile = true;
                                },
                              )
                          );
                      },
                    ),
                  ),
                ],
              ),
              Column(
                children: <Widget>[
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Flexible(
                          flex: 1,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(1.0, 1.0, 4.0, 3.0),
                            child: Container(
                                width: double.infinity,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: Colors.black12),
                                  color: Colors.black.withAlpha(10),
                                ),
                                child: Text(fiqhTitlePath)
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: (parent.isEmpty || parent.last.Category_name.isEmpty) ? null : () async {
                              if (!enableTile) {
                                return;
                              } else {
                                enableTile = false;
                              }

                              final response = await http.post(
                                Uri.parse('https://fiqh.cc/db.php'),
                                headers: <String, String>{'Content-Type': 'application/json; charset=UTF-8',},
                                body: jsonEncode(<String, String>{
                                  'Category_id': parent[parent.length - 2].Category_id.toString(),
                                  'sql_id': parent[parent.length - 2].Category_name.isEmpty ? '6' : '7',
                                }),
                              );

                              if (response.statusCode == 200) {
                                final List<dynamic> data = jsonDecode(response.body);
                                fiqhTitlePath = fiqhTitlePath.substring(0, fiqhTitlePath.lastIndexOf("←"));
                                parent.removeLast();
                                fiqhList.clear();
                                //print('data $data');
                                for (var map in data) {
                                  printMapContent(map);
                                }
                                setState(() {});
                              }
                              else {
                                print('Failed to create list');
                              }
                              enableTile = true;
                            }
                        )
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: fiqhList.length,
                      itemBuilder: (BuildContext context, int index) {
                        return
                          Container(
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: Colors.black12)),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10.0),
                                leading: fiqhList[index].Category_name.isNotEmpty
                                    ? const Icon(Icons.folder_outlined)
                                    : null,
                                trailing: fiqhList[index].tafreeg.isNotEmpty ? IconButton(
                                    icon: const Icon(Icons.paste),
                                    onPressed: () {
                                      showDialog(
                                          context: context,
                                          builder: (context) {
                                            return Directionality(
                                              textDirection: TextDirection.rtl,
                                              child: AlertDialog(
                                                scrollable: true,
                                                content: Text(fiqhList[index].tafreeg),
                                              ),
                                            );
                                          }
                                      );
                                    }) : null,
                                title: fiqhList[index].Category_name.isNotEmpty
                                    ? Text(fiqhList[index].getTitle())
                                    : fiqhList[index].getTitleRich(),
                                onTap: () async {
                                  if (!enableTile) {
                                    return;
                                  } else {
                                    enableTile = false;
                                  }
                                  if (fiqhList[index].fileName.isNotEmpty) {
                                    try {
                                      await _player.setAudioSource(AudioSource.uri(Uri.parse(
                                          "https://maknoon.com/audios.m4a/${fiqhList[index]
                                              .path}/${fiqhList[index].fileName}.m4a")
                                      ));
                                      _player.seek(Duration(milliseconds: fiqhList[index].offset));
                                      _player.play();
                                    } on PlayerException catch (e) {
                                      print("Error loading audio source: $e");
                                    }
                                  } else {
                                    final response = await http.post(
                                      Uri.parse('https://fiqh.cc/db.php'),
                                      headers: <String, String>{'Content-Type': 'application/json; charset=UTF-8',},
                                      body: jsonEncode(<String, String>{
                                        'Category_id': fiqhList[index].Category_id.toString(),
                                        'sql_id': '7',
                                      }),
                                    );

                                    if (response.statusCode == 200) {
                                      final List<dynamic> data = jsonDecode(response.body);
                                      fiqhTitlePath = "$fiqhTitlePath ← ${fiqhList[index].getTitle()}";
                                      parent.add(fiqhList[index]);
                                      fiqhList.clear();
                                      //print('data $data');
                                      for (var map in data) {
                                        printMapContent(map);
                                      }
                                      setState(() {});
                                    }
                                    else {
                                      print('Failed to create list');
                                    }
                                  }
                                  enableTile = true;
                                },
                              )
                          );
                      },
                      //separatorBuilder: (BuildContext context, int index) => const Divider(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.8),
            //mini: true,
            child:
            // This StreamBuilder rebuilds whenever the player state changes, which
            // includes the playing/paused state and also the
            // loading/buffering/ready state. Depending on the state we show the
            // appropriate button or loading indicator.
            StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
              builder: (context, snapshot) {
                final playerState = snapshot.data;
                final processingState = playerState?.processingState;
                final playing = playerState?.playing;
                if (processingState == ProcessingState.loading ||
                    processingState == ProcessingState.buffering) {
                  return const SizedBox( // same size as Icon
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator()
                  );
                } else if (playing != true) {
                  playerStatus = PlayerStatus.Play;
                  return const Icon(Icons.play_arrow);
                } else if (processingState != ProcessingState.completed) {
                  playerStatus = PlayerStatus.Pause;
                  return const Icon(Icons.pause);
                } else {
                  playerStatus = PlayerStatus.Buffering;
                  return const Icon(Icons.replay);
                }
              },
            ),
            onPressed: () {
              switch (playerStatus) {
                case PlayerStatus.Play:
                  _player.play();
                  break;
                case PlayerStatus.Pause:
                  _player.pause();
                  break;
                case PlayerStatus.Buffering:
                  _player.load();
                  break;
              }
            },
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: Directionality(
            textDirection: TextDirection.ltr,
            child: SafeArea(
              child: Container(
                color: Colors.black26,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Display play/pause button and volume/speed sliders.
                    ControlButtons(_player),
                    // Display seek bar. Using StreamBuilder, this widget rebuilds
                    // each time the position, buffered position or duration changes.
                    StreamBuilder<PositionData>(
                      stream: _positionDataStream,
                      builder: (context, snapshot) {
                        final positionData = snapshot.data;
                        return SeekBar(
                          duration: positionData?.duration ?? Duration.zero,
                          position: positionData?.position ?? Duration.zero,
                          bufferedPosition:
                          positionData?.bufferedPosition ?? Duration.zero,
                          onChangeEnd: _player.seek,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    ambiguate(WidgetsBinding.instance)!.removeObserver(this);
    // Release decoders and buffers back to the operating system making them
    // available for other apps to use.
    _player.dispose();
    super.dispose();
  }
}

// Displays the play/pause button and volume/speed sliders.
class ControlButtons extends StatelessWidget {
  final AudioPlayer player;

  const ControlButtons(this.player, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Opens volume slider dialog
        IconButton(
          icon: const Icon(Icons.volume_up),
          onPressed: () {
            showSliderDialog(
              context: context,
              title: "الصوت",
              divisions: 10,
              min: 0.0,
              max: 1.0,
              value: player.volume,
              stream: player.volumeStream,
              onChanged: player.setVolume,
            );
          },
        ),

        const SizedBox(width: 75),

        // Opens speed slider dialog
        StreamBuilder<double>(
          stream: player.speedStream,
          builder: (context, snapshot) => IconButton(
            icon: Text("${snapshot.data?.toStringAsFixed(1)}x",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              showSliderDialog(
                context: context,
                title: "سرعة الإلقاء",
                divisions: 10,
                min: 0.5,
                max: 1.5,
                value: player.speed,
                stream: player.speedStream,
                onChanged: player.setSpeed,
              );
            },
          ),
        ),
      ],
    );
  }
}

class Node {
  String Category_name;
  int Category_id;

  int Sheekh_id;
  String Sheekh_name;
  int Book_id;
  String Book_name;
  bool Multi_volume;
  String Title;
  String Sub_Book;

  int code;
  String line;
  String tafreeg;
  int offset;
  int seq;
  int duration;

  String fileName;
  String path;

  Node(this.Sheekh_id, this.Sheekh_name, this.Book_id, this.Book_name, this.Multi_volume, this.Title, this.Sub_Book,
      this.code, this.line, this.tafreeg, this.offset, this.seq, this.duration, this.fileName, this.path,
      this.Category_name, this.Category_id);

  String getTitle() {
    if (sheekhTab) {
      if (currentLevel == ListLevel.SHEEKH) {
        return Sheekh_name;
      } else {
        if (currentLevel == ListLevel.BOOK) {
          return Book_name;
        } else {
          if (currentLevel == ListLevel.SUB_BOOK) {
            return Title;
          } else {
            if (currentLevel == ListLevel.CHAPTER) {
              return "$Title($fileName)";
            } else { // index
              final String dur;
              if (duration == -1) {
                dur = "[?] ";
              } else {
                final String minute = (duration / 60 / 1000).toInt().toString();
                final String second = (duration / 1000 -
                    (duration.toDouble() / 60 / 1000).toInt() * 60).toInt().toString();
                dur = "[$minute:$second] ";
              }
              return "$dur$line";
            }
          }
        }
      }
    } else {
      if (Category_name.isNotEmpty) {
        return Category_name;
      } else {
        final String dur;
        if (duration == -1) {
          dur = "[?] ";
        } else {
          final String minute = (duration / 60 / 1000).toInt().toString();
          final String second = (duration / 1000 -
              (duration.toDouble() / 60 / 1000).toInt() * 60).toInt().toString();
          dur = "[$minute:$second] ";
        }

        if (Book_name == Title) {
          return "$dur$line←$Sheekh_name←$Book_name←$fileName";
        } else {
          return "$dur$line←$Sheekh_name←$Book_name←$Title←$fileName";
        }
      }
    }
  }

  Text getTitleRich() {
    final String dur;
    if (duration == -1) {
      dur = "[?] ";
    } else {
      final String minute = (duration / 60 / 1000).toInt().toString();
      final String second = (duration / 1000 -
          (duration.toDouble() / 60 / 1000).toInt() * 60).toInt().toString();
      dur = "[$minute:$second] ";
    }

    return Text.rich(
      TextSpan(
        text: "$dur$line ",
        children: <TextSpan>[
          TextSpan(text: (Book_name == Title) ?
          '$Sheekh_name←$Book_name←$fileName' :
          '$Sheekh_name←$Book_name←$Title←$fileName', style: const TextStyle(color: Colors.indigo)),
        ],
      ),
    );
  }
}
