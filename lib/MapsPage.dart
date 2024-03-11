import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapsPage extends StatefulWidget {
  const MapsPage() : super();

  @override
  State<MapsPage> createState() => _MapsPageState();
}

class _MapsPageState extends State<MapsPage> {
  String apiKey = 'pk.f9a5e193687ba71e403440e7974d3038';
  TextEditingController searchController = TextEditingController();
  List<dynamic> autocompleteResults = [];
  LatLng _center = LatLng(51.509364, -0.128928); // Default center
  String locationMessage = '';
  MapController mapController = MapController(); // Create a MapController
  LatLng draggableMarkerPosition = LatLng(51.509364, -0.128928); // Position for the draggable marker
  FocusNode searchFocusNode = FocusNode(); // Define a FocusNode

  @override
  void initState() {
    super.initState();
    _getCurrentLocation().then((value) {
      setState(() {
        _center = LatLng(value.latitude, value.longitude);
        draggableMarkerPosition = _center; // Set the initial position of the draggable marker
        print("Init ${_center}");
        locationMessage = 'Latitude ${value.latitude} Longitude ${value.longitude}';
      });
      // Call liveLocation to start listening for location updates
      liveLocation();
    });
  }

  void autocompleteSearch(String query) async {
    String apiUrl = 'https://us1.locationiq.com/v1/autocomplete.php';
    String url = '$apiUrl?key=$apiKey&q=$query';

    try {
      var response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          autocompleteResults = json.decode(response.body);
        });
      } else {
        print('Request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  void handleAutocompleteTap(double latitude, double longitude) {
    setState(() {
      _center = LatLng(latitude, longitude); // Update _center with selected location
      draggableMarkerPosition = LatLng(latitude, longitude); // Update the draggable marker's position
    });
    // Use the MapController to move the map to the selected location
    mapController.move(LatLng(latitude, longitude), 15.0);
  }


  void liveLocation() {
    LocationSettings locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 100,
    );
    Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      setState(() {
        _center = LatLng(position.latitude, position.longitude);
        locationMessage = 'Latitude ${position.latitude} Longitude ${position.longitude}';
        print(locationMessage);
        // Use the MapController to move the map to the new coordinates
        mapController.move(LatLng(position.latitude, position.longitude), 15.0);
      });
    });
  }

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maps Page'),
      ),
      body: Stack(
        children: [
          StatefulBuilder(
            builder: (context, setState) {
              return FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  center: _center,
                  zoom: 5.2,
                  onTap: (TapPosition tapPosition, LatLng latlng) {
                    // Update the draggable marker's position when the map is tapped
                    setState(() {
                      draggableMarkerPosition = latlng;
                      print("Draggable Marker Position: Latitude ${draggableMarkerPosition.latitude}, Longitude ${draggableMarkerPosition.longitude}");
                    });
                  },
                ),

                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app',
                  ),
                  // Add a MarkerLayer to display the draggable marker
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 80.0,
                        height: 80.0,
                        point: draggableMarkerPosition,
                        child: Container(
                          child: Icon(Icons.location_pin, color: Colors.red, size: 40),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          Positioned(
            top: 16.0,
            left: 16.0,
            right: 16.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: searchController,
                  focusNode: searchFocusNode, // Use the FocusNode here
                  onChanged: (value) {
                    autocompleteSearch(value);
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search for places...',
                    labelText: 'Search',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8.0),
                SizedBox(
                  height: 200.0,
                  child: ListView.builder(
                    itemCount: autocompleteResults.length,
                    itemBuilder: (context, index) {
                      var location = autocompleteResults[index];
                      return ListTile(
                        title: Text(location['display_name']),
                        onTap: () {
                          handleAutocompleteTap(
                            double.parse(location['lat']),
                            double.parse(location['lon']),
                          );
                          searchFocusNode.unfocus(); // Dismiss the keyboard and the list
                          setState(() {
                            autocompleteResults.clear(); // Clear the list of search results
                          });
                        },
                      );

                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: () async {
                try {
                  Position currentPosition = await _getCurrentLocation();
                  setState(() {
                    _center = LatLng(currentPosition.latitude, currentPosition.longitude);
                    draggableMarkerPosition = LatLng(currentPosition.latitude, currentPosition.longitude);
                    locationMessage = 'Latitude ${currentPosition.latitude} Longitude ${currentPosition.longitude}';
                  });
                  // Use the MapController to move the map back to the current location
                  mapController.move(LatLng(currentPosition.latitude, currentPosition.longitude), 15.0);
                  // Call liveLocation to start listening for location updates
                  liveLocation();
                } catch (e) {
                  print('Error getting current location: $e');
                }
              },
              child: Icon(Icons.gps_fixed),
            ),
          )

        ],
      ),
    );
  }

}
