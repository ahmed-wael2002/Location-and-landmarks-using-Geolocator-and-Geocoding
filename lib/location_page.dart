import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  _LocationPageState createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  String _address = "No location yet";
  Future<List<String>> _landmarks = Future.value([]);  // Initialize with an empty list.
  List<String> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadStoredLocation();
    _loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Location & Landmarks"),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton(
              onPressed: _handleLocationPermissionWithDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.my_location, color: Theme.of(context).colorScheme.onPrimary),
                  const SizedBox(width: 8),
                  Text('Get Location', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Current Address: $_address",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<String>>(
              future: _landmarks,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Failed to load landmarks: ${snapshot.error}",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No landmarks found"));
                } else {
                  final landmarks = snapshot.data!;
                  return ListView.builder(
                    itemCount: landmarks.length,
                    itemBuilder: (context, index) {
                      final parts = landmarks[index].split("|");
                      final address = parts.isNotEmpty ? parts[0] : "No address";
                      final coordinates = parts.length > 1 ? parts[1] : "No coordinates";

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 3,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Icon(Icons.place, color: theme.primaryColor, size: 30),
                          title: Text(address, style: theme.textTheme.headlineSmall?.copyWith(fontSize: 14, fontWeight: FontWeight.bold)),
                          trailing: IconButton(
                            icon: Icon(
                              _favorites.contains(landmarks[index]) ? Icons.favorite : Icons.favorite_border,
                              color: _favorites.contains(landmarks[index]) ? Colors.red : theme.iconTheme.color,
                            ),
                            onPressed: () => _toggleFavorite(landmarks[index]),
                          ),
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Main',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
        ],
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => FavoritesPage(favorites: _favorites)),
            );
          }
        },
      ),
    );
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      final myPlacemark = placemarks.first;
      final newAddress = "${myPlacemark.street}, ${myPlacemark.locality}, ${myPlacemark.country}";

      final newLandmarks = placemarks.map((p) => "${p.street}, ${p.locality}, ${p.country}").toList();

      final prefs = await SharedPreferences.getInstance();
      final savedAddress = prefs.getString("address");

      if (savedAddress != newAddress) {
        setState(() {
          _address = newAddress;
          _landmarks = Future.value(newLandmarks); // Update _landmarks with Future.value
        });

        await prefs.setString("address", newAddress);
        await prefs.setStringList("landmarks", newLandmarks);
      } else {
        setState(() {
          _address = savedAddress!;
          _landmarks = Future.value(prefs.getStringList("landmarks") ?? []); // Ensure that landmarks are loaded from prefs
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to fetch location: $e")));
    }
  }

  Future<void> _handleLocationPermissionWithDialog() async {
    final permissionStatus = await Permission.location.status;

    if (permissionStatus.isGranted) {
      _fetchCurrentLocation();
    } else if (permissionStatus.isDenied) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Location Permission Required"),
          content: const Text("This app needs location access to display your current location and nearby landmarks."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final result = await Permission.location.request();
                if (result.isGranted) {
                  _fetchCurrentLocation();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Location permission is required to proceed.")),
                  );
                }
              },
              child: const Text("Grant Permission"),
            ),
          ],
        ),
      );
    } else if (permissionStatus.isPermanentlyDenied) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Permission Permanently Denied"),
          content: const Text("Location access has been permanently denied. Please enable it from the app settings."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text("Open Settings"),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _loadStoredLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final storedAddress = prefs.getString("address");

    setState(() {
      _address = storedAddress ?? "No location yet";
      _landmarks = Future.value(prefs.getStringList("landmarks") ?? []); // Default to an empty list if no stored landmarks
    });
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final storedFavorites = prefs.getStringList("favorites") ?? [];
    setState(() {
      _favorites = storedFavorites;
    });
  }

  void _toggleFavorite(String landmark) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favorites.contains(landmark)) {
        _favorites.remove(landmark);
      } else {
        _favorites.add(landmark);
      }
    });
    await prefs.setStringList("favorites", _favorites);
  }
}

class FavoritesPage extends StatelessWidget {
  final List<String> favorites;

  const FavoritesPage({super.key, required this.favorites});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Favorite Landmarks")),
      body: favorites.isEmpty
          ? const Center(child: Text("No favorites yet"))
          : ListView.builder(
        itemCount: favorites.length,
        itemBuilder: (context, index) {
          final parts = favorites[index].split("|");
          final address = parts.isNotEmpty ? parts[0] : "No address";
          final coordinates = parts.length > 1 ? parts[1] : "No coordinates";

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 3,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const Icon(Icons.place, color: Colors.red, size: 30),
              title: Text(address),
              subtitle: Text(coordinates),
            ),
          );
        },
      ),
    );
  }
}
