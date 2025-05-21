import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter API Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter API Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<dynamic> _data = []; // To store API data
  bool _isLoading = false; // To show loading state
  String _errorMessage = ''; // To handle errors

  @override
  void initState() {
    super.initState();
    _fetchData(); // Fetch data when the widget is initialized
  }

  // Function to fetch data from the API
  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true; // Show loading indicator
      _errorMessage = ''; // Reset error message
    });

    try {
      final response = await http.get(Uri.parse(
          'https://script.google.com/macros/s/AKfycbxRZrJJ92BzOYTBd-mbCiyO2lqayIvPRIGBRWNdTBYlylndbJYRZVZN_ZR1KiIFoqszPA/exec'));

      if (response.statusCode == 200) {
        // Parse JSON data
        final List<dynamic> fetchedData = jsonDecode(response.body);
        setState(() {
          _data = fetchedData; // Store the data
          _isLoading = false; // Hide loading indicator
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load data: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) // Show loading indicator
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage)) // Show error message
              : _data.isEmpty
                  ? const Center(child: Text('No data available'))
                  : ListView.builder(
                      itemCount: _data.length,
                      itemBuilder: (context, index) {
                        // Assuming each item in _data is a Map with a 'name' field
                        // Adjust this based on your API's response structure
                        return ListTile(
                          title: Text(_data[index]['name']?.toString() ?? 'No Name'),
                          subtitle: Text('Index: $index'), // Customize as needed
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchData, // Re-fetch data when pressed
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}