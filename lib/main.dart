import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Character {
  final String url;
  final String name;
  final String gender;
  final String culture;
  final String born;

  Character({
    required this.url,
    required this.name,
    required this.gender,
    required this.culture,
    required this.born,
  });

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      url: json['url'] ?? '',
      name: (json['name'] != null && json['name'].toString().isNotEmpty)
          ? json['name']
          : 'Unknown',
      gender: json['gender'] ?? 'Unknown',
      culture: json['culture'] ?? 'Unknown',
      born: json['born'] ?? 'Unknown',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Character && other.url == url;
  @override
  int get hashCode => url.hashCode;
}

Future<List<Character>> fetchCharacters({int page = 1, int pageSize = 10}) async {
  final response = await http.get(Uri.parse('https://anapioficeandfire.com/api/characters?page=$page&pageSize=$pageSize'));
  if (response.statusCode == 200) {
    List data = json.decode(response.body);
    return data.map((json) => Character.fromJson(json)).toList();
  } else {
    throw Exception('Error loading characters');
  }
}

Future<Character> fetchRandomCharacter() async {
  final random = Random();
  int page = random.nextInt(10) + 1;
  int pageSize = 20;
  List<Character> characters = await fetchCharacters(page: page, pageSize: pageSize);
  if (characters.isNotEmpty) {
    return characters[random.nextInt(characters.length)];
  } else {
    throw Exception('No characters found');
  }
}

class GameOfThronesApp extends StatefulWidget {
  @override
  _GameOfThronesAppState createState() => _GameOfThronesAppState();
}

class _GameOfThronesAppState extends State<GameOfThronesApp> {
  int _selectedIndex = 0;
  List<Character> favorites = [];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void toggleFavorite(Character character) {
    setState(() {
      if (favorites.contains(character)) {
        favorites.remove(character);
      } else {
        favorites.add(character);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personajes Juego de Tronos',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.red,
        fontFamily: 'GameOfThrones',
      ),
      home: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text('Personajes Juego de Tronos'),
          ),
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            DestacadoScreen(toggleFavorite: toggleFavorite, favorites: favorites),
            ListadoScreen(toggleFavorite: toggleFavorite, favorites: favorites),
            FavoritosScreen(favorites: favorites, toggleFavorite: toggleFavorite),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: [
            // Se reemplazan los iconos por un widget vacío para que no se muestren
            BottomNavigationBarItem(icon: SizedBox.shrink(), label: 'Destacado'),
            BottomNavigationBarItem(icon: SizedBox.shrink(), label: 'Listado'),
            BottomNavigationBarItem(icon: SizedBox.shrink(), label: 'Favoritos'),
          ],
        ),
      ),
    );
  }
}

class DestacadoScreen extends StatefulWidget {
  final Function(Character) toggleFavorite;
  final List<Character> favorites;
  DestacadoScreen({required this.toggleFavorite, required this.favorites});

  @override
  _DestacadoScreenState createState() => _DestacadoScreenState();
}

class _DestacadoScreenState extends State<DestacadoScreen> {
  late Future<Character> randomCharacter;
  @override
  void initState() {
    super.initState();
    randomCharacter = fetchRandomCharacter();
  }
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Character>(
      future: randomCharacter,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            decoration: backgroundDecoration(),
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Container(
            decoration: backgroundDecoration(),
            child: Center(child: Text('Error: ${snapshot.error}')),
          );
        } else if (snapshot.hasData) {
          final character = snapshot.data!;
          bool isFav = widget.favorites.contains(character);
          return Container(
            decoration: backgroundDecoration(),
            child: ResponsiveDetail(
              character: character,
              toggleFavorite: () {
                widget.toggleFavorite(character);
                setState(() {});
              },
              isFavorite: isFav,
            ),
          );
        } else {
          return Container(
            decoration: backgroundDecoration(),
            child: Center(child: Text('No data')),
          );
        }
      },
    );
  }
}

class ListadoScreen extends StatefulWidget {
  final Function(Character) toggleFavorite;
  final List<Character> favorites;
  ListadoScreen({required this.toggleFavorite, required this.favorites});

  @override
  _ListadoScreenState createState() => _ListadoScreenState();
}

class _ListadoScreenState extends State<ListadoScreen> {
  List<Character> characters = [];
  bool isLoading = false;
  int currentPage = 1;
  final int pageSize = 10;
  bool hasMore = true;

