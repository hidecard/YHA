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
import 'package:flutter/scheduler.dart';

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
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF6200),
          secondary: Color(0xFFFF8C00),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6200),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        primaryColor: const Color(0xFFFF6200),
        scaffoldBackgroundColor: const Color(0xFF2B1A0D),
        textTheme: GoogleFonts.orbitronTextTheme(),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF6200),
          secondary: Color(0xFFFF8C00),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6200),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
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

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  List<dynamic> leaderboardData = [];
  List<dynamic> filteredData = [];
  String sortColumn = 'rank';
  bool sortAscending = true;
  bool isLoading = true;
  String? errorMessage;
  bool isDarkMode = true;
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _scanlineController;
  late Animation<double> _scanlineAnimation;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    fetchLeaderboard();
    _scanlineController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
    _scanlineAnimation = Tween<double>(begin: -1, end: 1).animate(_scanlineController);
  }

  @override
  void dispose() {
    _scanlineController.dispose();
    _searchController.dispose();
    super.dispose();
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
        final validData = data.where((user) {
          try {
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
        try {
          final digitsA = valueA.toString().replaceAll(RegExp(r'[^\d\s]'), '').trim();
          final digitsB = valueB.toString().replaceAll(RegExp(r'[^\d\s]'), '').trim();
          valueA = num.tryParse(digitsA) ?? 999999;
          valueB = num.tryParse(digitsB) ?? 999999;
        } catch (e) {
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
      return sortAscending ? valueA.compareTo(valueB) : valueB.compareTo(valueA);
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
        body: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: isDarkMode
                  ? [const Color(0xFF2B1A0D), const Color(0xFF3B261B)]
                  : [const Color(0xFFF5F5F5), const Color(0xFFE0E0E0)],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'YHA Coder Leaderboard',
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: primaryColor.withOpacity(0.7),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  isDarkMode ? Icons.wb_sunny : Icons.nightlight_round,
                                  color: Colors.white,
                                ),
                                onPressed: _toggleTheme,
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh, color: Colors.white),
                                onPressed: fetchLeaderboard,
                              ),
                              IconButton(
                                icon: const Icon(Icons.file_download, color: Colors.white),
                                onPressed: _exportToCSV,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.black26 : Colors.white70,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: primaryColor),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search by name...',
                            prefixIcon: Icon(Icons.search, color: primaryColor),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onChanged: _filterData,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? const Color(0xFF3D2114).withOpacity(0.8)
                                : Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: primaryColor, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.3),
                                blurRadius: 25,
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              AnimatedBuilder(
                                animation: _scanlineAnimation,
                                builder: (context, child) {
                                  return Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    height: 2,
                                    child: Transform.translate(
                                      offset: Offset(0, _scanlineAnimation.value * MediaQuery.of(context).size.height / 2),
                                      child: Container(
                                        color: primaryColor.withOpacity(0.5),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              isLoading
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
                                                child: const Text('Retry'),
                                              ),
                                            ],
                                          ),
                                        )
                                      : filteredData.isEmpty
                                          ? const Center(child: Text('No data available'))
                                          : ListView.builder(
                                              padding: const EdgeInsets.all(8),
                                              itemCount: filteredData.length,
                                              itemBuilder: (context, index) {
                                                final user = filteredData[index];
                                                final maxPoints = filteredData
                                                    .map((u) => num.tryParse(u['points'].toString()) ?? 0)
                                                    .reduce((a, b) => a > b ? a : b);
                                                final pointsPercentage =
                                                    (num.tryParse(user['points'].toString()) ?? 0) / maxPoints * 100;
                                                return AnimatedContainer(
                                                  duration: const Duration(milliseconds: 500),
                                                  curve: Curves.easeInOut,
                                                  transform: Matrix4.identity()
                                                    ..translate(0.0, index * 20.0)
                                                    ..scale(isLoading ? 0.0 : 1.0),
                                                  child: GestureDetector(
                                                    onTap: () => _showUserProfileDialog(context, user),
                                                    child: Card(
                                                      color: isDarkMode
                                                          ? Colors.white.withOpacity(0.05)
                                                          : Colors.black.withOpacity(0.05),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        side: BorderSide(color: primaryColor.withOpacity(0.2)),
                                                      ),
                                                      elevation: 0,
                                                      child: Padding(
                                                        padding: const EdgeInsets.all(12.0),
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Row(
                                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                              children: [
                                                                _RankBadge(
                                                                  rank: user['rank'],
                                                                  primaryColor: primaryColor,
                                                                ),
                                                                Text(
                                                                  user['name'],
                                                                  style: TextStyle(
                                                                    color: secondaryColor,
                                                                    fontWeight: FontWeight.w600,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(height: 8),
                                                            Row(
                                                              children: [
                                                                Text(
                                                                  'Points: ${user['points']}',
                                                                  style: TextStyle(color: goldColor),
                                                                ),
                                                                const SizedBox(width: 8),
                                                                Expanded(
                                                                  child: LinearProgressIndicator(
                                                                    value: pointsPercentage / 100,
                                                                    backgroundColor: Colors.black26,
                                                                    valueColor:
                                                                        AlwaysStoppedAnimation<Color>(primaryColor),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(height: 4),
                                                            Text(
                                                              'Averages: ${user['averages']}%',
                                                              style: const TextStyle(color: Color(0xFFFFAB40)),
                                                            ),
                                                            const SizedBox(height: 4),
                                                            Text(
                                                              'Achievements: ${user['achievements'] ?? 'None'}',
                                                              style: const TextStyle(
                                                                color: Color(0xFFFFAB40),
                                                                fontStyle: FontStyle.italic,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

class _RankBadge extends StatefulWidget {
  final String rank;
  final Color primaryColor;

  const _RankBadge({required this.rank, required this.primaryColor});

  @override
  _RankBadgeState createState() => _RankBadgeState();
}

class _RankBadgeState extends State<_RankBadge> with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 5, end: 15).animate(_glowController);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Colors.orange, widget.primaryColor],
            ),
            boxShadow: [
              BoxShadow(
                color: widget.primaryColor.withOpacity(0.5),
                blurRadius: _glowAnimation.value,
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.rank,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
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
    final maxPoints = 810;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
        decoration: BoxDecoration(
          color: const Color(0xFF2B1A0D).withOpacity(0.9),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: primaryColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.3),
              blurRadius: 25,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor.withOpacity(0.2), Colors.transparent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${widget.user['name']}'s Profile",
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.black.withOpacity(0.2),
                      ),
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
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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