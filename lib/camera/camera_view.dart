import 'dart:io';
import 'package:android_image_processing/screens/display_text_screen.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_cropper/image_cropper.dart';

import '../main.dart';

enum ScreenMode { liveFeed, gallery }

class CameraView extends StatefulWidget {
  const CameraView({
    Key? key,
    required this.customPaint,
    required this.customPaint2,
    this.text,
    required this.onImage,
    this.onScreenModeChanged,
    required this.painterFeature,
    required this.controller,
  }) : super(key: key);

  final CustomPaint? customPaint;
  final CustomPaint? customPaint2;
  final String? text;
  final Function(InputImage inputImage) onImage;
  final Function(ScreenMode mode)? onScreenModeChanged;
  final PainterFeature painterFeature;
  final CameraController controller;

  @override
  _CameraViewState createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  /* Camera Preview Variables */
  final ScreenMode _mode = ScreenMode.liveFeed;
  int _cameraIndex = 0;
  double zoomLevel = 0.0, minZoomLevel = 0.0, maxZoomLevel = 0.0;
  bool _changingCameraLens = false;
  /*    */

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _liveFeedBody(),
          if (widget.customPaint != null) widget.customPaint!,
        ],
      ),
      floatingActionButton: _floatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  /* IMAGE CROPPER */
  Future<CroppedFile?> _cropImage(String path) async {
    return await ImageCropper().cropImage(
      sourcePath: path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 100,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          initAspectRatio: CropAspectRatioPreset.original,
          showCropGrid: true,
          toolbarColor: Colors.transparent,
          dimmedLayerColor: const Color.fromARGB(133, 54, 54, 54),
          cropFrameColor: Colors.white,
          cropGridColor: const Color.fromARGB(145, 255, 255, 255),
          cropGridStrokeWidth: 1,
          lockAspectRatio: false,
        )
      ],
    );
  }

  Future<void> _capturePicture() async {
    final picture = await widget.controller.takePicture();
    final croppedImage = await _cropImage(picture.path);
    if (croppedImage == null) return;
    Future.microtask(
      () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: ((context) =>
              DisplayTextScreen(imagePath: croppedImage.path)),
        ),
      ),
    );
  }

  Widget _circleButton() {
    if (widget.painterFeature == PainterFeature.TextRecognition) {
      return GestureDetector(
        onTap: _capturePicture,
        child: const CircleAvatar(
          backgroundColor: Colors.white,
          child: CircleAvatar(
            radius: 38,
            backgroundColor: Colors.black87,
            child: CircleAvatar(
              radius: 34,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _switchLiveCamera,
      child: CircleAvatar(
        backgroundColor: Colors.white,
        child: CircleAvatar(
          radius: 38,
          backgroundColor: Colors.black87,
          child: CircleAvatar(
            radius: 34,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            child: Icon(
              Platform.isIOS
                  ? Icons.flip_camera_ios_outlined
                  : Icons.flip_camera_android_outlined,
              size: 40,
            ),
          ),
        ),
      ),
    );
  }

  Widget? _floatingActionButton() {
    if (_mode == ScreenMode.gallery) return null;
    if (cameras.length == 1) return null;
    return SizedBox(
      height: 80.0,
      width: 80.0,
      child: _circleButton(),
    );
  }

  Widget _liveFeedBody() {
    if (widget.controller.value.isInitialized == false) {
      return Container();
    }

    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * widget.controller.value.aspectRatio;

    if (scale < 1) scale = (1 / scale);

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Transform.scale(
            scale: scale,
            child: Center(
              child: _changingCameraLens
                  ? const Center(
                      child: Text('Changing camera lens'),
                    )
                  : CameraPreview(widget.controller),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            left: 0,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.25,
              width: MediaQuery.of(context).size.width,
              color: const Color.fromARGB(99, 0, 0, 0),
            ),
          ),
          if (widget.customPaint != null) widget.customPaint!,
          if (widget.customPaint2 != null) widget.customPaint2!,
          Positioned(
            bottom: 170,
            left: 50,
            right: 50,
            child: Slider(
              value: zoomLevel,
              min: minZoomLevel,
              max: maxZoomLevel,
              onChanged: (newSliderValue) {
                setState(() {
                  widget.controller.setZoomLevel(newSliderValue);
                });
              },
              divisions: (maxZoomLevel - 1).toInt() < 1
                  ? null
                  : (maxZoomLevel - 1).toInt(),
            ),
          ),
        ],
      ),
    );
  }

  // Future _startLiveFeed() async {
  //   widget.controller.initialize().then((_) {
  //     if (!mounted) {
  //       return;
  //     }
  //     widget.controller.getMinZoomLevel().then((value) {
  //       zoomLevel = value;
  //       minZoomLevel = value;
  //     });
  //     widget.controller.getMaxZoomLevel().then((value) {
  //       maxZoomLevel = value;
  //     });
  //     if (widget.painterFeature != PainterFeature.TextRecognition) {
  //       widget.controller.startImageStream(_processCameraImage);
  //     }
  //     setState(() {});
  //   });
  // }

  // Future _stopLiveFeed() async {
  //   await widget.controller.stopImageStream();
  //   await widget.controller.dispose();
  // }

  Future _switchLiveCamera() async {
    setState(() => _changingCameraLens = true);
    _cameraIndex = (_cameraIndex + 1) % cameras.length;

    // await _stopLiveFeed();
    // await _startLiveFeed();
    setState(() => _changingCameraLens = false);
  }

  // Future _processCameraImage(CameraImage image) async {
  //   final WriteBuffer allBytes = WriteBuffer();
  //   for (final Plane plane in image.planes) {
  //     allBytes.putUint8List(plane.bytes);
  //   }
  //   final bytes = allBytes.done().buffer.asUint8List();

  //   final Size imageSize =
  //       Size(image.width.toDouble(), image.height.toDouble());

  //   final camera = cameras[_cameraIndex];
  //   final imageRotation =
  //       InputImageRotationValue.fromRawValue(camera.sensorOrientation);
  //   if (imageRotation == null) return;

  //   final inputImageFormat =
  //       InputImageFormatValue.fromRawValue(image.format.raw);
  //   if (inputImageFormat == null) return;

  //   final planeData = image.planes.map(
  //     (Plane plane) {
  //       return InputImagePlaneMetadata(
  //         bytesPerRow: plane.bytesPerRow,
  //         height: plane.height,
  //         width: plane.width,
  //       );
  //     },
  //   ).toList();

  //   final inputImageData = InputImageData(
  //     size: imageSize,
  //     imageRotation: imageRotation,
  //     inputImageFormat: inputImageFormat,
  //     planeData: planeData,
  //   );

  //   final inputImage =
  //       InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);

  //   widget.onImage(inputImage);
  // }
}
