import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:io';

void main() {
  runApp(const YhaCoderLeaderboardApp());
}

class YhaCoderLeaderboardApp extends StatelessWidget {
  const YhaCoderLeaderboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YHA Coder Leaderboard',
      theme: ThemeData(
        primaryColor: const Color(0xFFFF6200),
        scaffoldBackgroundColor: const Color(0xFF2B1A0D),
        textTheme: GoogleFonts.orbitronTextTheme(),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFFF6200),
          secondary: const Color(0xFFFF8C00),
        ),
      ),
      darkTheme: ThemeData(
        primaryColor: const Color(0xFFFF6200),
        scaffoldBackgroundColor: const Color(0xFF2B1A0D),
        textTheme: GoogleFonts.orbitronTextTheme(),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFFF6200),
          secondary: const Color(0xFFFF8C00),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const LeaderboardScreen(),
    );
  }
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  _LeaderboardScreenState createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<dynamic> leaderboardData = [];
  List<dynamic> filteredData = [];
  String sortColumn = 'rank';
  bool sortAscending = true;
  bool isLoading = true;
  String? errorMessage;
  bool isDarkMode = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTheme();
    fetchLeaderboard();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = prefs.getBool('darkMode') ?? true;
    });
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = !isDarkMode;
      prefs.setBool('darkMode', isDarkMode);
    });
  }

  Future<void> fetchLeaderboard() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final response = await http.get(Uri.parse(
          'https://script.google.com/macros/s/AKfycbyVAV8QIzzphbtZZGPK7-qfKpwbcEjGcuYwmSSZ6Qydg2slaMAQ6N2lUChYZhL12b6_3Q/exec'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Validate and filter valid entries
        final validData = data.where((user) {
          try {
            // Ensure required fields exist and rank is parseable
            final rank = user['rank']?.toString() ?? '';
            final digits = rank.replaceAll(RegExp(r'[^\d\s]'), '').trim();
            num.tryParse(digits);
            return user['name'] != null && user['points'] != null && user['averages'] != null;
          } catch (e) {
            print('Invalid user data: $user, error: $e');
            return false;
          }
        }).toList();
        setState(() {
          leaderboardData = validData;
          filteredData = validData;
          isLoading = false;
          _sortData();
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load data: $e';
      });
    }
  }

  void _sortData() {
    filteredData.sort((a, b) {
      var valueA = a[sortColumn];
      var valueB = b[sortColumn];
      if (sortColumn == 'rank') {
        // Extract digits from rank, handling emojis and spaces
        try {
          // Remove all non-digits, trim spaces, and handle Unicode
          final digitsA = valueA.toString().replaceAll(RegExp(r'[^\d\s]'), '').trim();
          final digitsB = valueB.toString().replaceAll(RegExp(r'[^\d\s]'), '').trim();
          valueA = num.tryParse(digitsA) ?? 999999;
          valueB = num.tryParse(digitsB) ?? 999999;
        } catch (e) {
          // Log error for debugging
          print('Error parsing rank: $valueA vs $valueB, error: $e');
          valueA = 999999;
          valueB = 999999;
        }
      } else if (sortColumn == 'points' || sortColumn == 'averages') {
        valueA = num.tryParse(valueA.toString()) ?? 0;
        valueB = num.tryParse(valueB.toString()) ?? 0;
      } else {
        valueA = valueA.toString().toLowerCase();
        valueB = valueB.toString().toLowerCase();
      }
      return sortAscending
          ? (valueA.compareTo(valueB))
          : (valueB.compareTo(valueA));
    });
  }

  void _filterData(String query) {
    setState(() {
      filteredData = leaderboardData.where((user) {
        return user['name'].toString().toLowerCase().contains(query.toLowerCase());
      }).toList();
      _sortData();
    });
  }

  Future<void> _exportToCSV() async {
    if (leaderboardData.isEmpty) return;
    final headers = ['Rank', 'Name', 'Points', 'Averages', 'Achievements'];
    final csvRows = [headers.join(',')];
    for (var user in leaderboardData) {
      csvRows.add([
        user['rank'],
        '"${user['name']}"',
        user['points'],
        '"${user['averages']}%"',
        '"${user['achievements'] ?? ''}"'
      ].join(','));
    }
    final csvContent = csvRows.join('\n');
    final directory = await getExternalStorageDirectory();
    final path = '${directory!.path}/yha_coder_leaderboard.csv';
    final file = File(path);
    await file.writeAsString(csvContent);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('CSV exported to $path')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = isDarkMode ? ThemeData.dark() : ThemeData.light();
    final primaryColor = const Color(0xFFFF6200);
    final secondaryColor = const Color(0xFFFF8C00);
    final goldColor = const Color(0xFFFFD700);

    return Theme(
      data: theme.copyWith(
        primaryColor: primaryColor,
        colorScheme: isDarkMode
            ? ColorScheme.dark(primary: primaryColor, secondary: secondaryColor)
            : ColorScheme.light(primary: primaryColor, secondary: secondaryColor),
        scaffoldBackgroundColor: isDarkMode
            ? const Color(0xFF2B1A0D)
            : const Color(0xFFF5F5F5),
        textTheme: GoogleFonts.orbitronTextTheme().apply(
          bodyColor: isDarkMode ? Colors.white : Colors.black87,
          displayColor: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('YHA Coder Leaderboard'),
          actions: [
            IconButton(
              icon: Icon(isDarkMode ? Icons.wb_sunny : Icons.nightlight_round),
              onPressed: _toggleTheme,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: fetchLeaderboard,
            ),
            IconButton(
              icon: const Icon(Icons.file_download),
              onPressed: _exportToCSV,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: isDarkMode ? Colors.black26 : Colors.white,
                ),
                onChanged: _filterData,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  errorMessage!,
                                  style: const TextStyle(color: Colors.red),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: fetchLeaderboard,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                  ),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : filteredData.isEmpty
                            ? const Center(child: Text('No data available'))
                            : SingleChildScrollView(
                                child: DataTable(
                                  sortColumnIndex: ['rank', 'name', 'points', 'averages', 'achievements'].indexOf(sortColumn),
                                  sortAscending: sortAscending,
                                  columns: [
                                    DataColumn(
                                      label: const Text('Rank'),
                                      onSort: (i, ascending) {
                                        setState(() {
                                          sortColumn = 'rank';
                                          sortAscending = ascending;
                                          _sortData();
                                        });
                                      },
                                    ),
                                    DataColumn(
                                      label: const Text('Name'),
                                      onSort: (i, ascending) {
                                        setState(() {
                                          sortColumn = 'name';
                                          sortAscending = ascending;
                                          _sortData();
                                        });
                                      },
                                    ),
                                    DataColumn(
                                      label: const Text('Points'),
                                      onSort: (i, ascending) {
                                        setState(() {
                                          sortColumn = 'points';
                                          sortAscending = ascending;
                                          _sortData();
                                        });
                                      },
                                    ),
                                    DataColumn(
                                      label: const Text('Averages'),
                                      onSort: (i, ascending) {
                                        setState(() {
                                          sortColumn = 'averages';
                                          sortAscending = ascending;
                                          _sortData();
                                        });
                                      },
                                    ),
                                    DataColumn(
                                      label: const Text('Achievements'),
                                      onSort: (i, ascending) {
                                        setState(() {
                                          sortColumn = 'achievements';
                                          sortAscending = ascending;
                                          _sortData();
                                        });
                                      },
                                    ),
                                  ],
                                  rows: filteredData.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final user = entry.value;
                                    final maxPoints = filteredData
                                        .map((u) => num.tryParse(u['points'].toString()) ?? 0)
                                        .reduce((a, b) => a > b ? a : b);
                                    final pointsPercentage = (num.tryParse(user['points'].toString()) ?? 0) / maxPoints * 100;
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: LinearGradient(
                                                colors: [Colors.orange, primaryColor],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: primaryColor.withOpacity(0.5),
                                                  blurRadius: 10,
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Text(
                                                user['rank'],
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          GestureDetector(
                                            onTap: () => _showUserProfileDialog(context, user),
                                            child: Text(
                                              user['name'],
                                              style: TextStyle(
                                                color: secondaryColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                user['points'].toString(),
                                                style: TextStyle(
                                                  color: goldColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              SizedBox(
                                                width: 100,
                                                child: LinearProgressIndicator(
                                                  value: pointsPercentage / 100,
                                                  backgroundColor: Colors.black26,
                                                  valueColor: AlwaysStoppedAnimation<Color>(
                                                    primaryColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            '${user['averages']}%',
                                            style: const TextStyle(
                                              color: Color(0xFFFFAB40),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            user['achievements'] ?? 'None',
                                            style: const TextStyle(
                                              color: Color(0xFFFFAB40),
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserProfileDialog(BuildContext context, dynamic user) {
    showDialog(
      context: context,
      builder: (context) => UserProfileDialog(user: user),
    );
  }
}

class UserProfileDialog extends StatefulWidget {
  final dynamic user;

  const UserProfileDialog({super.key, required this.user});

  @override
  _UserProfileDialogState createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends State<UserProfileDialog> {
  String chartView = 'daily';

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFFFF6200);
    final secondaryColor = const Color(0xFFFF8C00);
    final goldColor = const Color(0xFFFFD700);
    final history = widget.user['pointsHistory'] ?? [];
    final maxPoints = 810; // From JSON data

    return AlertDialog(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Text(
        "${widget.user['name']}'s Profile",
        style: TextStyle(color: primaryColor),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Colors.orange, primaryColor]),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.5),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  widget.user['rank'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.user['name'],
              style: TextStyle(color: secondaryColor, fontSize: 20),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(FontAwesomeIcons.star, size: 16, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'Points: ${widget.user['points']}',
                          style: TextStyle(color: goldColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(FontAwesomeIcons.percentage, size: 16, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'Averages: ${widget.user['averages']}%',
                          style: const TextStyle(color: Color(0xFFFFAB40)),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(FontAwesomeIcons.trophy, size: 16, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'Achievements:',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.user['achievements'] ?? 'None',
                      style: const TextStyle(color: Color(0xFFFFAB40)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Progress',
              style: TextStyle(color: primaryColor, fontSize: 18),
            ),
            LinearProgressIndicator(
              value: (num.tryParse(widget.user['points'].toString()) ?? 0) / maxPoints,
              backgroundColor: Colors.black26,
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              minHeight: 25,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  chartView == 'daily' ? 'Daily Points Change' : 'Weekly Points Total',
                  style: TextStyle(color: primaryColor),
                ),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => setState(() => chartView = 'daily'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: chartView == 'daily' ? primaryColor : Colors.grey,
                      ),
                      child: const Text('Daily'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => setState(() => chartView = 'weekly'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: chartView == 'weekly' ? primaryColor : Colors.grey,
                      ),
                      child: const Text('Weekly'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 300,
              child: history.isEmpty
                  ? const Center(child: Text('No history available'))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        barGroups: _getBarGroups(history),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) => Text(
                                value.toInt().toString(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                final labels = _getChartLabels(history);
                                final index = value.toInt();
                                return index < labels.length
                                    ? Text(
                                        labels[index],
                                        style: const TextStyle(color: Colors.white),
                                      )
                                    : const Text('');
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: false),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Close',
            style: TextStyle(color: primaryColor),
          ),
        ),
      ],
    );
  }

  List<String> _getChartLabels(List<dynamic> history) {
    if (chartView == 'daily') {
      return history
          .map((entry) => DateTime.parse(entry['timestamp']).toString().substring(0, 10))
          .toList();
    } else {
      final weeklyTotals = <String, double>{};
      for (var entry in history) {
        final date = DateTime.parse(entry['timestamp']);
        final weekStart = DateTime(date.year, date.month, date.day - date.weekday);
        final weekKey = weekStart.toString().substring(0, 10);
        weeklyTotals[weekKey] = (weeklyTotals[weekKey] ?? 0) +
            (num.tryParse(entry['points'].toString()) ?? 0);
      }
      return weeklyTotals.keys.toList()..sort();
    }
  }

  List<BarChartGroupData> _getBarGroups(List<dynamic> history) {
    if (chartView == 'daily') {
      return history.asMap().entries.map((entry) {
        final index = entry.key;
        final points = num.tryParse(entry.value['points'].toString()) ?? 0;
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: points.toDouble(),
              color: points >= 0 ? const Color(0xFFFF6200) : Colors.red,
              width: 10,
            ),
          ],
        );
      }).toList();
    } else {
      final weeklyTotals = <String, double>{};
      for (var entry in history) {
        final date = DateTime.parse(entry['timestamp']);
        final weekStart = DateTime(date.year, date.month, date.day - date.weekday);
        final weekKey = weekStart.toString().substring(0, 10);
        weeklyTotals[weekKey] = (weeklyTotals[weekKey] ?? 0) +
            (num.tryParse(entry['points'].toString()) ?? 0);
      }
      final sortedWeeks = weeklyTotals.keys.toList()..sort();
      return sortedWeeks.asMap().entries.map((entry) {
        final index = entry.key;
        final week = entry.value;
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: weeklyTotals[week]!,
              color: const Color(0xFFFF6200),
              width: 10,
            ),
          ],
        );
      }).toList();
    }
  }
}