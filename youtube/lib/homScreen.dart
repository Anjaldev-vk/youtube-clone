import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:share_plus/share_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: const MyApp(),
    ),
  );
}

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  ThemeNotifier() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setAutoTheme();
    });
  }

  void _setAutoTheme() {
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _themeMode = brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    return MaterialApp(
      title: 'YouTube',
      theme: ThemeData.light().copyWith(
        primaryColor: Colors.white,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF212121),
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF212121),
        ),
      ),
      themeMode: themeNotifier.themeMode,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  List<dynamic> videos = [];
  List<dynamic> shorts = [];
  bool isLoading = true;
  String query = '';
  final TextEditingController _searchController = TextEditingController();
  List<String> history = [];
  List<String> likedVideos = [];
  List<String> watchLaterVideos = [];
  late stt.SpeechToText _speech;
  bool _isListening = false;
  final ScrollController _scrollController = ScrollController();

  static const String apiKey = 'AIzaSyDhr_5AgiRmlA21tuDUNX250PgWxocuCvw';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    fetchTrendingVideos();
    fetchShorts();
    _speech = stt.SpeechToText();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      history = prefs.getStringList('history') ?? [];
      likedVideos = prefs.getStringList('liked') ?? [];
      watchLaterVideos = prefs.getStringList('watchLater') ?? [];
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('history', history);
    await prefs.setStringList('liked', likedVideos);
    await prefs.setStringList('watchLater', watchLaterVideos);
  }

  Future<Map<String, dynamic>> fetchVideoDetails(String videoId) async {
    final url = 'https://www.googleapis.com/youtube/v3/videos?part=snippet&id=$videoId&key=$apiKey';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['items'].isNotEmpty) {
        return data['items'][0];
      }
    }
    return {};
  }

  Future<void> fetchTrendingVideos() async {
    setState(() => isLoading = true);
    try {
      final apiUrl =
          'https://www.googleapis.com/youtube/v3/videos?part=snippet&chart=mostPopular&regionCode=US&maxResults=10&key=$apiKey';

      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          videos = data['items'];
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load videos.');
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> fetchShorts() async {
    try {
      final apiUrl =
          'https://www.googleapis.com/youtube/v3/search?part=snippet&q=shorts&type=video&maxResults=10&key=$apiKey';

      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          shorts = data['items'];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading shorts: ${e.toString()}')),
      );
    }
  }

  Future<void> searchVideos(String keyword) async {
    setState(() => isLoading = true);
    try {
      final apiUrl =
          'https://www.googleapis.com/youtube/v3/search?part=snippet&q=$keyword&type=video&maxResults=10&key=$apiKey';

      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          videos = data['items'];
          isLoading = false;
        });
      } else {
        throw Exception('Search failed.');
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search Error: ${e.toString()}')),
      );
    }
  }

  void onSearchSubmitted(String value) {
    query = value.trim();
    if (query.isNotEmpty) {
      searchVideos(query);
    } else {
      fetchTrendingVideos();
    }
  }

  void _addToHistory(String id) {
    if (!history.contains(id)) {
      setState(() {
        history.add(id);
        _savePreferences();
      });
    }
  }

  void _toggleLike(String id) {
    setState(() {
      likedVideos.contains(id) ? likedVideos.remove(id) : likedVideos.add(id);
      _savePreferences();
    });
  }

  void _toggleWatchLater(String id) {
    setState(() {
      watchLaterVideos.contains(id)
          ? watchLaterVideos.remove(id)
          : watchLaterVideos.add(id);
      _savePreferences();
    });
  }

  void _listenToVoice() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            _searchController.text = val.recognizedWords;
            if (val.finalResult) {
              _speech.stop();
              setState(() => _isListening = false);
              onSearchSubmitted(val.recognizedWords);
            }
          },
        );
      }
    } else {
      _speech.stop();
      setState(() => _isListening = false);
    }
  }

  Widget _buildLibraryList(String title, List<String> ids) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Future.wait(ids.map((id) => fetchVideoDetails(id))),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final items = snapshot.data!.where((v) => v.isNotEmpty).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ...items.map((video) {
              final id = video['id'];
              final snippet = video['snippet'];
              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.network(
                    snippet['thumbnails']['default']['url'],
                    width: 120,
                    height: 90,
                    fit: BoxFit.cover,
                  ),
                ),
                title: Text(snippet['title'], maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(snippet['channelTitle']),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoPlayerPage(
                        videoId: id is Map ? id['videoId'] ?? id['videoId'] : id,
                        title: snippet['title'],
                      ),
                    ),
                  );
                },
              );
            }),
            const Divider(),
          ],
        );
      },
    );
  }

  Widget _buildLibraryContent() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        if (history.isNotEmpty) _buildLibraryList('Watch History', history),
        if (likedVideos.isNotEmpty) _buildLibraryList('Liked Videos', likedVideos),
        if (watchLaterVideos.isNotEmpty) _buildLibraryList('Watch Later', watchLaterVideos),
        if (history.isEmpty && likedVideos.isEmpty && watchLaterVideos.isEmpty)
          const Center(child: Text('Your Library is empty')),
      ],
    );
  }

  Widget _buildShortsContent() {
    return ListView.builder(
      itemCount: shorts.length,
      itemBuilder: (context, index) {
        final short = shorts[index];
        final videoId = short['id']['videoId'];
        final title = short['snippet']['title'];
        final thumbnail = short['snippet']['thumbnails']['high']['url'];
        final views = '1.2M views';

        return Container(
          height: 500,
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
          child: Stack(
            children: [
              // Short video thumbnail
              GestureDetector(
                onTap: () {
                  _addToHistory(videoId);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoPlayerPage(videoId: videoId, title: title),
                    ),
                  );
                },
                child: Image.network(
                  thumbnail,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              // Video info overlay
              Positioned(
                bottom: 20,
                left: 10,
                right: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      views,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // Right side action buttons
              Positioned(
                bottom: 100,
                right: 10,
                child: Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.thumb_up, color: Colors.white),
                      onPressed: () => _toggleLike(videoId),
                    ),
                    Text(
                      '12K',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    IconButton(
                      icon: const Icon(Icons.thumb_down, color: Colors.white),
                      onPressed: () {},
                    ),
                    const SizedBox(height: 20),
                    IconButton(
                      icon: const Icon(Icons.comment, color: Colors.white),
                      onPressed: () {},
                    ),
                    Text(
                      '1.2K',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.white),
                      onPressed: () {
                        Share.share('https://youtube.com/shorts/$videoId');
                      },
                    ),
                    const SizedBox(height: 20),
                    const CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, size: 20, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileContent() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text('Username', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('user@example.com', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white, backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Edit Profile'),
            ),
          ],
        ),
      );

  Widget _buildVideoCard(dynamic video) {
    final videoId = video['id'] is String
        ? video['id']
        : video['id']['videoId'] ?? video['id'];
    final title = video['snippet']['title'];
    final thumbnail = video['snippet']['thumbnails']['high']['url'];
    final channelTitle = video['snippet']['channelTitle'];
    final publishedAt = video['snippet']['publishedAt'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: () {
                  _addToHistory(videoId);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoPlayerPage(videoId: videoId, title: title),
                    ),
                  );
                },
                child: Image.network(
                  thumbnail,
                  width: double.infinity,
                  height: 200.0,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                bottom: 8.0,
                right: 8.0,
                child: Container(
                  padding: const EdgeInsets.all(4.0),
                  color: Colors.black.withOpacity(0.7),
                  child: const Text(
                    '10:30',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$channelTitle • 1.2M views • ${_formatDate(publishedAt)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => _buildVideoOptionsSheet(videoId),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoOptionsSheet(String videoId) {
    return Container(
      height: 300,
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        children: [
          _buildOptionTile(Icons.share, 'Share', () {
            Share.share('https://youtu.be/$videoId');
            Navigator.pop(context);
          }),
          _buildOptionTile(
            likedVideos.contains(videoId) ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
            likedVideos.contains(videoId) ? 'Liked' : 'Like',
            () {
              _toggleLike(videoId);
              Navigator.pop(context);
            },
          ),
          _buildOptionTile(
            watchLaterVideos.contains(videoId) ? Icons.watch_later : Icons.watch_later_outlined,
            watchLaterVideos.contains(videoId) ? 'Saved to Watch later' : 'Save to Watch later',
            () {
              _toggleWatchLater(videoId);
              Navigator.pop(context);
            },
          ),
          _buildOptionTile(Icons.playlist_add, 'Save to playlist', () {}),
          _buildOptionTile(Icons.flag, 'Report', () {}),
          _buildOptionTile(Icons.notifications_none, 'Not interested', () {}),
        ],
      ),
    );
  }

  Widget _buildOptionTile(IconData icon, String text, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(text),
      onTap: onTap,
    );
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} years ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildAppBar() {
    return AppBar(
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Image.asset(
          'assets/Youtube.png', // Replace with your actual YouTube logo asset
          height: 24,
        ),
      ),
      title: SizedBox(
        height: 40,
        child: TextField(
          controller: _searchController,
          onSubmitted: onSearchSubmitted,
          decoration: InputDecoration(
            hintText: 'Search',
            hintStyle: const TextStyle(color: Colors.black),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20.0),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.grey[200],
            contentPadding: const EdgeInsets.only(left: 16.0),
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => onSearchSubmitted(_searchController.text),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.mic),
          onPressed: _listenToVoice,
        ),
        IconButton(
          icon: const Icon(Icons.video_call),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.notifications_none),
          onPressed: () {},
        ),
        IconButton(
          icon: const CircleAvatar(
            radius: 14,
            backgroundColor: Colors.grey,
            child: Icon(Icons.person, size: 16, color: Colors.white),
          ),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildCategoryChips() {
    final categories = ['All', 'Music', 'Gaming', 'News', 'Live', 'Cooking', 'Recently uploaded'];
    return Container(
      height: 50,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            child: ChoiceChip(
              label: Text(
                categories[index],
                style: const TextStyle(color: Colors.black),
              ),
              selected: index == 0,
              selectedColor: Colors.grey[700],
              labelStyle: TextStyle(
                color: index == 0 ? Colors.white : Colors.white,
              ),
              onSelected: (selected) {},
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: _buildAppBar(),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_selectedIndex == 0) _buildCategoryChips(),
                Expanded(
                  child: _selectedIndex == 0
                      ? ListView.builder(
                          itemCount: videos.length,
                          itemBuilder: (context, index) => _buildVideoCard(videos[index]),
                        )
                      : (_selectedIndex == 1
                          ? _buildShortsContent()
                          : (_selectedIndex == 4
                              ? _buildLibraryContent()
                              : _buildProfileContent())),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        onTap: (int index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle_outline),
            activeIcon: Icon(Icons.play_circle),
            label: 'Shorts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'Create',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.subscriptions_outlined),
            activeIcon: Icon(Icons.subscriptions),
            label: 'Subscriptions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library_outlined),
            activeIcon: Icon(Icons.video_library),
            label: 'Library',
          ),
        ],
      ),
    );
  }
}

class VideoPlayerPage extends StatefulWidget {
  final String videoId;
  final String title;

  const VideoPlayerPage({super.key, required this.videoId, required this.title});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late YoutubePlayerController _controller;
  List<dynamic> relatedVideos = [];
  int currentVideoIndex = -1;
  bool _isLiked = false;
  bool _isDisliked = false;
  bool _isSubscribed = false;
  bool _showMoreDescription = false;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: true,
        forceHD: true,
      ),
    );

    fetchRelatedVideos().then((videos) {
      setState(() {
        relatedVideos = videos;
        currentVideoIndex = videos.indexWhere(
            (v) => v['id']['videoId'] == widget.videoId);
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _seekForward() {
    final current = _controller.value.position;
    _controller.seekTo(current + const Duration(seconds: 10));
  }

  void _seekBackward() {
    final current = _controller.value.position;
    _controller.seekTo(current - const Duration(seconds: 10));
  }

  void _playNextVideo() {
    if (currentVideoIndex + 1 < relatedVideos.length) {
      final nextVideo = relatedVideos[currentVideoIndex + 1];
      final nextId = nextVideo['id']['videoId'];
      final nextTitle = nextVideo['snippet']['title'];

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerPage(videoId: nextId, title: nextTitle),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No more videos available.')),
      );
    }
  }

  void _playPreviousVideo() {
    if (currentVideoIndex > 0) {
      final prevVideo = relatedVideos[currentVideoIndex - 1];
      final prevId = prevVideo['id']['videoId'];
      final prevTitle = prevVideo['snippet']['title'];

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerPage(videoId: prevId, title: prevTitle),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No previous video available.')),
      );
    }
  }

  Future<List<dynamic>> fetchRelatedVideos() async {
    const apiKey = 'AIzaSyDhr_5AgiRmlA21tuDUNX250PgWxocuCvw';
    final url =
        'https://www.googleapis.com/youtube/v3/search?relatedToVideoId=${widget.videoId}&type=video&part=snippet&maxResults=10&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['items'];
    } else {
      return [];
    }
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, size: 24),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildVideoInfo() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '1.2M views • 2 days ago',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isLiked = !_isLiked;
                        if (_isLiked) _isDisliked = false;
                      });
                    },
                    child: _buildActionButton(
                      _isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                      _isLiked ? '1.2K' : 'Like',
                    ),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isDisliked = !_isDisliked;
                        if (_isDisliked) _isLiked = false;
                      });
                    },
                    child: _buildActionButton(
                      _isDisliked ? Icons.thumb_down : Icons.thumb_down_alt_outlined,
                      'Dislike',
                    ),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () {
                      Share.share('https://youtu.be/${widget.videoId}');
                    },
                    child: _buildActionButton(Icons.share, 'Share'),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () {
                      // Handle save to playlist
                    },
                    child: _buildActionButton(Icons.playlist_add, 'Save'),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  // Handle more options
                },
                child: const Icon(Icons.more_vert),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Channel Name',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '1.5M subscribers',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isSubscribed = !_isSubscribed;
                  });
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: _isSubscribed ? Colors.grey : Colors.white,
                  backgroundColor: _isSubscribed ? Colors.grey[300] : Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.0),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Text(_isSubscribed ? 'SUBSCRIBED' : 'SUBSCRIBE'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              setState(() {
                _showMoreDescription = !_showMoreDescription;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '123K views • Premiered 2 days ago',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _showMoreDescription
                      ? 'This is the full description of the video. It contains all the details about the content, links, and other information. '
                        'You can see more details when you expand this section.'
                      : 'This is the full description of the video...',
                    maxLines: _showMoreDescription ? null : 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _showMoreDescription ? 'Show less' : 'Show more',
                    style: const TextStyle(
                        color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Comments • 1.2K',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              const Icon(Icons.sort, size: 20),
              const SizedBox(width: 8),
              Text('Sort by', style: TextStyle(color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    border: UnderlineInputBorder(
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Colors.red,
        progressColors: const ProgressBarColors(
          playedColor: Colors.red,
          handleColor: Colors.red,
        ),
        bottomActions: [
          IconButton(onPressed: _playPreviousVideo, icon: const Icon(Icons.skip_previous)),
          IconButton(onPressed: _seekBackward, icon: const Icon(Icons.replay_10)),
          const SizedBox(width: 4),
          const CurrentPosition(),
          const ProgressBar(isExpanded: true),
          const PlaybackSpeedButton(),
          const SizedBox(width: 4),
          IconButton(onPressed: _seekForward, icon: const Icon(Icons.forward_10)),
          IconButton(onPressed: _playNextVideo, icon: const Icon(Icons.skip_next)),
          const FullScreenButton(),
        ],
      ),
      builder: (context, player) {
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    player,
                    _buildVideoInfo(),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Text(
                        'Up next',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Autoplay'),
                      ),
                      const Icon(Icons.toggle_on, color: Colors.red),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final video = relatedVideos[index];
                    final videoId = video['id']['videoId'];
                    final title = video['snippet']['title'];
                    final thumbnail = video['snippet']['thumbnails']['medium']['url'];
                    final channelTitle = video['snippet']['channelTitle'];
                    final views = '1.2M views';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.network(
                          thumbnail,
                          width: 120,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text('$channelTitle • $views'),
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VideoPlayerPage(videoId: videoId, title: title),
                          ),
                        );
                      },
                    );
                  },
                  childCount: relatedVideos.length,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}