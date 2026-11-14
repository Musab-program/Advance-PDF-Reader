import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class NoInternetException implements Exception {
  final String message;
  NoInternetException([this.message = 'لا يوجد اتصال بالإنترنت']);
  @override
  String toString() => message;
}

class OperationCancelledException implements Exception {
  final String message;
  OperationCancelledException([this.message = 'تم إلغاء العملية']);
  @override
  String toString() => message;
}

class HfTokenTestResult {
  final bool isValid;
  final String? username;
  final bool hasInferencePermission;
  final String? errorMessage;

  HfTokenTestResult({
    required this.isValid,
    this.username,
    required this.hasInferencePermission,
    this.errorMessage,
  });
}

class _GradioSpaceConfig {
  final String baseUrl;
  final String callEndpoint;
  final int outputIndex;

  const _GradioSpaceConfig({
    required this.baseUrl,
    required this.callEndpoint,
    required this.outputIndex,
  });
}

class _AuthException implements Exception {
  final String message;
  _AuthException(this.message);
  @override
  String toString() => message;
}

class _PostProcessInput {
  final Uint8List originalBytes;
  final Uint8List serverPngBytes;

  const _PostProcessInput({
    required this.originalBytes,
    required this.serverPngBytes,
  });
}

class HuggingFaceBgRemoverService {
  static HttpClient? _activeClient;
  static int _requestEpoch = 0;

  // Primary responsive endpoint + fast secondary endpoint on same healthy host
  static const List<_GradioSpaceConfig> _spaces = [
    _GradioSpaceConfig(
      baseUrl: 'https://not-lain-background-removal.hf.space',
      callEndpoint: 'png',
      outputIndex: 0,
    ),
    _GradioSpaceConfig(
      baseUrl: 'https://not-lain-background-removal.hf.space',
      callEndpoint: 'image',
      outputIndex: 0,
    ),
  ];

  /// Immediately aborts any in-flight HTTP request and increments the request epoch
  /// so fallback loops stop cleanly without further network calls.
  static void abortActiveRequest() {
    _requestEpoch++;
    try {
      _activeClient?.close(force: true);
    } catch (_) {}
    _activeClient = null;
  }

  /// Checks whether the device has active internet connectivity (fast 3s DNS probe).
  static Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('huggingface.co')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Tests whether the provided Hugging Face token is valid and active.
  static Future<HfTokenTestResult> testToken(String token) async {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) {
      return HfTokenTestResult(
        isValid: false,
        hasInferencePermission: false,
        errorMessage: 'يرجى إدخال المفتاح أولاً',
      );
    }

