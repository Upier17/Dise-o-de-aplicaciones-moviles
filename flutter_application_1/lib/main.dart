import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'PokeApp',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 2, 34, 15),
          ),
          useMaterial3: true,
        ),
        home: MyHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  String pokemonName = "";
  String pokemonImage = "";
  bool isLoading = false;

  // ✅ Cambiado a dynamic para evitar conflictos con Firestore
  List<Map<String, dynamic>> favorites = [];

  final firestore = FirebaseFirestore.instance;

  MyAppState() {
    loadFavorites();
  }

  Future<void> fetchPokemon() async {
    isLoading = true;
    notifyListeners();

    final randomId = DateTime.now().millisecondsSinceEpoch % 151 + 1;
    final url = Uri.parse('https://pokeapi.co/api/v2/pokemon/$randomId');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      pokemonName = data['name'];
      pokemonImage = data['sprites']['front_default'];
    } else {
      pokemonName = "Error al cargar Pokémon";
      pokemonImage = "";
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> addFavorite(String name, String image) async {
    final doc = await firestore.collection('favorites').add({
      'name': name,
      'image': image,
    });
    favorites.add({'name': name, 'image': image, 'id': doc.id});
    notifyListeners();
  }

  Future<void> removeFavorite(String id) async {
    await firestore.collection('favorites').doc(id).delete();
    favorites.removeWhere((f) => f['id'] == id);
    notifyListeners();
  }

  Future<void> loadFavorites() async {
    final snapshot = await firestore.collection('favorites').get();
    favorites = snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        'name': doc['name'],
        'image': doc['image'],
      };
    }).toList();
    notifyListeners();
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (selectedIndex) {
      case 0:
        page = GeneratorPage();
        break; 
      case 1:
        page = FavoritesPage();
        break; 
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }

    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            child: NavigationRail(
              extended: false,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.favorite),
                  label: Text('Favorites'),
                ),
              ],
              selectedIndex: selectedIndex,
              onDestinationSelected: (value) {
                setState(() {
                  selectedIndex = value;
                });
              },
            ),
          ),
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: page,
            ),
          ),
        ],
      ),
    );
  }
}

class GeneratorPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (appState.isLoading)
            const CircularProgressIndicator()
          else if (appState.pokemonName.isNotEmpty)
            BigCard(
              name: appState.pokemonName,
              imageUrl: appState.pokemonImage,
              onFavorite: () {
                appState.addFavorite(appState.pokemonName, appState.pokemonImage);
              },
            )
          else
            const Text(
              "Presiona el botón para descubrir un Pokémon",
              style: TextStyle(fontSize: 18),
            ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              appState.fetchPokemon();
            },
            child: const Text('Obtener Pokémon'),
          ),
        ],
      ),
    );
  }
}

class BigCard extends StatelessWidget {
  final String name;
  final String imageUrl;
  final VoidCallback? onFavorite;

  const BigCard({
    super.key,
    required this.name,
    required this.imageUrl,
    this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style =
        theme.textTheme.displayMedium!.copyWith(color: theme.colorScheme.onPrimary);

    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (imageUrl.isNotEmpty)
              Image.network(imageUrl, width: 150, height: 150),
            const SizedBox(height: 10),
            Text(
              name.toUpperCase(),
              style: style,
            ),
            if (onFavorite != null)
              IconButton(
                icon: const Icon(Icons.favorite_border),
                color: Colors.red,
                onPressed: onFavorite,
              ),
          ],
        ),
      ),
    );
  }
}

class FavoritesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    if (appState.favorites.isEmpty) {
      return const Center(
        child: Text('No favorites yet.'),
      );
    }

    return ListView(
      children: appState.favorites.map((f) {
        return ListTile(
          leading: Image.network(f['image']),
          title: Text(f['name']),
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              appState.removeFavorite(f['id']);
            },
          ),
        );
      }).toList(),
    );
  }
}
