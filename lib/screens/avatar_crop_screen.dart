import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimensions.dart';
import '../core/theme/app_text_styles.dart';
import '../core/widgets/primary_button.dart';

/// Lets the user choose which part of a photo becomes their avatar.
///
/// The picked image sits under a circular window: drag to reposition, pinch to
/// zoom. Whatever is inside the circle when they confirm is exported as a
/// square PNG — which is what stops tall photos from letterboxing into black
/// bars inside the avatar.
///
/// Returns the cropped [File] via `Navigator.pop`, or null if cancelled.
///
/// The crop is done with a [ui.PictureRecorder] rather than an image-processing
/// package: the same transform the user sees is replayed onto a canvas, so
/// there is no dependency to add and no risk of the output disagreeing with
/// the preview.
class AvatarCropScreen extends StatefulWidget {
  const AvatarCropScreen({super.key, required this.source});

  /// The image the user picked from their gallery.
  final File source;

  /// Side length of the exported square, in pixels.
  ///
  /// The avatar is stored base64 inside the Firestore user document, so this
  /// stays small deliberately. 384px is sharp at every size the app renders an
  /// avatar (largest is a 68px-diameter circle, so ~3x on a high-DPI screen)
  /// while keeping the PNG comfortably under the repository's 700 KB ceiling —
  /// base64 inflates bytes by about a third, and Firestore documents cap at
  /// 1 MB.
  static const int outputSize = 384;

  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<AvatarCropScreen> {
  /// Drives pan/zoom, and is also the source of truth for the export — the
  /// exported crop replays this exact matrix, so preview and result can't
  /// diverge.
  final TransformationController _controller = TransformationController();

  ui.Image? _image;
  bool _loadFailed = false;
  bool _saving = false;

  /// Side length of the on-screen crop window, set during layout.
  double _viewport = 0;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _controller.dispose();
    _image?.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      final Uint8List bytes = await widget.source.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _image = frame.image);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  /// Renders the region currently framed by the circle to a square PNG.
  ///
  /// Replays the interactive transform onto a canvas scaled from the on-screen
  /// viewport to [AvatarCropScreen.outputSize], so what the user framed is
  /// exactly what gets written.
  Future<void> _confirm() async {
    final ui.Image? image = _image;
    if (image == null || _viewport <= 0 || _saving) return;
    setState(() => _saving = true);

    try {
      final double out = AvatarCropScreen.outputSize.toDouble();
      final double scale = out / _viewport;

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Rect outRect = Rect.fromLTWH(0, 0, out, out);
      final Canvas canvas = Canvas(recorder, outRect);

      // Opaque backdrop: a PNG with transparent corners would show through as
      // grey once composited into the circular avatar.
      canvas.drawRect(outRect, Paint()..color = AppColors.surface);

      canvas.scale(scale);
      canvas.transform(_controller.value.storage);

      // BoxFit.contain matches how InteractiveViewer lays the image out at
      // identity, so the recorded frame lines up with the preview.
      final FittedSizes fitted = applyBoxFit(
        BoxFit.contain,
        Size(image.width.toDouble(), image.height.toDouble()),
        Size(_viewport, _viewport),
      );
      final Rect dest = Alignment.center.inscribe(
        fitted.destination,
        Rect.fromLTWH(0, 0, _viewport, _viewport),
      );
      canvas.drawImageRect(
        image,
        Alignment.center.inscribe(
          fitted.source,
          Rect.fromLTWH(
            0,
            0,
            image.width.toDouble(),
            image.height.toDouble(),
          ),
        ),
        dest,
        Paint()..filterQuality = FilterQuality.high,
      );

      final ui.Image cropped = await recorder
          .endRecording()
          .toImage(AvatarCropScreen.outputSize, AvatarCropScreen.outputSize);
      final ByteData? data =
          await cropped.toByteData(format: ui.ImageByteFormat.png);
      cropped.dispose();

      if (data == null) throw StateError('encode failed');

      // Written beside the original in the temp dir; the picker's files are
      // already temporary, so nothing here needs cleaning up by us.
      final File outFile = File(
        '${widget.source.parent.path}/avatar_crop_'
        '${widget.source.uri.pathSegments.last}.png',
      );
      await outFile.writeAsBytes(data.buffer.asUint8List(), flush: true);

      if (!mounted) return;
      Navigator.pop(context, outFile);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text("Couldn't crop that image.")),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.textPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.onPrimary,
        title: const Text('Adjust photo'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _stage()),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.spaceXl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Drag to reposition · pinch to zoom',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.onPrimary.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceL),
                  PrimaryButton(
                    text: 'Use photo',
                    isLoading: _saving,
                    onPressed: _image == null ? null : _confirm,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stage() {
    if (_loadFailed) {
      return Center(
        child: Text(
          "Couldn't open that image.",
          style: AppTextStyles.body.copyWith(color: AppColors.onPrimary),
        ),
      );
    }
    if (_image == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.secondary),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Square window, inset so the user can see a little of the photo
        // outside the crop while positioning it.
        final double side = constraints.biggest.shortestSide -
            AppDimensions.spaceXxl * 2;
        _viewport = side;

        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: Stack(
              fit: StackFit.expand,
              children: [
                InteractiveViewer(
                  transformationController: _controller,
                  minScale: 1,
                  maxScale: 5,
                  // Lets the user pull an edge of the photo into the middle of
                  // the circle, which is the whole point of repositioning.
                  boundaryMargin: EdgeInsets.all(side),
                  clipBehavior: Clip.none,
                  child: RawImage(image: _image, fit: BoxFit.contain),
                ),
                // Dim + circular cut-out, painted above the photo.
                IgnorePointer(
                  child: CustomPaint(
                    painter: _CircleMaskPainter(),
                    size: Size(side, side),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Dims everything outside an inscribed circle and rings it in the brand color.
class _CircleMaskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final double radius = size.shortestSide / 2;
    final Offset center = rect.center;

    // even-odd fill: the square minus the circle, so only the outside dims.
    final Path mask = Path.combine(
      PathOperation.difference,
      Path()..addRect(rect),
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawPath(
      mask,
      Paint()..color = AppColors.textPrimary.withValues(alpha: 0.72),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.onPrimary.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant _CircleMaskPainter oldDelegate) => false;
}