  @override
  void initState() {
    super.initState();
    fetchNextPage();
  }

  Future<void> fetchNextPage() async {
    if (isLoading || !hasMore) return;
    setState(() { isLoading = true; });
    try {
      List<Character> newCharacters = await fetchCharacters(page: currentPage, pageSize: pageSize);
      setState(() {
        if (newCharacters.length < pageSize) hasMore = false;
        characters.addAll(newCharacters);
        currentPage++;
      });
    } catch (e) {
      // Manejo de error
    } finally {
      setState(() { isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: backgroundDecoration(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          if (!isLoading && hasMore && scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
            fetchNextPage();
          }
          return false;
        },
        child: ListView.builder(
          itemCount: characters.length + (hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == characters.length) {
              return Center(child: CircularProgressIndicator());
            }
            final character = characters[index];
            bool isFav = widget.favorites.contains(character);
            return Container(
              margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                title: Text(character.name, style: TextStyle(color: Colors.red)),
                subtitle: Text(character.gender, style: TextStyle(color: Colors.white)),
                // Se eliminó el icono de favorito
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CharacterDetailScreen(
                        character: character,
                        toggleFavorite: widget.toggleFavorite,
                        favorites: widget.favorites,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class FavoritosScreen extends StatelessWidget {
  final List<Character> favorites;
  final Function(Character) toggleFavorite;
  FavoritosScreen({required this.favorites, required this.toggleFavorite});

  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) {
      return Container(
        decoration: backgroundDecoration(),
        child: Center(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'No hay favoritos',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ),
      );
    }
    return Container(
      decoration: backgroundDecoration(),
      child: ListView.builder(
        itemCount: favorites.length,
        itemBuilder: (context, index) {
          final character = favorites[index];
          return Container(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              title: Text(character.name, style: TextStyle(color: Colors.white)),
              subtitle: Text(character.gender, style: TextStyle(color: Colors.white)),
              // Se eliminó el icono de favorito
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CharacterDetailScreen(
                      character: character,
                      toggleFavorite: toggleFavorite,
                      favorites: favorites,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class CharacterDetailScreen extends StatefulWidget {
  final Character character;
  final Function(Character) toggleFavorite;
  final List<Character> favorites;
  CharacterDetailScreen({required this.character, required this.toggleFavorite, required this.favorites});

  @override
  _CharacterDetailScreenState createState() => _CharacterDetailScreenState();
}

class _CharacterDetailScreenState extends State<CharacterDetailScreen> {
  bool get isFavorite => widget.favorites.contains(widget.character);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.character.name)),
      body: Container(
        decoration: backgroundDecoration(),
        child: ResponsiveDetail(
          character: widget.character,
          toggleFavorite: () {
            widget.toggleFavorite(widget.character);
            setState(() {});
          },
          isFavorite: isFavorite,
        ),
      ),
    );
  }
}

class ResponsiveDetail extends StatelessWidget {
  final Character character;
  final Function() toggleFavorite;
  final bool isFavorite;
  ResponsiveDetail({required this.character, required this.toggleFavorite, required this.isFavorite});

  @override
  Widget build(BuildContext context) {
    Widget content = SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: buildCharacterDetails()),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        return constraints.maxWidth < 600
            ? content
            : Center(child: Container(width: 600, padding: const EdgeInsets.all(16.0), child: Card(child: content)));
      },
    );
  }

  List<Widget> buildCharacterDetails() {
    return [
      Text('Name: ${character.name}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      SizedBox(height: 10),
      Text('Gender: ${character.gender}', style: TextStyle(fontSize: 18)),
      SizedBox(height: 10),
      Text('Culture: ${character.culture}', style: TextStyle(fontSize: 18)),
      SizedBox(height: 10),
      Text('Born: ${character.born}', style: TextStyle(fontSize: 18)),
      SizedBox(height: 20),
      // Se reemplaza ElevatedButton.icon por ElevatedButton sin icono
      ElevatedButton(
        onPressed: toggleFavorite,
        child: Text(isFavorite ? 'Remove Favorite' : 'Add to Favorites'),
      )
    ];
  }
}

BoxDecoration backgroundDecoration() {
  return BoxDecoration(
    image: DecorationImage(
      image: AssetImage('assets/images/dragon.jpg'),
      fit: BoxFit.cover,
    ),
  );
}

void main() => runApp(GameOfThronesApp());