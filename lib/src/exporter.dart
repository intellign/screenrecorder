import 'dart:ui' as ui show ImageByteFormat;
import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:screen_recorder/src/constants.dart';
import 'package:screen_recorder/src/render_type.dart';

import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

class Exporter with ChangeNotifier {
  bool loading = false, isPlaying = false;

  Future<Map<String, dynamic>> mergeIntoVideo({
    required RenderType renderType,
  }) async {
    loading = true;
    notifyListeners();

    /// get application temp directory
    Directory appDocDirectory = await getTemporaryDirectory();
    String dir = appDocDirectory.path;

    basePath = "$dir/";

    ///////final FlutterFFmpeg _flutterFFmpeg = FlutterFFmpeg();

    if (await Permission.storage.request().isGranted) {
      /// mp4 output
      String mp4Command =
          '-r 50 -i ${Constants.imagesPath} -vf scale=1920:1080 -pix_fmt yuv420p -y ${Constants.videoOutputPath}';

      /// 7mb gif output
      String gifCommand =
          '-r 50 -i ${Constants.imagesPath} -vf "scale=iw/2:ih/2" -y ${Constants.gifOutputPath}';

      /// Replacing audio stream
      /// -c:v copy -c:a aac -map 0:v:0 -map 1:a:0

      /// To combine audio with video
      //   String commandToExecute =
      //     '-r 15 -f mp4 -i ${Constants.VIDEO_PATH} -f mp3 -i ${Constants.AUDIO_PATH} -c:v copy -c:a aac -map 0:v:0 -map 1:a:0 -t $timeLimit -y ${Constants.OUTPUT_PATH}';

      /// To combine audio with image
      // String commandToExecute =
      //     '-r 15 -f mp3 -i ${Constants.AUDIO_PATH} -f image2 -i ${Constants.IMAGE_PATH} -pix_fmt yuv420p -t $timeLimit -y ${Constants.OUTPUT_PATH}';

      /// To combine audio with gif
      // String commandToExecute = '-r 15 -f mp3 -i ${Constants
      //     .AUDIO_PATH} -f gif -re -stream_loop 5 -i ${Constants.GIF_PATH} -y ${Constants
      //     .OUTPUT_PATH}';

      /// To combine audio with sequence of images
      // String commandToExecute = '-r 30 -pattern_type sequence -start_number 01 -f image2 -i ${Constants
      //     .IMAGES_PATH} -f mp3 -i ${Constants.AUDIO_PATH} -y ${Constants
      //     .OUTPUT_PATH}';

      var response = await FFmpegKit.execute(

              ///_flutterFFmpeg   /// await FFmpegKit
              renderType == RenderType.gif ? gifCommand : mp4Command)
          .then((rc) async {
        loading = false;
        notifyListeners();
        debugPrint(
            'FFmpeg process exited with rc ==> ${await rc.getReturnCode()}');
        debugPrint('FFmpeg process exited with rc ==> ${rc.getCommand()}');
        var res = await rc.getReturnCode();

        if (res!.getValue() == 0) {
          return {
            'success': true,
            'msg': 'Widget was render successfully.',
            'outPath': renderType == RenderType.gif
                ? Constants.gifOutputPath
                : Constants.videoOutputPath
          };
        } else if (res.getValue() == 1) {
          return {'success': false, 'msg': 'Widget was render unsuccessfully.'};
        } else {
          return {'success': false, 'msg': 'Widget was render unsuccessfully.'};
        }
      });

      return response;
    } else if (await Permission.storage.isPermanentlyDenied) {
      loading = false;
      notifyListeners();
      openAppSettings();
      return {'success': false, 'msg': 'Missing storage permission.'};
    } else {
      return {'success': false, 'msg': 'unknown error.'};
    }
  }
}
