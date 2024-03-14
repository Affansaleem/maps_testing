import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
  double radius = 0.0; // Add this line
  late double setRadius;
  String unit = 'km'; // Default unit is kilometers
  String address = ''; // Add this line
  bool isSearchBarFocused = false; // Add this line at the beginning of your _MapsPageState class
  bool isAddressFetched=false;

  @override
  void initState() {
    super.initState();
    // Initialize the MapController
    mapController = MapController();

    // Set up the focus node listener for the search bar
    searchFocusNode.addListener(_focusListener);

    _getCurrentLocation().then((value) {
      setState(() {

        _center = LatLng(value.latitude, value.longitude);
        draggableMarkerPosition = _center; // Set the initial position of the draggable marker
        locationMessage = 'Latitude ${value.latitude} Longitude ${value.longitude}';
      });
      liveLocation();
    });
  }

// Define the _focusListener method
  void _focusListener() {
    setState(() {
      isSearchBarFocused = searchFocusNode.hasFocus;
      print(isSearchBarFocused);
    });
  }


  @override
  void dispose() {
    searchFocusNode.removeListener(_focusListener);
    searchFocusNode.dispose();
    super.dispose();
  }


  Future<void> reverseGeocode(double latitude, double longitude) async {
    String apiUrl = 'https://us1.locationiq.com/v1/reverse.php';
    String apiKey = 'pk.f9a5e193687ba71e403440e7974d3038'; // Replace with your actual API key
    String url = '$apiUrl?key=$apiKey&lat=$latitude&lon=$longitude&format=json';

    try {
      var response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        var addressComponents = data['address'];

        // Extract and concatenate address components
        String fetchedAddress = [
          addressComponents['neighbourhood'],
          addressComponents['suburb'],
          addressComponents['district'],
          addressComponents['state'],
          addressComponents['postcode'],
          addressComponents['country'],
        ].where((component) => component != null && component.isNotEmpty)
            .join(', ');

        print("Address: $fetchedAddress");

        // Update the address state variable
        setState(() {
          address = fetchedAddress;
          isAddressFetched=true;
          print(address);
        });
      } else {
        print('Request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in reverse geocoding: $e');
    }
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
                    setState(() {
                      draggableMarkerPosition = latlng;
                      print("Draggable Marker Position: Latitude ${draggableMarkerPosition.latitude}, Longitude ${draggableMarkerPosition.longitude}");
                      reverseGeocode(draggableMarkerPosition.latitude, draggableMarkerPosition.longitude);

                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 80.0,
                        height: 80.0,
                        point: draggableMarkerPosition,
                        child: Container(
                          child: Icon(FontAwesomeIcons.person, size: 25.0, // Adjust the icon size
                                  color: Colors.blue, // Adjust the icon color)
                          )
                        ),
                      ),
                    ],
                  ),
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: draggableMarkerPosition,
                        radius: radius,
                        color: Colors.blue.withOpacity(0.5),
                        borderStrokeWidth: 2,
                        borderColor: Colors.blue,
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
                  focusNode: searchFocusNode,

                  onChanged: (value) {
                    autocompleteSearch(value);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search for places...',
                    labelText: 'Search',
                    prefixIcon: Icon(Icons.search, color: Colors.grey[700]),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[700]),
                      onPressed: () {
                        searchController.clear();
                        autocompleteSearch('');
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20.0),
                      borderSide: BorderSide.none,
                    ),
                    fillColor: Colors.grey[100],
                    filled: true,
                    labelStyle: TextStyle(color: Colors.grey[700]),
                    hintStyle: TextStyle(color: Colors.grey[700]?.withOpacity(0.7)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20.0),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20.0),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                ),




                const SizedBox(height: 8.0),
                // Conditionally render the list container based on autocompleteResults and search text
                if (autocompleteResults.isNotEmpty &&
                    searchController.text.isNotEmpty)
                  Container(
                    color: Colors.grey[100],
                    // Light grey background color
                    padding: EdgeInsets.all(8.0),
                    // Add some padding around the list
                    child: SizedBox(
                      height: 200.0,
                      child: ListView.builder(
                        itemCount: autocompleteResults.length,
                        itemBuilder: (context, index) {
                          var location = autocompleteResults[index];
                          return ListTile(
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8.0),
                            // Add padding around each item
                            leading: Icon(
                                Icons.location_on, color: Colors.blue),
                            // Add a leading icon
                            title: Text(
                              location['display_name'],
                              style: TextStyle(fontSize: 16.0,
                                  color: Colors
                                      .grey[700]), // Customize the text style with grey color
                            ),
                            onTap: () {
                              handleAutocompleteTap(
                                double.parse(location['lat']),
                                double.parse(location['lon']),
                              );
                              searchFocusNode.unfocus();
                              setState(() {
                                autocompleteResults.clear();
                              });
                            },
                          );
                        },
                      ),
                    ),
                  )



              ],
            ),
          ),


          if (!isSearchBarFocused)
              Positioned(
                left: 250,
                top: 250.0,
                child: Column(
                  children: [
                    Transform.rotate(
                      angle: -90 * pi / 180,
                      // Rotate 90 degrees counterclockwise
                      child: Slider(
                        value: radius,
                        // Adjust the slider value based on the unit
                        min: 0.0,
                        // Adjust the slider min value based on the unit
                        max: 50.0,
                        // Adjust the slider max value based on the unit
                        divisions: 10,
                        // Adjust the slider divisions based on the unit
                        label: unit == 'km'
                            ? (radius / 10).toStringAsFixed(1)
                            : ((radius / 5).round() * 5).toString(),
                        onChanged: (double newRadius) {
                          setState(() {
                            radius =
                                newRadius; // Convert the slider value to the correct unit
                            setRadius = unit == 'km' ? radius * 100 : radius;
                            print(setRadius);
                          });
                        },
                      ),

                    ),
                    Container(
                      margin: EdgeInsets.only(top: 60),
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            unit = unit == 'km' ? 'm' : 'km'; // Toggle the unit
                            radius = 0;
                          });
                        },
                        child: Text(unit),
                      ),
                    ),
                  ],
                ),
              ),

          if (!isSearchBarFocused)
            Positioned(
                bottom: 20,
                right: 20,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      Position currentPosition = await _getCurrentLocation();
                      setState(() {
                        _center = LatLng(currentPosition.latitude,
                            currentPosition.longitude);
                        draggableMarkerPosition = LatLng(
                            currentPosition.latitude,
                            currentPosition.longitude);
                        locationMessage = 'Latitude ${currentPosition
                            .latitude} Longitude ${currentPosition.longitude}';
                      });
                      mapController.move(LatLng(
                          currentPosition.latitude, currentPosition.longitude),
                          15.0);
                      liveLocation();
                    } catch (e) {
                      print('Error getting current location: $e');
                    }
                  },
                  child: Icon(Icons.gps_fixed),
                ),
              ),
          if (!isSearchBarFocused)
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 30, vertical: 60),
                  child: isAddressFetched // Check if the address has been fetched
                      ? Card(
                    elevation: 4,
                    color: Colors.grey[100],
                    // Light grey background color
                    shadowColor: Colors.grey[300],
                    // Subtle shadow color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10), // Rounded corners
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      // Slightly reduced padding for a more compact look
                      child: Text(
                        address,
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]), // Smaller font size for concise text
                        // Removed maxLines and overflow to show complete text
                      ),
                    ),
                  )
                      : Container(), // Display an empty Container if the address has not been fetched
                ),
              ],
            )


        ],
      ),
    );
  }


}
