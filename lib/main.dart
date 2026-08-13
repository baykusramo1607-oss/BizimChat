import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Arka plan bildirimleri için
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Bildirim ayarları
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  // await kelimesini siliyoruz, arka planda kendisi başlasın
  flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const ChatApp());
}

class ChatApp extends StatefulWidget {
  const ChatApp({super.key});

  static _ChatAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_ChatAppState>();

  @override
  State<ChatApp> createState() => _ChatAppState();
}

class _ChatAppState extends State<ChatApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bizim Chat',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFFECE5DD),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFF121B22),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roomController =
      TextEditingController(text: "Genel");

  @override
  void initState() {
    super.initState();
    _loadSavedName();
  }

  // Hafızadaki kayıtlı ismi yükleme
  void _loadSavedName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedName = prefs.getString('saved_username');
    if (savedName != null && savedName.isNotEmpty) {
      setState(() {
        _nameController.text = savedName;
      });
    }
  }

  // İsmi hafızaya kaydetip sohbete geçme
  void _enterChat() async {
    String name = _nameController.text.trim();
    String room = _roomController.text.trim();

    if (name.isNotEmpty && room.isNotEmpty) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_username', name);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            username: name,
            roomCode: room,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121B22) : Colors.teal.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.wb_sunny : Icons.nightlight_round),
            onPressed: () => ChatApp.of(context)?.toggleTheme(),
          )
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.chat_bubble_rounded,
                  size: 80, color: Colors.teal),
              const SizedBox(height: 16),
              const Text(
                'Bizim Chat',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Adınız',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _roomController,
                decoration: InputDecoration(
                  labelText: 'Oda Kodu / Adı (Örn: Genel)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _enterChat,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child:
                    const Text('Sohbete Katıl', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String username;
  final String roomCode;
  const ChatScreen({super.key, required this.username, required this.roomCode});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _messageController.addListener(_onTyping);
    _setUserOnline(true);
  }

  void _setUserOnline(bool isOnline) {
    _firestore.collection('status').doc(widget.username).set({
      'isOnline': isOnline,
      'isTyping': false,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setUserOnline(true);
    } else {
      _setUserOnline(false);
    }
  }

  void _onTyping() {
    bool isTyping = _messageController.text.isNotEmpty;
    _firestore.collection('status').doc(widget.username).set({
      'isTyping': isTyping,
    }, SetOptions(merge: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setUserOnline(false);
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage({String? textUrl}) {
    String text = textUrl ?? _messageController.text.trim();
    if (text.isNotEmpty) {
      _firestore
          .collection('rooms')
          .doc(widget.roomCode)
          .collection('messages')
          .add({
        'sender': widget.username,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'isImage': textUrl != null,
        'reaction': '',
      });
      _messageController.clear();
      _firestore.collection('status').doc(widget.username).set({
        'isTyping': false,
      }, SetOptions(merge: true));
    }
  }

  void _addReaction(String docId, String emoji) {
    _firestore
        .collection('rooms')
        .doc(widget.roomCode)
        .collection('messages')
        .doc(docId)
        .update({'reaction': emoji});
  }

  void _showReactionMenu(String docId) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        List<String> emojis = ['❤️', '👍', '😂', '🔥', '😮', '🙏'];
        return Container(
          height: 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: emojis.map((e) {
              return GestureDetector(
                onTap: () {
                  _addReaction(docId, e);
                  Navigator.pop(context);
                },
                child: Text(e, style: const TextStyle(fontSize: 30)),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _deleteMessage(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Mesaj Seçeneği"),
        content: const Text("Ne yapmak istersiniz?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showReactionMenu(docId);
            },
            child: const Text("Tepki Ver"),
          ),
          TextButton(
            onPressed: () {
              _firestore
                  .collection('rooms')
                  .doc(widget.roomCode)
                  .collection('messages')
                  .doc(docId)
                  .delete();
              Navigator.pop(context);
            },
            child: const Text("Sil", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    DateTime date = timestamp.toDate();
    return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Oda: ${widget.roomCode}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('status').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Text('Bağlanıyor...',
                      style: TextStyle(fontSize: 11));

                List<String> typingUsers = [];
                String statusText = "Çevrimdışı";

                for (var doc in snapshot.data!.docs) {
                  if (doc.id != widget.username) {
                    var data = doc.data() as Map<String, dynamic>;
                    if (data['isTyping'] == true) {
                      typingUsers.add(doc.id);
                    }
                    if (data['isOnline'] == true) {
                      statusText = "Çevrimiçi";
                    } else if (data['lastSeen'] != null) {
                      statusText =
                          "Son görülme: ${_formatTime(data['lastSeen'] as Timestamp?)}";
                    }
                  }
                }

                if (typingUsers.isNotEmpty) {
                  return Text('${typingUsers.join(', ')} yazıyor...',
                      style: const TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.lightGreenAccent));
                }
                return Text(statusText, style: const TextStyle(fontSize: 11));
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.wb_sunny : Icons.nightlight_round),
            onPressed: () => ChatApp.of(context)?.toggleTheme(),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('rooms')
                  .doc(widget.roomCode)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                var docs = snapshot.data!.docs;

                for (var doc in docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  if (data['sender'] != widget.username &&
                      data['isRead'] == false) {
                    _firestore
                        .collection('rooms')
                        .doc(widget.roomCode)
                        .collection('messages')
                        .doc(doc.id)
                        .update({'isRead': true});
                  }
                }

                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    bool isMe = data['sender'] == widget.username;
                    bool isImage = data['isImage'] ?? false;
                    String reaction = data['reaction'] ?? '';

                    return GestureDetector(
                      onLongPress: () => isMe
                          ? _deleteMessage(doc.id)
                          : _showReactionMenu(doc.id),
                      child: Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? (isDark
                                        ? const Color(0xFF005C4B)
                                        : const Color(0xFFE2F7CB))
                                    : (isDark
                                        ? const Color(0xFF202C33)
                                        : Colors.white),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isMe)
                                    Text(data['sender'] ?? 'Anonim',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: Colors.teal)),
                                  if (isImage)
                                    Image.network(data['text'],
                                        width: 200,
                                        errorBuilder: (c, e, s) =>
                                            const Text("Resim yüklenemedi"))
                                  else
                                    Text(data['text'] ?? '',
                                        style: const TextStyle(fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                          _formatTime(
                                              data['createdAt'] as Timestamp?),
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[500])),
                                      if (isMe) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.done_all,
                                          size: 16,
                                          color: (data['isRead'] == true)
                                              ? Colors.blue
                                              : Colors.grey,
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (reaction.isNotEmpty)
                              Positioned(
                                bottom: -2,
                                right: isMe ? 16 : null,
                                left: isMe ? null : 16,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey[800]
                                        : Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: const [
                                      BoxShadow(
                                          blurRadius: 2, color: Colors.black26)
                                    ],
                                  ),
                                  child: Text(reaction,
                                      style: const TextStyle(fontSize: 12)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: isDark ? const Color(0xFF1E2C34) : Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Mesaj yazın...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.teal),
                  onPressed: () => _sendMessage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
