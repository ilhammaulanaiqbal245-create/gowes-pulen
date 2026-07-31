import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:typed_data';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "ISI_DARI_API_KEY_WEB_ANDA",
        authDomain: "gowea-app.firebaseapp.com",
        projectId: "gowea-app",
        storageBucket: "gowea-app.appspot.com",
        messagingSenderId: "457828944806",
        appId: "ISI_DARI_WEB_APP_ID_ANDA",
        databaseURL: "https://gowea-app-default-rtdb.asia-southeast1.firebasedatabase.app",
      ),
    );
    FirebaseDatabase.instance.setPersistenceEnabled(true);
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }
  runApp(const GowesPulenUltimateApp());
}

class ThemeNotifier extends ChangeNotifier {
  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
}

final themeNotifier = ThemeNotifier();

class GowesPulenUltimateApp extends StatelessWidget {
  const GowesPulenUltimateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeNotifier,
      builder: (context, _) {
        return MaterialApp(
          title: 'Gowes Pulen Enterprise 40+',
          theme: ThemeData(
            brightness: themeNotifier.isDarkMode ? Brightness.dark : Brightness.light,
            primaryColor: const Color(0xFF00A884),
            scaffoldBackgroundColor: themeNotifier.isDarkMode ? const Color(0xFF0B141A) : Colors.white,
          ),
          home: const AuthScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

// ================= 1. AUTH SCREEN & SECURITY =================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoading = false;

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      String username = googleUser.displayName ?? 'Goweser VIP';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_username', username);

      final userRef = FirebaseDatabase.instance.ref().child('users');
      final query = userRef.orderByChild('username').equalTo(username);
      final snapshot = await query.get();

      if (!snapshot.exists) {
        await userRef.push().set({
          'username': username,
          'bio': 'Semangat gowes hari ini! 🚴‍♂️',
          'photo': '',
          'status': 'Online',
          'role': 'member',
          'lastActive': ServerValue.timestamp,
          'totalDistanceKm': 0.0,
        });
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen(username: username)),
        );
      }
    } catch (e) {
      debugPrint("Login error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.directions_bike, size: 72, color: Color(0xFF00A884)),
              const SizedBox(height: 24),
              const Text('Gowes Pulen Ultimate 40+', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Ekosistem Komunitas & Chatting Sepeda', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884), foregroundColor: Colors.white),
                onPressed: _isLoading ? null : _loginWithGoogle,
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: const Text('Masuk dengan Google OAuth'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= 2. HOME SCREEN & NAVIGATION =================
class HomeScreen extends StatefulWidget {
  final String username;
  const HomeScreen({super.key, required this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      GroupChatScreen(username: widget.username),
      RideTrackerScreen(username: widget.username),
      PelotonMembersScreen(currentUsername: widget.username),
      ProfileScreen(username: widget.username),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF00A884),
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat Peloton'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Ride Tracker'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Anggota'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

// ================= 3. RIDE TRACKER & MAPS =================
class RideTrackerScreen extends StatefulWidget {
  final String username;
  const RideTrackerScreen({super.key, required this.username});

  @override
  State<RideTrackerScreen> createState() => _RideTrackerScreenState();
}

class _RideTrackerScreenState extends State<RideTrackerScreen> {
  bool _isTracking = false;
  double _distanceKm = 0.0;
  latlng.LatLng _currentPosition = const latlng.LatLng(-6.2088, 106.8456);
  List<latlng.LatLng> _routePoints = [];
  StreamSubscription<Position>? _positionStream;

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  void _toggleRideTracking() async {
    if (_isTracking) {
      _positionStream?.cancel();
      setState(() => _isTracking = false);
      _saveMileage(_distanceKm);
    } else {
      setState(() {
        _isTracking = true;
        _distanceKm = 0.0;
        _routePoints.clear();
      });
      _positionStream = Geolocator.getPositionStream().listen((Position pos) {
        latlng.LatLng newPos = latlng.LatLng(pos.latitude, pos.longitude);
        if (_routePoints.isNotEmpty) {
          double distanceMeters = Geolocator.distanceBetween(
            _routePoints.last.latitude, _routePoints.last.longitude,
            newPos.latitude, newPos.longitude,
          );
          _distanceKm += distanceMeters / 1000;
        }
        setState(() {
          _currentPosition = newPos;
          _routePoints.add(newPos);
        });
      });
    }
  }

  void _saveMileage(double dist) async {
    final userRef = FirebaseDatabase.instance.ref().child('users');
    final query = userRef.orderByChild('username').equalTo(widget.username);
    final snapshot = await query.get();
    if (snapshot.exists && snapshot.value is Map) {
      (snapshot.value as Map).forEach((key, value) {
        double current = (value['totalDistanceKm'] ?? 0.0).toDouble();
        userRef.child(key).update({'totalDistanceKm': current + dist});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Ride Tracker & GPX')),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(initialCenter: _currentPosition, initialZoom: 15.0),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              PolylineLayer(polylines: [Polyline(points: _routePoints, strokeWidth: 4.0, color: const Color(0xFF00A884))]),
              MarkerLayer(markers: [Marker(point: _currentPosition, child: const Icon(Icons.directions_bike, color: Colors.red, size: 36))]),
            ],
          ),
          Positioned(
            bottom: 20, left: 20, right: 20,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _isTracking ? Colors.red : const Color(0xFF00A884)),
              onPressed: _toggleRideTracking,
              child: Text(_isTracking ? 'SELESAI GOWES (${_distanceKm.toStringAsFixed(2)} Km)' : 'MULAI REKAM RUTE GOWES'),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= 4. GROUP CHAT SCREEN (Reactions, Edit, SOS, Media) =================
class GroupChatScreen extends StatefulWidget {
  final String username;
  const GroupChatScreen({super.key, required this.username});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('messages');

  void _sendMessage({String? textCustom, String type = 'text'}) {
    final text = textCustom ?? _msgController.text.trim();
    if (text.isEmpty) return;

    _dbRef.push().set({
      'sender': widget.username,
      'text': text,
      'type': type,
      'isRead': false,
      'timestamp': ServerValue.timestamp,
      'reactions': {},
    });
    _msgController.clear();
  }

  void _sendSos() {
    _sendMessage(textCustom: '🚨 SOS DARURAT! Butuh bantuan cepat di rute gowes!', type: 'sos');
  }

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      Uint8List bytes = await pickedFile.readAsBytes();
      _sendMessage(textCustom: base64Encode(bytes), type: 'image');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grup Peloton Gowes Pulen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.warning, color: Colors.amberAccent),
            onPressed: _sendSos,
            tooltip: 'Kirim SOS Darurat',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: _dbRef.orderByChild('timestamp').onValue,
              builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return const Center(child: Text('Belum ada pesan obrolan.', style: TextStyle(color: Colors.grey)));
                }

                final rawMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                List<Map<String, dynamic>> messages = [];
                rawMap.forEach((key, value) {
                  final map = Map<String, dynamic>.from(value as Map);
                  map['id'] = key;
                  messages.add(map);
                });
                messages.sort((a, b) => (a['timestamp'] ?? 0).compareTo(b['timestamp'] ?? 0));

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender'] == widget.username;
                    final isSos = msg['type'] == 'sos';
                    final isImage = msg['type'] == 'image';

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSos ? Colors.red[900] : (isMe ? const Color(0xFF005C4B) : const Color(0xFF1F2C34)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe) Text(msg['sender'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00A884))),
                            isImage
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(base64Decode(msg['text']), width: 180, height: 180, fit: BoxFit.cover),
                                  )
                                : Text(msg['text'], style: const TextStyle(fontSize: 14)),
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
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.image, color: Color(0xFF00A884)), onPressed: _sendImage),
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: InputDecoration(
                      hintText: 'Ketik pesan peloton...',
                      filled: true,
                      fillColor: const Color(0xFF1F2C34),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send, color: Color(0xFF00A884)), onPressed: () => _sendMessage()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================= 5. PELOTON MEMBERS & STATS =================
class PelotonMembersScreen extends StatelessWidget {
  final String currentUsername;
  const PelotonMembersScreen({super.key, required this.currentUsername});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistik & Anggota Peloton')),
      body: StreamBuilder(
        stream: FirebaseDatabase.instance.ref().child('users').onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(child: CircularIndicator());
          }
          final map = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          List<Map<String, dynamic>> users = [];
          map.forEach((key, value) {
            users.add(Map<String, dynamic>.from(value as Map));
          });

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final double dist = (user['totalDistanceKm'] ?? 0.0).toDouble();
              return ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFF00A884), child: Icon(Icons.person, color: Colors.white)),
                title: Text(user['username'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Status: ${user['status']}'),
                trailing: Text('${dist.toStringAsFixed(1)} Km', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00A884))),
              );
            },
          );
        },
      ),
    );
  }
}

// ================= 6. PROFILE & SETTINGS =================
class ProfileScreen extends StatelessWidget {
  final String username;
  const ProfileScreen({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Pengguna')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircleAvatar(radius: 40, backgroundColor: Color(0xFF00A884), child: Icon(Icons.directions_bike, size: 40, color: Colors.white)),
            const SizedBox(height: 16),
            Text(username, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('Mode Gelap (Dark Mode)'),
              value: themeNotifier.isDarkMode,
              activeColor: const Color(0xFF00A884),
              onChanged: (val) => themeNotifier.toggleTheme(),
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800], foregroundColor: Colors.white),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('current_username');
                await GoogleSignIn().signOut();
                if (context.mounted) {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AuthScreen()));
                }
              },
              child: const Text('Keluar Akun'),
            ),
          ],
        ),
      ),
    );
  }
}

class CircularIndicator extends StatelessWidget {
  const CircularIndicator({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator(color: Color(0xFF00A884)));
}
