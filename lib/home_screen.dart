import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:mobile_evaluation/DB_files/sqlite_db.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late TextEditingController _searchController;
  String _searchText = '';

  bool _isConnectionSuccessful = true;

  @override
  void initState() {
    super.initState();
    _tryConnection();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  Future<bool> _tryConnection() async {
    try {
      final response = await InternetAddress.lookup('Example.com');

      setState(() {
        _isConnectionSuccessful = response.isNotEmpty;
      });
    } on SocketException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );

      setState(() {
        _isConnectionSuccessful = false;
      });
    }
    if (_isConnectionSuccessful != true) {
      if (!mounted) {}
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please check your internet connection to load recipes from official site",
          ),
        ),
      );
    }
    return _isConnectionSuccessful;
  }

  Future<List<dynamic>> fetchRandomRecipes({String? searchText}) async {
    try {
      final queryParameters = {
        'number': '10',
        'apiKey': 'cd4226ea80b34a95afceb5fa01325912',
        if (_searchText != '') 'query': _searchText,
      };
      final uri = Uri.https(
        'api.spoonacular.com',
        '/recipes/random',
        queryParameters,
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body)['recipes'];

        // Saving the fetched data to SQLite
        await RecipeDatabase.saveRecipes(data);

        return data;
      } else {
        throw Exception('Failed to load recipes');
      }
    } catch (e) {
       SnackBar(
        content: Text(
          "Error fetching and saving recipes: $e",
        ),
      );

      return []; // Return an empty list to indicate that there was an error
    }
  }

  Future<List<dynamic>> fetchRecipes({String? searchText}) async {
    if (_isConnectionSuccessful == true) {
      try {
        final fetchedRecipes =
        await fetchRandomRecipes(searchText: searchText);
        await RecipeDatabase.saveRecipes(fetchedRecipes);
        return fetchedRecipes;
      } catch (e) {
        SnackBar(
          content: Text(
            "Error fetching and saving recipes: $e",
          ),
        );

        return await RecipeDatabase.getRecipes();
      }
    } else {
      return await RecipeDatabase.getRecipes();
    }
  }

  Future<List<dynamic>> loadSavedRecipes() async {
    try {
      final recipes = await RecipeDatabase.getRecipes();
      return recipes;
    } catch (e) {
      SnackBar(
        content: Text(
          "Error loading saved recipes: $e",
        ),
      );
      return []; // Return an empty list to indicate that there was an error
    }
  }


  Widget randomRecipes() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search for recipes...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchText = '';
                  });
                },
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchText = value;
              });
            },
          ),
        ),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: fetchRecipes(searchText: _searchText),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final recipes = snapshot.data!;
                if (_searchText.isNotEmpty) {
                  // filter the list of recipes based on the search query
                  final filteredRecipes = recipes.where((recipe) =>
                      recipe['title'].toString().toLowerCase().contains(_searchText.toLowerCase())
                  ).toList();
                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: filteredRecipes.length,
                    itemBuilder: (context, index) {
                      final recipe = filteredRecipes[index];
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Card(
                          elevation: 2.0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(10.0),
                                    topRight: Radius.circular(10.0),
                                  ),
                                  child:
                                  recipe['image'] != null?
                                  Image.network(
                                    recipe['image'],
                                    fit: BoxFit.fill,
                                  ):
                                  Image.asset("assets/images/No_image_available.svg.png"),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    SizedBox(
                                      height: 45,
                                      child: Text(
                                        recipe['title'],
                                        style: const TextStyle(
                                          fontSize: 10.0,
                                          fontWeight: FontWeight.bold,
                                          overflow: TextOverflow.visible,


                                        ),
                                        maxLines: 2,

                                      ),
                                    ),
                                    const SizedBox(height: 4.0),
                                    FittedBox(
                                      child: Text(
                                        'Ready in ${recipe['readyInMinutes']} minutes',
                                        style: TextStyle(
                                          fontSize: 8.0,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                      // ...
                    },
                  );
                } else {
                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final recipe = snapshot.data![index];
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Card(
                          elevation: 2.0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(10.0),
                                    topRight: Radius.circular(10.0),
                                  ),
                                  child:
                                  recipe['image'] != null?
                                      Image.network(
                                    recipe['image'],
                                    fit: BoxFit.fill,
                                  ):
                                      Image.asset("assets/images/No_image_available.svg.png"),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    SizedBox(
                                      height: 45,
                                      child: Text(
                                        recipe['title'],
                                        style: const TextStyle(
                                          fontSize: 10.0,
                                          fontWeight: FontWeight.bold,
                                          overflow: TextOverflow.visible,


                                        ),
                                        maxLines: 2,

                                      ),
                                    ),
                                    const SizedBox(height: 4.0),
                                    FittedBox(
                                      child: Text(
                                        'Ready in ${recipe['readyInMinutes']} minutes',
                                        style: TextStyle(
                                          fontSize: 8.0,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }
              } else if (snapshot.hasError) {
                return Text('${snapshot.error}');
              } else {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spoonacular Recipes'),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: randomRecipes()
      ),
    );
  }
}
