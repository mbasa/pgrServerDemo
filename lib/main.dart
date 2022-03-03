// @dart=2.9

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geojson_vi/geojson_vi.dart';
import 'package:latlong2/latlong.dart';
import 'package:pgrserver_demo/res/RestParams.dart';
import 'package:pgrserver_demo/utils/DialogUtil.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'pgrServer Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      home: MyHomePage(title: 'pgrServer Services'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  final int _algolDIJKSTRA = 1;
  final int _algolASTAR = 2;
  final int _algolCHBD = 3;

  String _url = RestParams.baseUrl;

  int _selAlgol = 1;
  int _drivingDistance = 3000;
  int _visibleTab = 0;
  int _numVehicles = 1;
  int _numPassengers = 1;
  int _svcPassengers = 1;

  TabController _tabController;

  MapController _mapController = MapController();
  LatLngBounds _mapBounds;
  List<Marker> _markers = [];
  List<Polyline> _polyLines = [];
  List<Polygon> _polygons = [];

  LatLng _sourcePt;
  LatLng _targetPt;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, initialIndex: 0, vsync: this);
    _mapController.onReady.then((value) => getMapBounds());
  }

  void getMapBounds() async {
    Dio dio = Dio();

    if (_mapBounds != null) {
      _mapController.fitBounds(_mapBounds,
          options: FitBoundsOptions(padding: EdgeInsets.all(3.0)));
    } else {
      DialogUtil.showOnSendDialog(context, "Getting Map Boundaries");

      try {
        debugPrint("requesting for map boundaries");

        Response response = await dio.get("$_url/utils/graphBnd");

        if (response.statusCode == 200) {
          var poly = GeoJSONPolygon.fromMap(response.data);
          var polyBnd = poly.bbox;

          _mapBounds = LatLngBounds(
              LatLng(polyBnd[1], polyBnd[0]), LatLng(polyBnd[3], polyBnd[2]));

          _mapController.fitBounds(_mapBounds,
              options: FitBoundsOptions(padding: EdgeInsets.all(3.0)));

          Navigator.pop(context);
        }
      } catch (e) {
        Navigator.pop(context);
        DialogUtil.showCustomDialog(
            context, "Error", "Ensure that pgrServer is reachable.", "Close",
            titleColor: Colors.red);
      }
    }
  }

  void _addMarker(LatLng latLng, Color color) {
    _markers.add(
      Marker(
        point: latLng,
        anchorPos: AnchorPos.align(AnchorAlign.top),
        builder: (ctx) => Container(
          child: Icon(
            Icons.location_on_rounded,
            color: color,
            size: 40.0,
          ),
        ),
      ),
    );
  }

  Future<void> getVrp() async {
    if (_markers.isEmpty || _markers.length < 3) return;

    _polyLines.clear();

    Map<String, dynamic> startLoc = {
      "lat": _markers.first.point.latitude,
      "lng": _markers.first.point.longitude,
    };

    List<Map<String, dynamic>> vehicles = [];

    for (int i = 0; i < _numVehicles; i++) {
      Map<String, dynamic> vehicle = {
        "capacity": _numPassengers,
        "startLocation": startLoc,
        "weightIndex": 0,
      };
      vehicles.add(vehicle);
    }

    List<Map<String, dynamic>> services = [];

    for (int j = 1; j < _markers.length; j++) {
      Map<String, dynamic> location = {
        "lat": _markers[j].point.latitude,
        "lng": _markers[j].point.longitude,
      };

      Map<String, dynamic> service = {
        "capacity": _svcPassengers,
        "location": location,
        "weightIndex": 0,
      };

      services.add(service);
    }

    DialogUtil.showOnSendDialog(context, "Creating VRP Solution");
    try {
      Dio dio = new Dio();
      Map<String, dynamic> data = {
        "services": services,
        "vehicles": vehicles,
      };

      Map<String, dynamic> vehicleColors = {
        "vehicle1": Colors.red,
        "vehicle2": Colors.blueAccent,
        "vehicle3": Colors.green,
        "vehicle4": Colors.deepPurple,
      };

      Response response =
          await dio.post("$_url/vrp/generateServiceRoute", data: data);

      if (response.statusCode == 200) {
        GeoJSONFeatureCollection featureCollection =
            GeoJSONFeatureCollection.fromMap(response.data);

        for (GeoJSONFeature feature in featureCollection.features) {
          //debugPrint("VRP: ${feature.properties["vehicle"]},"
          //    "route${feature.properties["route"]}");

          var geom = feature.geometry;
          String vehicle = feature.properties["vehicle"];

          if (geom is GeoJSONMultiLineString) {
            for (List<List<double>> coords in geom.coordinates) {
              List<LatLng> pLinePts = [];

              for (List<double> coord in coords) {
                LatLng latLng = LatLng(coord[1], coord[0]);
                pLinePts.add(latLng);
              }

              var polyLine = Polyline(
                  points: pLinePts,
                  color: vehicleColors[vehicle],
                  strokeWidth: 4.0);

              _polyLines.add(polyLine);
            }
          }
        }
        if (featureCollection.bbox != null) {
          _mapController.fitBounds(
              LatLngBounds(
                  LatLng(featureCollection.bbox[1], featureCollection.bbox[0]),
                  LatLng(featureCollection.bbox[3], featureCollection.bbox[2])),
              options: FitBoundsOptions(padding: EdgeInsets.all(33.0)));
        }
      }
    } catch (e) {
      debugPrint("VRP: ${e.toString()}");
    }

    Navigator.pop(context);
    setState(() {});
  }

  Future<void> getDriveTimePoly() async {
    if (_markers.isEmpty) return;

    DialogUtil.showOnSendDialog(context, "Creating DriveTime Polygon");

    try {
      _polygons.clear();
      Dio dio = Dio();

      Map<String, dynamic> options = {
        "source_x": _markers[0].point.longitude,
        "source_y": _markers[0].point.latitude,
        "radius": _drivingDistance,
      };

      Response response = await dio.get("$_url/api/latlng/drivingDistance",
          queryParameters: options);

      if (response.statusCode == 200) {
        var polys = GeoJSONPolygon.fromMap(response.data["geometry"]);

        if (polys != null) {
          for (List<List<double>> mPolys in polys.coordinates) {
            List<LatLng> coordinates = [];

            for (List<double> mPoly in mPolys) {
              coordinates.add(LatLng(mPoly[1], mPoly[0]));
            }

            _polygons.add(Polygon(
                points: coordinates,
                color: Colors.redAccent.withOpacity(0.3), //Colors.transparent,
                borderColor: Colors.red,
                borderStrokeWidth: 4.0));
          }

          _mapController.fitBounds(LatLngBounds(
              LatLng(polys.bbox[1], polys.bbox[0]),
              LatLng(polys.bbox[3], polys.bbox[2])));
        }
      }
    } catch (e) {
      debugPrint("DriveTimePolygon: ${e.toString()}");
    }

    Navigator.pop(context);
    setState(() {});
  }

  Future<void> getRoute() async {
    Dio dio = Dio();
    String url = "$_url/api/latlng/";
    String mUrl;

    DialogUtil.showOnSendDialog(context, "Finding Shortest Path");

    try {
      Map<String, dynamic> options = {
        "source_x": _sourcePt.longitude,
        "source_y": _sourcePt.latitude,
        "target_x": _targetPt.longitude,
        "target_y": _targetPt.latitude,
      };

      if (_selAlgol == _algolDIJKSTRA) {
        mUrl = "$url/dijkstra";
      } else if (_selAlgol == _algolASTAR) {
        mUrl = "$url/astar";
      } else if (_selAlgol == _algolCHBD) {
        mUrl = "$url/chbDijkstra";
      }

      Response response = await dio.get(mUrl, queryParameters: options);

      if (response.statusCode == 200) {
        GeoJSON geoJson = GeoJSON.fromMap(response.data);

        if (geoJson is GeoJSONFeature) {
          var geom = geoJson.geometry;

          if (geom is GeoJSONMultiLineString) {
            for (List<List<double>> coords in geom.coordinates) {
              List<LatLng> pLinePts = [];

              for (List<double> coord in coords) {
                LatLng latLng = LatLng(coord[1], coord[0]);
                pLinePts.add(latLng);
              }

              var polyLine = Polyline(
                  points: pLinePts, color: Colors.deepPurple, strokeWidth: 4.0);

              _polyLines.add(polyLine);
            }

            _mapController.fitBounds(
                LatLngBounds(LatLng(geom.bbox[1], geom.bbox[0]),
                    LatLng(geom.bbox[3], geom.bbox[2])),
                options: FitBoundsOptions(padding: EdgeInsets.all(33.0)));
          } else if (geom is GeoJSONLineString) {
            List<LatLng> pLinePts = [];

            for (List<double> coord in geom.coordinates) {
              LatLng latLng = LatLng(coord[1], coord[0]);
              pLinePts.add(latLng);
            }

            var polyLine = Polyline(
                points: pLinePts, color: Colors.deepPurple, strokeWidth: 4.0);

            _polyLines.add(polyLine);

            _mapController.fitBounds(
                LatLngBounds(LatLng(geom.bbox[1], geom.bbox[0]),
                    LatLng(geom.bbox[3], geom.bbox[2])),
                options: FitBoundsOptions(padding: EdgeInsets.all(33.0)));
          }
        }
      }
    } catch (exception) {
      debugPrint("Get Route Exception: $exception");
      setState(() {});
    }

    Navigator.pop(context);
  }

  void _removeMarkers() {
    _markers.clear();
    _polyLines.clear();
    _polygons.clear();
    setState(() {});
  }

  void _mapMove(LatLng latLng) async {
    switch (_visibleTab) {
      case 0: // Shortest Path Tab
        if (_markers.length == 0) {
          _addMarker(latLng, Colors.green[900]);
          _sourcePt = latLng;
          _mapController.move(_sourcePt, _mapController.zoom);
        } else {
          if (_markers.length > 1) {
            _markers.removeLast();
          }
          _addMarker(latLng, Colors.red[900]);
          _targetPt = latLng;
          _polyLines.clear();

          await getRoute();
        }
        break;
      case 1: //Driving Distance Tab
        _markers.clear();
        _polygons.clear();
        _addMarker(latLng, Colors.green[900]);
        _sourcePt = latLng;
        _mapController.move(_sourcePt, _mapController.zoom);
        break;
      case 2:
        if (_markers.length == 0) {
          _addMarker(latLng, Colors.green[900]);
          _sourcePt = latLng;
        } else {
          _addMarker(latLng, Colors.red[900]);
          _targetPt = latLng;
        }
        _mapController.move(latLng, _mapController.zoom);
        break;
    }
  }

  void _zoomMap(bool zoomIn) {
    double zoom = _mapController.zoom;
    zoomIn ? zoom++ : zoom--;

    _mapController.move(_mapController.center, zoom);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 40.0,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () async {
              String mUrl = await DialogUtil.showTextInputDialog(
                  context, "Enter pgrServer URL", _url, "OK", "Cancel");
              if (mUrl != null && mUrl.isNotEmpty) {
                _url = mUrl;
                _mapBounds = null;
              }
            },
          ),
        ],
      ),
      body: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center: LatLng(51.5, -0.09),
                    zoom: 13.0,
                    onTap: (tp, xy) => _mapMove(xy),
                  ),
                  layers: [
                    TileLayerOptions(
                        urlTemplate:
                            "http://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                        subdomains: ['a', 'b', 'c']),
                    PolygonLayerOptions(
                      polygons: _polygons,
                    ),
                    PolylineLayerOptions(
                      polylines: _polyLines,
                    ),
                    MarkerLayerOptions(
                      markers: _markers,
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: EdgeInsets.all(22.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FloatingActionButton(
                          elevation: 32.0,
                          onPressed: () => getMapBounds(),
                          tooltip: 'Zoom Bnd',
                          child: Icon(
                            Icons.zoom_out_map_outlined,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(
                          width: 15.0,
                        ),
                        FloatingActionButton(
                          elevation: 32.0,
                          onPressed: () => _zoomMap(true),
                          tooltip: 'Zoom In',
                          child: Icon(
                            Icons.zoom_in_sharp,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(
                          width: 15.0,
                        ),
                        FloatingActionButton(
                          elevation: 32.0,
                          onPressed: () => _zoomMap(false),
                          tooltip: 'Zoom Out',
                          child: Icon(
                            Icons.zoom_out_sharp,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Padding(
              padding: EdgeInsets.all(4),
              child: Container(
                padding: EdgeInsets.all(1.5),
                //height: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black26, width: 1),
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8), //border corner radius
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5), //color of shadow
                      spreadRadius: 5, //spread radius
                      blurRadius: 7, // blur radius
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      child: new TabBar(
                        controller: _tabController,
                        labelStyle: TextStyle(
                          fontSize: 8.5,
                        ),
                        labelColor: Colors.black,
                        unselectedLabelColor: Colors.black26,
                        onTap: (val) {
                          _visibleTab = val;
                          _removeMarkers();
                        },
                        tabs: [
                          new Tab(
                            icon: const Icon(
                              Icons.home,
                              size: 16.0,
                            ),
                            text: 'Shortest\n   Path',
                          ),
                          new Tab(
                            icon: const Icon(
                              Icons.drive_eta,
                              size: 16.0,
                            ),
                            text: ' Driving\nDistance',
                          ),
                          new Tab(
                            icon: const Icon(
                              Icons.my_location,
                              size: 16.0,
                            ),
                            text: '   VRP\nSearches',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          shortestPath(),
                          drivingDistance(),
                          vrp(),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _removeMarkers(),
                      child: Text("Clear Markers"),
                    ),
                    SizedBox(
                      height: 10.0,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget vrp() {
    List<DropdownMenuItem<int>> numVehicles = [
      DropdownMenuItem(
        child: Text("1 Vehicle"),
        value: 1,
      ),
      DropdownMenuItem(
        child: Text("2 Vehicles"),
        value: 2,
      ),
      DropdownMenuItem(
        child: Text("3 Vehicles"),
        value: 3,
      ),
      DropdownMenuItem(
        child: Text("4 Vehicles"),
        value: 4,
      ),
    ];

    List<DropdownMenuItem<int>> numPassengers = [
      DropdownMenuItem(
        child: Text("1 Passenger"),
        value: 1,
      ),
      DropdownMenuItem(
        child: Text("2 Passengers"),
        value: 2,
      ),
      DropdownMenuItem(
        child: Text("3 Passengers"),
        value: 3,
      ),
      DropdownMenuItem(
        child: Text("4 Passengers"),
        value: 4,
      ),
      DropdownMenuItem(
        child: Text("5 Passengers"),
        value: 5,
      ),
      DropdownMenuItem(
        child: Text("6 Passengers"),
        value: 6,
      ),
    ];

    List<DropdownMenuItem<int>> svcPassengers = [
      DropdownMenuItem(
        child: Text("1 Passenger"),
        value: 1,
      ),
      DropdownMenuItem(
        child: Text("2 Passengers"),
        value: 2,
      ),
      DropdownMenuItem(
        child: Text("3 Passengers"),
        value: 3,
      ),
      DropdownMenuItem(
        child: Text("4 Passengers"),
        value: 4,
      ),
    ];

    return Container(
      padding: EdgeInsets.only(top: 20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text("Vehicle Routing Problem"),
          SizedBox(
            height: 50.0,
          ),
          Text(
            "Choose Number of Vehicles",
            style: TextStyle(fontSize: 12),
          ),
          DropdownButton(
            items: numVehicles,
            value: _numVehicles,
            style: TextStyle(fontSize: 13, color: Colors.black),
            underline: Container(
              height: 2,
              color: Theme.of(context).accentColor,
            ),
            onChanged: (val) => setState(() {
              _numVehicles = val;
            }),
          ),
          SizedBox(
            height: 8.0,
          ),
          Text(
            "Passenger Capacity per Vehicle",
            style: TextStyle(fontSize: 12),
          ),
          DropdownButton(
            items: numPassengers,
            value: _numPassengers,
            style: TextStyle(fontSize: 13, color: Colors.black),
            underline: Container(
              height: 2,
              color: Theme.of(context).accentColor,
            ),
            onChanged: (val) => setState(() {
              _numPassengers = val;
            }),
          ),
          SizedBox(
            height: 8.0,
          ),
          Text(
            "Passengers per Service Request",
            style: TextStyle(fontSize: 12),
          ),
          DropdownButton(
            items: svcPassengers,
            value: _svcPassengers,
            style: TextStyle(fontSize: 13, color: Colors.black),
            underline: Container(
              height: 2,
              color: Theme.of(context).accentColor,
            ),
            onChanged: (val) => setState(() {
              _svcPassengers = val;
            }),
          ),
          SizedBox(
            height: 14.0,
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(primary: Colors.deepOrange),
            onPressed: () async {
              await getVrp();
            },
            child: Text("Search"),
          )
        ],
      ),
    );
  }

  Widget drivingDistance() {
    List<DropdownMenuItem<int>> distances = [
      DropdownMenuItem(
        child: Text("3 kilometers"),
        value: 3000,
      ),
      DropdownMenuItem(
        child: Text("5 kilometers"),
        value: 5000,
      ),
      DropdownMenuItem(
        child: Text("10 kilometers"),
        value: 10000,
      ),
      DropdownMenuItem(
        child: Text("15 kilometers"),
        value: 15000,
      ),
      DropdownMenuItem(
        child: Text("20 kilometers"),
        value: 20000,
      ),
      DropdownMenuItem(
        child: Text("25 kilometers"),
        value: 25000,
      ),
      /*
      DropdownMenuItem(
        child: Text("30 kilometers"),
        value: 30000,
      ),
      DropdownMenuItem(
        child: Text("45 kilometers"),
        value: 45000,
      ),
      DropdownMenuItem(
        child: Text("50 kilometers"),
        value: 50000,
      ),*/
    ];

    return Container(
      padding: EdgeInsets.only(top: 20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text("Driving Distance"),
          SizedBox(
            height: 50.0,
          ),
          Text(
            "Choose Search Distance",
            style: TextStyle(fontSize: 12),
          ),
          DropdownButton(
            items: distances,
            value: _drivingDistance,
            style: TextStyle(fontSize: 13, color: Colors.black),
            underline: Container(
              height: 2,
              color: Theme.of(context).accentColor,
            ),
            onChanged: (val) => setState(() {
              _drivingDistance = val;
            }),
          ),
          SizedBox(
            height: 8.0,
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(primary: Colors.deepOrange),
            onPressed: () async {
              await getDriveTimePoly();
            },
            child: Text("Search"),
          )
        ],
      ),
    );
  }

  Widget shortestPath() {
    return Container(
      padding: EdgeInsets.only(top: 20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text("Shortest Path"),
          SizedBox(
            height: 20.0,
          ),
          Text(
            "Choose Search Algorithm",
            style: TextStyle(fontSize: 12),
          ),
          SizedBox(
            height: 8.0,
          ),
          RadioListTile(
            title: Text("Dijkstra"),
            subtitle: Text("Shortest Path Algorithm"),
            value: _algolDIJKSTRA,
            groupValue: _selAlgol,
            onChanged: (val) {
              _selAlgol = val;
              setState(() {});
            },
            selected: _selAlgol == _algolDIJKSTRA,
          ),
          RadioListTile(
            title: Text("A-Star"),
            subtitle: Text("Shortest Path Algorithm"),
            value: _algolASTAR,
            groupValue: _selAlgol,
            onChanged: (val) {
              _selAlgol = val;
              setState(() {});
            },
            selected: _selAlgol == _algolASTAR,
          ),
          RadioListTile(
            title: Text("chbDijkstra"),
            subtitle: Text("Shortest Path Algorithm"),
            value: _algolCHBD,
            groupValue: _selAlgol,
            onChanged: (val) {
              _selAlgol = val;
              setState(() {});
            },
            selected: _selAlgol == _algolCHBD,
          ),
        ],
      ),
    );
  }
}
