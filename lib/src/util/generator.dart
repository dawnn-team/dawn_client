import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dawnn_client/src/network/objects/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// This just adds overlay and builds [_MarkerHelper] on that overlay.
/// [_MarkerHelper] does all the heavy work of creating and getting bitmaps
///
/// This class is created by https://github.com/itsJoKr
/// A little cleanup was done by mhmyesman.
@deprecated
class MarkerGenerator {
  final Function(List<Uint8List>, List<img.Image>) callback;

  // We get the bitmaps from this list.
  final List<Widget> markerWidgets;
  final List<img.Image> images;

  MarkerGenerator(this.markerWidgets, this.callback, this.images);

  void generate(BuildContext context) {
    // Code below from https://github.com/Jip1912
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance
          .addPostFrameCallback((_) => afterFirstLayout(context));
    } else {
      afterFirstLayout(context);
    }
  }

  void afterFirstLayout(BuildContext context) {
    addOverlay(context);
  }

  void addOverlay(BuildContext context) {
    OverlayState overlayState;

    try {
      overlayState = Overlay.of(context);
    } catch (exception) {
      print('Avoiding searching for deactivated widget ancestor.');
      return;
    }

    OverlayEntry entry = OverlayEntry(
        builder: (context) {
          return _MarkerHelper(
            markerWidgets: markerWidgets,
            callback: callback,
            images: images,
          );
        },
        maintainState: true);

    overlayState.insert(entry);
  }
}

/// Maps are embedding GoogleMap library for Android/iOS  into flutter.
///
/// These native libraries accept BitmapDescriptor for marker, which means that for custom markers
/// you need to draw view to bitmap and then send that to BitmapDescriptor.
///
/// Because of that Flutter also cannot accept Widget for marker, but you need draw it to bitmap and
/// that's what this widget does:
///
/// 1) It draws marker widget to tree
/// 2) After painted access the repaint boundary with global key and converts it to uInt8List
/// 3) Returns set of Uint8List (bitmaps) through callback
class _MarkerHelper extends StatefulWidget {
  final List<Widget> markerWidgets;
  final Function(List<Uint8List>, List<img.Image>) callback;
  final List<img.Image> images;

  const _MarkerHelper({Key key, this.markerWidgets, this.callback, this.images})
      : super(key: key);

  @override
  _MarkerHelperState createState() => _MarkerHelperState(images);
}

class _MarkerHelperState extends State<_MarkerHelper> with AfterLayoutMixin {
  List<GlobalKey> globalKeys = <GlobalKey>[];
  List<img.Image> images;

  _MarkerHelperState(this.images);

  @override
  void afterFirstLayout(BuildContext context) {
    _getBitmaps(context).then((list) {
      widget.callback(list, images);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(MediaQuery.of(context).size.width, 0),
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: widget.markerWidgets.map((i) {
            final markerKey = GlobalKey();
            globalKeys.add(markerKey);
            return RepaintBoundary(
              key: markerKey,
              child: i,
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<List<Uint8List>> _getBitmaps(BuildContext context) async {
    var futures = globalKeys.map((key) => _getUint8List(key));
    return Future.wait(futures);
  }

  Future<Uint8List> _getUint8List(GlobalKey markerKey) async {
    RenderRepaintBoundary boundary =
        markerKey.currentContext.findRenderObject();
    var image = await boundary.toImage(pixelRatio: 2.0);
    ByteData byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData.buffer.asUint8List();
  }
}

/// AfterLayoutMixin
mixin AfterLayoutMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => afterFirstLayout(context));
  }

  void afterFirstLayout(BuildContext context);
}
