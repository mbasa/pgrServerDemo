// @dart=2.9

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geojson_vi/geojson_vi.dart';
import 'package:latlong/latlong.dart';
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
  TabController _tabController;

  MapController _mapController = MapController();
  LatLngBounds _mapBounds;
  List<Marker> _markers = [];
  List<Polyline> _polyLines = [];

  LatLng _sourcePt;
  LatLng _targetPt;

  final int _algolDIJKSTRA = 1;
  final int _algolASTAR = 2;
  final int _algolCHBD = 3;

  int _selAlgol = 1;

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

        Response response =
            await dio.get("http://127.0.0.1:8080/pgrServer/utils/graphBnd");

        if (response.statusCode == 200) {
          JsonEncoder jsonEncoder = JsonEncoder();

          debugPrint("Status: ${response.statusCode},"
              "Data: ${jsonEncoder.convert(response.data)}");

          var poly =
              GeoJSONPolygon.fromJSON(jsonEncoder.convert(response.data));
          var polyBnd = poly.bbox;

          _mapBounds = LatLngBounds(
              LatLng(polyBnd[1], polyBnd[0]), LatLng(polyBnd[3], polyBnd[2]));

          _mapController.fitBounds(_mapBounds,
              options: FitBoundsOptions(padding: EdgeInsets.all(3.0)));
        }
      } catch (e) {
        debugPrint("Exception : $e");
      }

      Navigator.pop(context);
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

  Future<void> getRoute() async {
    Dio dio = Dio();
    String url = "http://localhost:8080/pgrServer/api/latlng/";
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
        debugPrint(
            "Line Properties: ${response.data["properties"].toString()}");

        JsonEncoder jsonEncoder = JsonEncoder();

        var lines = GeoJSONMultiLineString.fromJSON(
            jsonEncoder.convert(response.data["geometry"]));

        if (lines != null) {
          for (List<List<double>> coords in lines.coordinates) {
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
              LatLngBounds(LatLng(lines.bbox[1], lines.bbox[0]),
                  LatLng(lines.bbox[3], lines.bbox[2])),
              options: FitBoundsOptions(padding: EdgeInsets.all(33.0)));
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
    setState(() {});
  }

  void _mapMove(LatLng latLng) async {
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
  }

  void _incrementCounter(bool zoomIn) {
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
                    onTap: (xy) => _mapMove(xy),
                  ),
                  layers: [
                    TileLayerOptions(
                        urlTemplate:
                            "http://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                        subdomains: ['a', 'b', 'c']),
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
                          onPressed: () => _incrementCounter(true),
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
                          onPressed: () => _incrementCounter(false),
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
                        onTap: (val) => _removeMarkers(),
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
                          Text("Driving Distance"),
                          Text("VRP Search"),
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
