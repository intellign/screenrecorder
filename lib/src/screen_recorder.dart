import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:screen_recorder/src/exporter.dart';
import 'package:screen_recorder/src/constants.dart';
import 'package:screen_recorder/src/render_type.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:ui' as ui show Image, ImageByteFormat;

class ScreenRecorderController {
  ScreenRecorderController({
    this.pixelRatio = 3.0,
    //  this.skipFramesBetweenCaptures = 2,
    SchedulerBinding? binding,
  })  : _containerKey = GlobalKey(),
        _binding = binding ?? SchedulerBinding.instance;

  final GlobalKey _containerKey;
  final SchedulerBinding _binding;

  /// The pixelRatio describes the scale between the logical pixels and the size
  /// of the output image. Specifying 1.0 will give you a 1:1 mapping between
  /// logical pixels and the output pixels in the image. The default is a pixel
  /// ration of 3 and a value below 1 is not recommended.
  ///
  /// See [RenderRepaintBoundary](https://api.flutter.dev/flutter/rendering/RenderRepaintBoundary/toImage.html)
  /// for the underlying implementation.
  final double pixelRatio;

  /// Describes how many frames are skipped between caputerd frames.
  /// For example if it's `skipFramesBetweenCaptures = 2` screen_recorder
  /// captures a frame, skips the next two frames and then captures the next
  /// frame again.
  ////////////////// final int skipFramesBetweenCaptures;

  /// save frames
  final List<ui.Image> _frames = [];

  bool _record = false;

  void start() {
    // only start a video, if no recording is in progress
    if (_record == true) {
      return;
    }
    _record = true;
    _binding.addPostFrameCallback(postFrameCallback);
  }

  void stop() {
    _record = false;
  }

  void postFrameCallback(Duration timestamp) async {
    if (_record == false) {
      return;
    }

    try {
      final image = await capture();
      if (image == null) {
        print('capture returned null');
        return;
      }
      _frames.add(image);
    } catch (e) {
      print(e.toString());
    }
    _binding.addPostFrameCallback(postFrameCallback);
  }

  /// capture widget to render
  Future<ui.Image?> capture() async {
    final renderObject = _containerKey.currentContext?.findRenderObject();

    if (renderObject is RenderRepaintBoundary) {
      final image = await renderObject.toImage(pixelRatio: 3.0);
      return image;
    } else {
      FlutterError.reportError(_noRenderObject());
    }
    return null;
  }

  /// error details
  FlutterErrorDetails _noRenderObject() {
    return FlutterErrorDetails(
      exception: Exception(
        '_containerKey.currentContext is null. '
        'Thus we can\'t create a screenshot',
      ),
      library: 'feedback',
      context: ErrorDescription(
        'Tried to find a context to use it to create a screenshot',
      ),
    );
  }

  /// export widget
  Future<Map<String, dynamic>> export({required RenderType renderType}) async {
    int timestamp = DateTime.now().millisecondsSinceEpoch.toInt();

    String dir;
    String imagePath;
    List<File> imageFiles = [];
    List<List<int>> imageFilesBytes = [];
    List<Size> imageFilesSize = [];

    /// get application temp directory
    Directory appDocDirectory = await getTemporaryDirectory();
    dir = appDocDirectory.path;

    basePath = "$dir/";

    /// delete last directory
    if (appDocDirectory.existsSync()) {
      try {
        appDocDirectory.deleteSync(recursive: true);
      } catch (e) {}
    }

    /// create new directory
    appDocDirectory.create();

    /// iterate all frames
    for (int i = 0; i < _frames.length; i++) {
      /// convert frame to byte data png
      final val = await _frames[i].toByteData(format: ui.ImageByteFormat.png);

      /// convert frame to buffer list
      Uint8List pngBytes = val!.buffer.asUint8List();

      /// create temp path for every frame
      imagePath = '$dir/$i.png';

      /// create image frame in the temp directory
      File capturedFile = File(imagePath);
      await capturedFile.writeAsBytes(pngBytes);
    }

    /// clear frame list
    _frames.clear();

    /// render frames.png to video/gif
    var response = await Exporter().mergeIntoVideo(
      renderType: renderType,
    );

    /// return
    return response;
  }
}

class ScreenRecorder extends StatelessWidget {
  ScreenRecorder({
    Key? key,
    required this.child,
    required this.controller,
    required this.width,
    required this.height,
    this.background = Colors.white,
  })  : assert(background.alpha == 255,
            'background color is not allowed to be transparent'),
        super(key: key);

  /// The child which should be recorded.
  final Widget child;

  /// This controller starts and stops the recording.
  final ScreenRecorderController controller;

  /// Width of the recording.
  /// This should not change during recording as it could lead to
  /// undefined behavior.
  final double width;

  /// Height of the recording
  /// This should not change during recording as it could lead to
  /// undefined behavior.
  final double height;

  /// The background color of the recording.
  /// Transparency is currently not supported.
  final Color background;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: controller._containerKey,
      child: Container(
        width: width,
        height: height,
        color: Colors.black, //background
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
