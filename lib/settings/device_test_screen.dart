import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:v_meeting/meeting/meeting_media.dart';
import 'device_test_session.dart';
import 'media_preferences.dart';
import 'media_privacy.dart';

class DeviceTestScreen extends StatefulWidget {
  const DeviceTestScreen({super.key, required this.camera});
  final bool camera;

  @override
  State<DeviceTestScreen> createState() => _DeviceTestScreenState();
}

class _DeviceTestScreenState extends State<DeviceTestScreen>
    with WidgetsBindingObserver {
  final _renderer = rtc.RTCVideoRenderer();
  late final Future<void> _rendererReady;
  List<rtc.MediaDeviceInfo> _devices = [];
  String? _selected;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  bool _releasing = false;
  Object? _rendererFailure;
  bool _readingLevel = false;
  double? _level;
  DeviceTestSession? _session;
  Timer? _timer;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _rendererReady = widget.camera
        ? _renderer.initialize().catchError((Object error) {
            _rendererFailure = error;
          })
        : Future.value();
    _load();
  }

  Future<void> _load() async {
    try {
      final preferences = await MediaPreferences.load();
      final devices = await rtc.navigator.mediaDevices.enumerateDevices();
      final kind = widget.camera ? 'videoinput' : 'audioinput';
      final unique = <String, rtc.MediaDeviceInfo>{};
      for (final device in devices) {
        if (device.kind == kind && device.deviceId.isNotEmpty) {
          unique[device.deviceId] = device;
        }
      }
      final selected = widget.camera
          ? preferences.cameraId
          : preferences.microphoneId;
      if (!mounted) return;
      setState(() {
        _devices = unique.values.toList();
        _selected = selected;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = mediaCaptureError(error, camera: widget.camera);
        });
      }
    }
  }

  Future<void> _start() async {
    if (_busy || _releasing || _session != null) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      _level = null;
    });
    DeviceTestSession? session;
    try {
      await _rendererReady;
      if (!mounted || generation != _generation) return;
      if (_rendererFailure != null) throw _rendererFailure!;
      session = await DeviceTestSession.start(
        camera: widget.camera,
        deviceId: _selected,
      );
      if (!mounted || generation != _generation) {
        await session.stop();
        return;
      }
      _session = session;
      if (widget.camera) {
        _renderer.srcObject = session.stream;
      } else {
        _timer = Timer.periodic(
          const Duration(milliseconds: 150),
          (_) => _readLevel(),
        );
      }
      setState(() {});
    } catch (error) {
      await session?.stop();
      if (identical(_session, session)) _session = null;
      if (mounted && generation == _generation) {
        setState(
          () => _error = mediaCaptureError(error, camera: widget.camera),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _readLevel() async {
    final session = _session;
    if (session == null || _readingLevel) return;
    _readingLevel = true;
    try {
      final level = await session.readLevel();
      if (mounted && identical(session, _session)) {
        setState(() => _level = level);
      }
    } catch (_) {
      // A closing or unsupported meter must not interrupt capture cleanup.
    } finally {
      _readingLevel = false;
    }
  }

  Future<void> _stop() async {
    ++_generation;
    _timer?.cancel();
    final session = _session;
    _session = null;
    if (session != null) _releasing = true;
    if (widget.camera && _renderer.textureId != null) {
      _renderer.srcObject = null;
    }
    if (mounted) {
      setState(() {
        _level = null;
      });
    }
    await session?.stop();
    if (session != null && mounted) setState(() => _releasing = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_stop());
    if (state == AppLifecycleState.resumed && !_busy) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ++_generation;
    _timer?.cancel();
    final session = _session;
    _session = null;
    unawaited(session?.stop());
    if (widget.camera) {
      unawaited(
        _rendererReady
            .then((_) => _renderer.dispose())
            .catchError((Object _) {}),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.camera ? 'Kamera' : 'Mikrofon';
    final running = _session != null;
    final busy = _busy || _releasing;
    final selectedMissing =
        _selected != null && !_devices.any((d) => d.deviceId == _selected);
    return Scaffold(
      appBar: AppBar(title: Text('$name testi ve cihaz seçimi')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Seçiminiz kaydedilir ve bir sonraki toplantıda kullanılır. Test yalnızca bu cihazda çalışır; sunucuya ses veya görüntü gönderilmez.',
          ),
          const SizedBox(height: 20),
          if (_loading) const LinearProgressIndicator(),
          DropdownButtonFormField<String>(
            key: ValueKey('${widget.camera}:$_selected'),
            initialValue: _selected ?? '',
            isExpanded: true,
            decoration: InputDecoration(labelText: '$name tercihi'),
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('Sistem varsayılanı'),
              ),
              if (selectedMissing)
                DropdownMenuItem(
                  value: _selected,
                  child: const Text('Kayıtlı cihaz bağlı değil'),
                ),
              ..._devices.asMap().entries.map(
                (entry) => DropdownMenuItem(
                  value: entry.value.deviceId,
                  child: Text(
                    entry.value.label.isEmpty
                        ? '$name ${entry.key + 1}'
                        : entry.value.label,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: busy || running || _loading
                ? null
                : (value) async {
                    final selected = value == '' ? null : value;
                    try {
                      await MediaPreferences.select(
                        camera: widget.camera,
                        deviceId: selected,
                      );
                      if (mounted) {
                        setState(() {
                          _selected = selected;
                          _error = null;
                        });
                      }
                    } catch (_) {
                      if (mounted) {
                        setState(
                          () => _error =
                              'Cihaz tercihi kaydedilemedi. Tekrar deneyin.',
                        );
                      }
                    }
                  },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: busy || running ? null : _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Cihazları yenile'),
            ),
          ),
          if (widget.camera)
            SizedBox(
              height: 280,
              child: ColoredBox(
                color: Colors.black,
                child: running
                    ? rtc.RTCVideoView(
                        _renderer,
                        mirror: true,
                        objectFit: rtc
                            .RTCVideoViewObjectFit
                            .RTCVideoViewObjectFitContain,
                      )
                    : const Center(
                        child: Icon(
                          Icons.videocam_off,
                          color: Colors.white54,
                          size: 48,
                        ),
                      ),
              ),
            ),
          if (!widget.camera && running) ...[
            const Text(
              'Konuşun; ses seviyesi çubuğunun hareket ettiğini kontrol edin.',
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _level == null ? 0 : math.sqrt(_level!),
            ),
            const SizedBox(height: 8),
            Text(
              _level == null
                  ? 'Mikrofon açık. Ses seviyesi bekleniyor; bazı sürücüler seviye bilgisi sağlamayabilir.'
                  : _level! > 0.01
                  ? 'Mikrofondan ses alınıyor.'
                  : 'Mikrofon açık, şu anda sessiz.',
            ),
          ],
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FilledButton.icon(
            onPressed: busy || _loading
                ? null
                : running
                ? _stop
                : _start,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(running ? Icons.stop : Icons.play_arrow),
            label: Text(
              busy
                  ? 'Cihaz açılıyor…'
                  : running
                  ? 'Testi durdur'
                  : 'Testi başlat',
            ),
          ),
          if (isWindowsDesktop) ...[
            const SizedBox(height: 16),
            Text(
              'Windows erişimi kapalıysa $name erişimini ve masaüstü uygulamalarının erişimini açın. Sonra buraya dönüp testi yeniden başlatın.',
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await _stop();
                final opened = await openMediaPrivacy(camera: widget.camera);
                if (!opened && mounted) {
                  setState(
                    () => _error =
                        'Windows ayarları açılamadı. Ayarlar > Gizlilik ve güvenlik > $name bölümünü açın.',
                  );
                }
              },
              icon: const Icon(Icons.privacy_tip_outlined),
              label: Text('Windows $name gizlilik ayarlarını aç'),
            ),
          ],
        ],
      ),
    );
  }
}