    final connected = await hasInternetConnection();
    if (!connected) {
      return HfTokenTestResult(
        isValid: false,
        hasInferencePermission: false,
        errorMessage: 'لا يوجد اتصال بالإنترنت، يرجى التحقق من الشبكة',
      );
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client
          .getUrl(Uri.parse('https://huggingface.co/api/whoami-v2'))
          .timeout(const Duration(seconds: 10));
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $cleanToken');
      final res = await req.close().timeout(const Duration(seconds: 10));
      final bodyStr = await res.transform(utf8.decoder).join();

      if (res.statusCode != 200) {
        return HfTokenTestResult(
          isValid: false,
          hasInferencePermission: false,
          errorMessage: 'المفتاح غير صحيح أو منتهي الصلاحية',
        );
      }

      final json = jsonDecode(bodyStr) as Map<String, dynamic>;
      final username = json['name'] as String? ?? 'User';

      return HfTokenTestResult(
        isValid: true,
        username: username,
        hasInferencePermission: true,
      );
    } catch (_) {
      return HfTokenTestResult(
        isValid: false,
        hasInferencePermission: false,
        errorMessage: 'تعذر التحقق من الاتصال حالياً، حاول مرة أخرى',
      );
    } finally {
      client.close(force: true);
    }
  }

  /// Removes background remotely with tight timeouts, immediate fallback between
  /// endpoints, and full-resolution edge-guided alpha upsampling + boundary decontamination.
  static Future<Uint8List> removeBackground(
    Uint8List originalBytes, {
    required String token,
    void Function(double progress, String status)? onProgress,
  }) async {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) {
      throw Exception('يرجى إضافة مفتاح الوصول في الإعدادات أولاً');
    }

    // Abort any dangling prior client and capture this call's epoch
    abortActiveRequest();
    final int myEpoch = _requestEpoch;

    onProgress?.call(0.15, 'جاري تجهيز الصورة...');
    final readyBytes = await compute(_prepareImageForApiIsolate, originalBytes);
    if (myEpoch != _requestEpoch) {
      throw OperationCancelledException();
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12)
      ..idleTimeout = const Duration(seconds: 30);
    _activeClient = client;

    try {
      String? lastFriendlyError;
      bool sawSocketError = false;

      for (int i = 0; i < _spaces.length; i++) {
        if (myEpoch != _requestEpoch) {
          throw OperationCancelledException();
        }
        final space = _spaces[i];
        try {
          onProgress?.call(0.32, 'جاري رفع الصورة...');
          final uploadedPath = await _uploadToGradio(
            client: client,
            baseUrl: space.baseUrl,
            token: cleanToken,
            imageBytes: readyBytes,
          );
          if (myEpoch != _requestEpoch) {
            throw OperationCancelledException();
          }

          onProgress?.call(0.50, 'جاري المعالجة بالذكاء الاصطناعي...');
          final eventId = await _submitGradioJob(
            client: client,
            space: space,
            token: cleanToken,
            uploadedPath: uploadedPath,
          );
          if (myEpoch != _requestEpoch) {
            throw OperationCancelledException();
          }

          onProgress?.call(0.68, 'جاري استلام النتيجة...');
          final serverPngBytes = await _pollJobAndDownload(
            client: client,
            space: space,
            eventId: eventId,
            token: cleanToken,
            onProgress: onProgress,
          );
          if (myEpoch != _requestEpoch) {
            throw OperationCancelledException();
          }

          if (serverPngBytes.isNotEmpty) {
            onProgress?.call(0.92, 'جاري تحسين الحواف والدقة...');
            final highResBytes = await compute(
              _postProcessCutoutIsolate,
              _PostProcessInput(
                originalBytes: originalBytes,
                serverPngBytes: serverPngBytes,
              ),
            );
            if (myEpoch != _requestEpoch) {
              throw OperationCancelledException();
            }
            onProgress?.call(1.0, 'تم بنجاح');
            return highResBytes;
          }
        } on _AuthException {
          rethrow;
        } on OperationCancelledException {
          rethrow;
        } on SocketException catch (e) {
          sawSocketError = true;
          lastFriendlyError = _friendlyError(e);
          debugPrint('Remote bg removal attempt $i socket error: $e');
          if (myEpoch != _requestEpoch) {
            throw OperationCancelledException();
          }
        } catch (e) {
          if (myEpoch != _requestEpoch) {
            throw OperationCancelledException();
          }
          lastFriendlyError = _friendlyError(e);
          debugPrint('Remote bg removal attempt $i failed: $e');
        }
      }

      if (sawSocketError) {
        final stillOnline = await hasInternetConnection();
        if (!stillOnline) {
          throw NoInternetException('لا يتوفر اتصال بالإنترنت حالياً');
        }
      }

      throw Exception(lastFriendlyError ?? 'تعذر إتمام المعالجة حالياً، حاول مرة أخرى');
    } finally {
      if (identical(_activeClient, client)) {
        _activeClient = null;
      }
      try {
        client.close(force: true);
      } catch (_) {}
    }
  }

  static Future<String> _uploadToGradio({
    required HttpClient client,
    required String baseUrl,
    required String token,
    required Uint8List imageBytes,
  }) async {
    final uri = Uri.parse('$baseUrl/gradio_api/upload');
    final boundary = '----FlutterHfBoundary${DateTime.now().millisecondsSinceEpoch}';
    final req = await client.postUrl(uri).timeout(const Duration(seconds: 12));
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    req.headers.set(
      HttpHeaders.contentTypeHeader,
      'multipart/form-data; boundary=$boundary',
    );

    final headerBytes = utf8.encode(
      '--$boundary\r\n'
      'Content-Disposition: form-data; name="files"; filename="image.jpg"\r\n'
      'Content-Type: image/jpeg\r\n\r\n',
    );
    final footerBytes = utf8.encode('\r\n--$boundary--\r\n');

    req.contentLength = headerBytes.length + imageBytes.length + footerBytes.length;
    req.add(headerBytes);
    req.add(imageBytes);
    req.add(footerBytes);

    final res = await req.close().timeout(const Duration(seconds: 18));
    final body = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 10));

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw _AuthException('يرجى التحقق من صلاحية المفتاح في الإعدادات');
    }
    if (res.statusCode != 200) {
      throw Exception('الخدمة مشغولة حالياً، يرجى المحاولة بعد قليل');
    }

    final decoded = jsonDecode(body);
    if (decoded is List && decoded.isNotEmpty) {
      return decoded.first.toString();
    }
    throw Exception('تعذر إتمام المعالجة حالياً، حاول مرة أخرى');
  }

  static Future<String> _submitGradioJob({
    required HttpClient client,
    required _GradioSpaceConfig space,
    required String token,
    required String uploadedPath,
  }) async {
    final callUri = Uri.parse('${space.baseUrl}/gradio_api/call/${space.callEndpoint}');
    final req = await client.postUrl(callUri).timeout(const Duration(seconds: 10));
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

    final payload = jsonEncode({
      'data': [
        {
          'path': uploadedPath,
          'meta': {'_type': 'gradio.FileData'},
        }
      ],
    });
    final payloadBytes = utf8.encode(payload);
    req.contentLength = payloadBytes.length;
    req.add(payloadBytes);

    final res = await req.close().timeout(const Duration(seconds: 10));
    final body = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 10));

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw _AuthException('يرجى التحقق من صلاحية المفتاح في الإعدادات');
    }
    if (res.statusCode == 429 || res.statusCode >= 500) {
      throw Exception('الخدمة مشغولة حالياً، يرجى المحاولة بعد قليل');
    }
    if (res.statusCode != 200) {
      throw Exception('تعذر بدء المعالجة، حاول مرة أخرى');
    }

    final callJson = jsonDecode(body) as Map<String, dynamic>;
    final eventId = callJson['event_id'] as String?;
    if (eventId == null || eventId.isEmpty) {
      throw Exception('تعذر إتمام المعالجة حالياً، حاول مرة أخرى');
    }
    return eventId;
  }

  static Future<Uint8List> _pollJobAndDownload({
    required HttpClient client,
    required _GradioSpaceConfig space,
    required String eventId,
    required String token,
    void Function(double progress, String status)? onProgress,
  }) async {
    final sseUri = Uri.parse(
      '${space.baseUrl}/gradio_api/call/${space.callEndpoint}/$eventId',
    );

    final sseReq = await client.getUrl(sseUri).timeout(const Duration(seconds: 12));
    sseReq.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    sseReq.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');

    final sseRes = await sseReq.close().timeout(const Duration(seconds: 22));

    if (sseRes.statusCode == 404 || sseRes.statusCode == 410) {
      throw Exception('انتهت صلاحية جلسة المعالجة، يرجى المحاولة مرة أخرى');
    }
    if (sseRes.statusCode != 200) {
      throw Exception('الخدمة مشغولة حالياً، يرجى المحاولة بعد قليل');
    }

    String? outputUrl;
    String? currentEvent;
    final lineStream = utf8.decoder
        .bind(sseRes)
        .transform(const LineSplitter())
        .timeout(const Duration(seconds: 22));

    await for (final rawLine in lineStream) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('event:')) {
        currentEvent = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        final dataStr = line.substring(5).trim();
        if (currentEvent == 'error') {
          throw Exception('الخدمة مشغولة حالياً، يرجى المحاولة بعد قليل');
        }
        if (currentEvent == 'complete') {
          outputUrl = _extractOutputUrl(dataStr, space);
          break;
        }
      }
    }

    if (outputUrl == null || outputUrl.isEmpty) {
      throw Exception('لم تكتمل الاستجابة من الخادم، يرجى المحاولة مرة أخرى');
    }

    onProgress?.call(0.84, 'جاري تحميل النتيجة...');
    return _downloadFile(
      client: client,
      url: outputUrl,
      token: token,
    );
  }

  static String? _extractOutputUrl(String dataStr, _GradioSpaceConfig space) {
    try {
      final decoded = jsonDecode(dataStr);
      if (decoded is! List || decoded.length <= space.outputIndex) return null;
      dynamic item = decoded[space.outputIndex];
      if (item is List && item.isNotEmpty) {
        item = item.first;
      }
      if (item is Map) {
        final url = item['url']?.toString();
        if (url != null && url.isNotEmpty) return url;
        final path = item['path']?.toString();
        if (path != null && path.isNotEmpty) {
          return '${space.baseUrl}/gradio_api/file=$path';
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<Uint8List> _downloadFile({
    required HttpClient client,
    required String url,
    required String token,
  }) async {
    final req = await client.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 15));
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    final res = await req.close().timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('تعذر استلام النتيجة، يرجى المحاولة مرة أخرى');
    }

    final List<int> bytes = [];
    await for (final chunk in res.timeout(const Duration(seconds: 15))) {
      bytes.addAll(chunk);
    }
    return Uint8List.fromList(bytes);
  }

  static String _friendlyError(Object e) {
    final raw = e.toString().replaceFirst('Exception: ', '');
    if (raw.contains('المفتاح') ||
        raw.contains('إنترنت') ||
        raw.contains('مشغولة') ||
        raw.contains('انتهت')) {
      return raw;
    }
    return 'تعذر إتمام المعالجة حالياً، حاول مرة أخرى';
  }
}

