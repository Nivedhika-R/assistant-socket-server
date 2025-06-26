import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';

void main() => runApp(const MyApp());

ARView(
  {onARViewCreated = onARViewCreated, required PlaneDetectionConfig}
  (PlaneDetectionConfig = PlaneDetectionMode.horizontalAndVertical)
)



mixin onARViewCreated {
}class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: ARViewScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ARViewScreen extends StatefulWidget {
  const ARViewScreen({super.key});

  @override
  State<ARViewScreen> createState() => _ARViewScreenState();
}

class _ARViewScreenState extends State<ARViewScreen> {
  late ARSessionManager arSessionManager;
  late ARObjectManager arObjectManager;

  @override
  Widget build(BuildContext context, dynamic PlaneDetectionMode) {
    return Scaffold(
      appBar: AppBar(title: const Text("AR View")),
      body: ARView(
        onARViewCreated: onARViewCreated,
        PlaneDetectionConfig: PlaneDetectionMode.horizontalAndVertical),

      );
  }

  void onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) {
    arSessionManager = sessionManager;
    arObjectManager = objectManager;

    arSessionManager.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      handleTaps: true,
    );

    arObjectManager.onInitialize();

    // Listen for taps on detected planes
    arSessionManager.onPlaneTap = onPlaneTapped;


  Future<void> onPlaneTapped(List<ARHitTestResult> hitResults) async {
    if (hitResults.isEmpty) return;

    final hit = hitResults.first;

    final node = ARNode(
      type: NodeType.webGLB,
      uri:
          "https://github.com/KhronosGroup/glTF-Sample-Models/raw/master/2.0/Duck/glTF-Binary/Duck.glb",
      scale: Vector3(0.2, 0.2, 0.2),
      position: Vector3(
      hit.worldTransform.getTranslation().x,
      hit.worldTransform.getTranslation().y,
      hit.worldTransform.getTranslation().z,
),
rotation: hit.worldTransform.getRotation().eulerAngles,

    );

    final didAdd = await arObjectManager.addNode(node);
    print("Object added: $didAdd");
  }
}