// ── Background Isolate: Resizes upload to <= 1024px (native BiRefNet scale) for ~45% faster transfer ──
Uint8List _prepareImageForApiIsolate(Uint8List rawBytes) {
  final rawDecoded = img.decodeImage(rawBytes);
  if (rawDecoded == null) return rawBytes;
  final decoded = img.bakeOrientation(rawDecoded);

  const maxDim = 1024;
  if (decoded.width <= maxDim && decoded.height <= maxDim) {
    return Uint8List.fromList(img.encodeJpg(decoded, quality: 86));
  }

  final double scale =
      maxDim / (decoded.width > decoded.height ? decoded.width : decoded.height);
  final resized = img.copyResize(
    decoded,
    width: math.max(1, (decoded.width * scale).round()),
    height: math.max(1, (decoded.height * scale).round()),
    interpolation: img.Interpolation.linear,
  );

  return Uint8List.fromList(img.encodeJpg(resized, quality: 86));
}

// ── Background Isolate: Upsamples AI alpha mask to full-res original RGB with edge guidance + 5x5 decontamination ──
Uint8List _postProcessCutoutIsolate(_PostProcessInput input) {
  final rawOrig = img.decodeImage(input.originalBytes);
  final rawServer = img.decodeImage(input.serverPngBytes);
  if (rawOrig == null || rawServer == null) {
    return input.serverPngBytes;
  }

  var orig = img.bakeOrientation(rawOrig);
  const int maxOutputDim = 2048;
  if (orig.width > maxOutputDim || orig.height > maxOutputDim) {
    final scale = maxOutputDim / (orig.width > orig.height ? orig.width : orig.height);
    orig = img.copyResize(
      orig,
      width: math.max(1, (orig.width * scale).round()),
      height: math.max(1, (orig.height * scale).round()),
      interpolation: img.Interpolation.linear,
    );
  }

  final origRgbaImg = orig.convert(format: img.Format.uint8, numChannels: 4);
  final serverRgbaImg = rawServer.convert(format: img.Format.uint8, numChannels: 4);

  final int w = origRgbaImg.width;
  final int h = origRgbaImg.height;
  final int sw = serverRgbaImg.width;
  final int sh = serverRgbaImg.height;

  final Uint8List origBytes = origRgbaImg.getBytes(order: img.ChannelOrder.rgba);
  final Uint8List serverBytes = serverRgbaImg.getBytes(order: img.ChannelOrder.rgba);

  final Uint8List serverAlpha = Uint8List(sw * sh);
  for (int i = 0; i < serverAlpha.length; i++) {
    serverAlpha[i] = serverBytes[(i << 2) + 3];
  }

  // Respect any existing transparency on source image (intersection with AI alpha)
  final Uint8List upsampledAlpha = _upsampleAlphaEdgeGuided(
    origRgba: origBytes,
    w: w,
    h: h,
    serverAlpha: serverAlpha,
    sw: sw,
    sh: sh,
  );

  final Uint8List outRgba = Uint8List(w * h * 4);
  const double colorSigmaSq2 = 2.0 * 32.0 * 32.0;

  for (int y = 0; y < h; y++) {
    final int rowOffset = y * w;
    for (int x = 0; x < w; x++) {
      final int pi = rowOffset + x;
      final int idx = pi << 2;
      int alpha = upsampledAlpha[pi];
      final int origA = origBytes[idx + 3];
      if (origA < 255) {
        alpha = (alpha * origA) ~/ 255;
      }

      if (alpha == 0) {
        // Zeroed transparent pixel reduces PNG size cleanly
        continue;
      }

      int r = origBytes[idx];
      int g = origBytes[idx + 1];
      int b = origBytes[idx + 2];

      // 5x5 neighborhood foreground color decontamination on semi-transparent boundary pixels
      if (alpha > 12 && alpha < 245) {
        double sumW = 0.0;
        double sumR = 0.0;
        double sumG = 0.0;
        double sumB = 0.0;

        final int y0 = math.max(0, y - 2);
        final int y1 = math.min(h - 1, y + 2);
        final int x0 = math.max(0, x - 2);
        final int x1 = math.min(w - 1, x + 2);

        for (int ny = y0; ny <= y1; ny++) {
          final int nRow = ny * w;
          final int dy = ny - y;
          final int dySq = dy * dy;
          for (int nx = x0; nx <= x1; nx++) {
            final int npi = nRow + nx;
            if (upsampledAlpha[npi] < 245) continue;
            final int nIdx = npi << 2;
            if (origBytes[nIdx + 3] < 245) continue;

            final int dx = nx - x;
            final int distSq = dx * dx + dySq;
            final int dr = origBytes[nIdx] - r;
            final int dg = origBytes[nIdx + 1] - g;
            final int db = origBytes[nIdx + 2] - b;
            final int cSq = dr * dr + dg * dg + db * db;

            final double weight = (1.0 / (1.0 + distSq)) * math.exp(-cSq / colorSigmaSq2);
            sumW += weight;
            sumR += origBytes[nIdx] * weight;
            sumG += origBytes[nIdx + 1] * weight;
            sumB += origBytes[nIdx + 2] * weight;
          }
        }

        if (sumW > 1e-6) {
          final double fgR = sumR / sumW;
          final double fgG = sumG / sumW;
          final double fgB = sumB / sumW;
          final double blend = ((245 - alpha) / 233.0).clamp(0.15, 0.88);
          r = (r * (1.0 - blend) + fgR * blend).round().clamp(0, 255);
          g = (g * (1.0 - blend) + fgG * blend).round().clamp(0, 255);
          b = (b * (1.0 - blend) + fgB * blend).round().clamp(0, 255);
        }
      }

      outRgba[idx] = r;
      outRgba[idx + 1] = g;
      outRgba[idx + 2] = b;
      outRgba[idx + 3] = alpha;
    }
  }

  final outImg = img.Image.fromBytes(
    width: w,
    height: h,
    bytes: outRgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return Uint8List.fromList(img.encodePng(outImg, level: 4));
}

/// Joint bilateral / edge-guided upsampling of the low-res server alpha mask onto
/// full-resolution original RGB pixels so fine contours stay razor-sharp.
Uint8List _upsampleAlphaEdgeGuided({
  required Uint8List origRgba,
  required int w,
  required int h,
  required Uint8List serverAlpha,
  required int sw,
  required int sh,
}) {
  final Uint8List out = Uint8List(w * h);
  if (w == sw && h == sh) {
    out.setAll(0, serverAlpha);
    return out;
  }

  const double rangeSigmaSq2 = 2.0 * 28.0 * 28.0;
  final int maxX = sw - 1;
  final int maxY = sh - 1;

  // Precompute integer full-res anchor coordinates for each server column/row
  final Int32List sxAnchors = Int32List(sw);
  for (int sx = 0; sx < sw; sx++) {
    sxAnchors[sx] = sw > 1 ? ((sx * (w - 1)) / maxX).round().clamp(0, w - 1) : 0;
  }
  final Int32List syAnchors = Int32List(sh);
  for (int sy = 0; sy < sh; sy++) {
    syAnchors[sy] = sh > 1 ? ((sy * (h - 1)) / maxY).round().clamp(0, h - 1) : 0;
  }

  for (int y = 0; y < h; y++) {
    final double fy = (sh > 1 && h > 1) ? (y * maxY) / (h - 1) : 0.0;
    final int y0 = fy.floor().clamp(0, maxY);
    final int y1 = (y0 + 1).clamp(0, maxY);
    final double ty = fy - y0;
    final double invTy = 1.0 - ty;

    final int sRow0 = y0 * sw;
    final int sRow1 = y1 * sw;
    final int oy0 = syAnchors[y0] * w;
    final int oy1 = syAnchors[y1] * w;
    final int dstRow = y * w;

    for (int x = 0; x < w; x++) {
      final double fx = (sw > 1 && w > 1) ? (x * maxX) / (w - 1) : 0.0;
      final int x0 = fx.floor().clamp(0, maxX);
      final int x1 = (x0 + 1).clamp(0, maxX);

      final int a00 = serverAlpha[sRow0 + x0];
      final int a10 = serverAlpha[sRow0 + x1];
      final int a01 = serverAlpha[sRow1 + x0];
      final int a11 = serverAlpha[sRow1 + x1];

      // Fast path for interior/exterior uniform blocks (~90% of pixels)
      if (a00 == a10 && a00 == a01 && a00 == a11) {
        out[dstRow + x] = a00;
        continue;
      }

      final double tx = fx - x0;
      final double invTx = 1.0 - tx;

      final int pIdx = (dstRow + x) << 2;
      final int r = origRgba[pIdx];
      final int g = origRgba[pIdx + 1];
      final int b = origRgba[pIdx + 2];

      final int ax0 = sxAnchors[x0];
      final int ax1 = sxAnchors[x1];

      final int idx00 = (oy0 + ax0) << 2;
      final int idx10 = (oy0 + ax1) << 2;
      final int idx01 = (oy1 + ax0) << 2;
      final int idx11 = (oy1 + ax1) << 2;

      double rangeWeight(int idx) {
        final int dr = origRgba[idx] - r;
        final int dg = origRgba[idx + 1] - g;
        final int db = origRgba[idx + 2] - b;
        return math.exp(-((dr * dr + dg * dg + db * db) / rangeSigmaSq2));
      }

      final double w00 = (invTx * invTy) * (rangeWeight(idx00) + 1e-4);
      final double w10 = (tx * invTy) * (rangeWeight(idx10) + 1e-4);
      final double w01 = (invTx * ty) * (rangeWeight(idx01) + 1e-4);
      final double w11 = (tx * ty) * (rangeWeight(idx11) + 1e-4);

      final double wSum = w00 + w10 + w01 + w11;
      final double blended = (a00 * w00 + a10 * w10 + a01 * w01 + a11 * w11) / wSum;
      out[dstRow + x] = blended.round().clamp(0, 255);
    }
  }

  return out;
}
