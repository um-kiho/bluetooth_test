import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MaterialApp(
    home: ScanScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  // Store scan results
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;

  @override
  void initState() {
    super.initState();
    // Setup listeners
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      // 핫 리로드(Hot Reload) 시 즉각적인 필터 반영을 위해 필터링 로직은 build 메서드 안으로 이동합니다.
      _scanResults = results;
      if (mounted) setState(() {});
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      _isScanning = state;
      if (mounted) setState(() {});
    });

    // Check permissions immediately
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // Request Bluetooth and Location permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    // Check if all permissions are granted
    bool allGranted = statuses.values.every((status) => status.isGranted);

    if (!allGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('블루투스 권한이 필요합니다. 설정에서 권한을 허용해주세요.'),
          duration: Duration(seconds: 5),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _scanResultsSubscription.cancel();
    _isScanningSubscription.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    print(">>> _startScan 호출됨");
    try {
      // Check if Bluetooth is supported
      bool supported = await FlutterBluePlus.isSupported;
      print(">>> 블루투스 지원 여부: $supported");
      if (supported == false) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이 기기는 블루투스를 지원하지 않습니다.')),
          );
        }
        return;
      }

      // Check if Bluetooth is on
      var adapterState = await FlutterBluePlus.adapterState.first;
      print(">>> 현재 블루투스 상태: $adapterState");
      if (adapterState != BluetoothAdapterState.on) {
        print(">>> 블루투스가 꺼져 있습니다.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('블루투스를 켜주세요!'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        // 웹 환경에서는 turnOn()이 동작하지 않을 수 있으므로 주의
        try {
          await FlutterBluePlus.turnOn();
        } catch (e) {
          print(">>> turnOn() 호출 실패 (웹에서는 지원되지 않을 수 있음): $e");
        }
        return;
      }

      print(">>> FlutterBluePlus.startScan 호출 시작...");
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
      );
      print(">>> FlutterBluePlus.startScan 호출 완료!");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('블루투스 장치 검색 중...'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      print(">>> _startScan 중 예외 발생: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('스캔 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  void _onDeviceTap(BluetoothDevice device) {
    _stopScan();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DeviceScreen(device: device),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 핫 리로드 시 필터가 즉시 적용되도록 build 내에서 필터링을 수행합니다.
    final filteredResults = _scanResults.where((r) {
      // [전체 검색 모드] 모든 필터를 해제하여 발견된 모든 기기를 화면에 표시합니다.
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Lamp Controller'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _startScan,
        child: filteredResults.isEmpty
            ? ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  Icon(
                    _isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isScanning
                        ? '블루투스 장치 검색 중...'
                        : '아래 버튼을 눌러\n블루투스 장치를 검색하세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!_isScanning)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 60),
                      child: Text(
                        '※ 블루투스와 위치 서비스가 켜져 있는지 확인하세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ),
                ],
              )
            : ListView.separated(
                itemCount: filteredResults.length,
                separatorBuilder: (c, i) => const Divider(),
                itemBuilder: (context, index) {
                  final result = filteredResults[index];
                  String aName = result.advertisementData.advName.trim();
                  String pName = result.device.platformName.trim();
                  // OS가 캐시한 platformName보다, 기기가 방금 브로드캐스트한 advName을 무조건 우선 표시
                  final name = aName.isNotEmpty ? aName : (pName.isNotEmpty ? pName : result.device.remoteId.str);
                  return ListTile(
                    leading: const Icon(Icons.bluetooth, color: Colors.indigo),
                    title: Text(name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(result.device.remoteId.str),
                    trailing: Text('${result.rssi} dBm'),
                    onTap: () => _onDeviceTap(result.device),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isScanning ? _stopScan : _startScan,
        backgroundColor: _isScanning ? Colors.red : Colors.indigo,
        child:
            Icon(_isScanning ? Icons.stop : Icons.search, color: Colors.white),
      ),
    );
  }
}

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceScreen({super.key, required this.device});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  bool _isConnecting = false;
  late StreamSubscription<BluetoothConnectionState> _connectionStateSubscription;

  BluetoothCharacteristic? _sendChar; // 0xFF31
  List<BluetoothCharacteristic> _recvChars = []; // 0xFF20, 0xFF21, 0xFF22, 0xFF30 등
  final List<StreamSubscription<List<int>>> _valueSubscriptions = [];
  String _debugUUIDs = ""; // 디버깅용으로 발견된 모든 UUID를 저장할 변수

  // Receive Log Monitor
  final List<Map<String, dynamic>> _recvLogs = [];
  final ScrollController _logScrollController = ScrollController();

  // Form Controllers
  final TextEditingController _didCtrl = TextEditingController();
  final TextEditingController _devIdCtrl = TextEditingController();
  final TextEditingController _userIdCtrl = TextEditingController();
  final TextEditingController _ssidCtrl = TextEditingController();
  final TextEditingController _pswdCtrl = TextEditingController();
  final TextEditingController _ipCtrl = TextEditingController();
  final TextEditingController _portCtrl = TextEditingController();
  final TextEditingController _testAsciiCtrl = TextEditingController();

  // Focus Nodes
  final FocusNode _didFocus = FocusNode();
  final FocusNode _devIdFocus = FocusNode();
  final FocusNode _userIdFocus = FocusNode();
  final FocusNode _ssidFocus = FocusNode();
  final FocusNode _pswdFocus = FocusNode();
  final FocusNode _ipFocus = FocusNode();
  final FocusNode _portFocus = FocusNode();
  final FocusNode _testAsciiFocus = FocusNode();

  List<FocusNode> get _focusNodes => [
        _didFocus,
        _devIdFocus,
        _userIdFocus,
        _ssidFocus,
        _pswdFocus,
        _ipFocus,
        _portFocus,
        _testAsciiFocus
      ];
  int _currentFocusIndex = 0;

  @override
  void initState() {
    super.initState();
    _connectionStateSubscription = widget.device.connectionState.listen((state) {
      print(">>> 연결 상태 변화: $state");
      _connectionState = state;
      if (state == BluetoothConnectionState.connected) {
        print(">>> 연결됨! _discoverSpecificServices()를 호출합니다.");
        _discoverSpecificServices();
      }
      if (mounted) setState(() {});
    });
    _connect();
  }

  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
    });
    try {
      await widget.device.connect(license: License.free);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('연결 실패: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  Future<void> _discoverSpecificServices() async {
    print(">>> 서비스 검색 시작 (1초 대기 후 호출)...");
    await Future.delayed(const Duration(seconds: 1)); // 안드로이드 안정성을 위한 지연
    
    try {
      List<BluetoothService> services = await widget.device.discoverServices();
      print(">>> 발견된 서비스 개수: ${services.length}");
      StringBuffer debugLog = StringBuffer();
      
      _recvChars.clear();
      for (var sub in _valueSubscriptions) {
        sub.cancel();
      }
      _valueSubscriptions.clear();

      for (var s in services) {
        String sUuid = s.uuid.toString().toUpperCase();
        String serviceLabel = "";
        
        // 서비스 UUID에 따른 별칭 설정
        if (sUuid.contains("FF20")) serviceLabel = "Smartphone";
        else if (sUuid.contains("FF21")) serviceLabel = "Sensor";
        else if (sUuid.contains("FF22")) serviceLabel = "Extra";
        
        print(">>> 서비스 확인: $sUuid (${serviceLabel.isEmpty ? 'Unknown' : serviceLabel})");
        debugLog.writeln("- Service: $sUuid ${serviceLabel.isNotEmpty ? '($serviceLabel)' : ''}");
        
        for (var c in s.characteristics) {
          String cUuid = c.uuid.toString().toUpperCase();
          print(">>>   └ 특성 확인: $cUuid");
          debugLog.writeln("  └ Char: $cUuid");
          
          // 1. 송신 특성 설정: Smartphone 서비스(FF20)의 FF31을 우선적으로 사용
          if (serviceLabel == "Smartphone" && cUuid.contains("FF31")) {
            _sendChar = c;
            print(">>> [성공] 스마트폰 송신 채널(FF20 -> FF31) 설정 완료!");
          } 
          
          // 2. 수신 특성 설정: 각 서비스의 FF30을 구독
          if (cUuid.contains("FF30")) {
            if (!_recvChars.contains(c)) {
              if (c.properties.notify || c.properties.indicate) {
                _recvChars.add(c);
                print(">>> [성공] $serviceLabel 수신 채널(FF30) 구독!");
                _subscribeToRecv(c, serviceLabel.isNotEmpty ? serviceLabel : sUuid.split('-')[0].replaceAll(RegExp(r'^0+'), ''));
              }
            }
          }
        }
      }
      
      // 하위 호환: 스마트폰 서비스(FF20)를 못 찾은 경우 전체에서 FF31 검색
      if (_sendChar == null) {
        for (var s in services) {
          for (var c in s.characteristics) {
            if (c.uuid.toString().toUpperCase().contains("FF31")) {
              _sendChar = c;
              break;
            }
          }
        }
      }
      
      _debugUUIDs = debugLog.toString();
      _clearAllFields();
      if (mounted) setState(() {});
    } catch (e) {
      print(">>> 서비스 검색 오류: $e");
    }
  }

  Future<void> _subscribeToRecv(BluetoothCharacteristic char, String label) async {
    try {
      await char.setNotifyValue(true);
      final sub = char.onValueReceived.listen((value) {
        if (mounted) {
          _addLog(value, label);
        }
      });
      _valueSubscriptions.add(sub);
    } catch (e) {
      debugPrint("${char.uuid} 구독 실패: $e");
    }
  }

  void _addLog(List<int> data, String uuid) {
    if (data.isEmpty) return;
    
    final timestamp = DateTime.now();
    final timeStr = "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}";
    final hexStr = data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ').toUpperCase();
    
    // ASCII 변환 시도 (제어문자는 . 으로 표시)
    final asciiStr = String.fromCharCodes(data.map((b) => (b >= 32 && b <= 126) ? b : 46));

    setState(() {
      _recvLogs.add({
        'time': timeStr,
        'uuid': uuid,
        'hex': hexStr,
        'ascii': asciiStr,
      });
    });

    // 자동 스크롤
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearAllFields() {
    _didCtrl.clear();
    _devIdCtrl.clear();
    _userIdCtrl.clear();
    _ssidCtrl.clear();
    _pswdCtrl.clear();
    _ipCtrl.clear();
    _portCtrl.clear();
    _testAsciiCtrl.clear();
  }

  Future<void> _disconnect() async {
    await widget.device.disconnect();
    _sendChar = null;
    _recvChars.clear();
    for (var sub in _valueSubscriptions) {
      sub.cancel();
    }
    _valueSubscriptions.clear();
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    for (var sub in _valueSubscriptions) {
      sub.cancel();
    }
    _valueSubscriptions.clear();
    _logScrollController.dispose();
    for (var fn in _focusNodes) {
      fn.dispose();
    }
    _didCtrl.dispose();
    _devIdCtrl.dispose();
    _userIdCtrl.dispose();
    _ssidCtrl.dispose();
    _pswdCtrl.dispose();
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _testAsciiCtrl.dispose();
    super.dispose();
  }

  void _focusNext() {
    if (_currentFocusIndex < _focusNodes.length - 1) {
      _currentFocusIndex++;
      FocusScope.of(context).requestFocus(_focusNodes[_currentFocusIndex]);
      setState(() {});
    }
  }

  void _focusPrev() {
    if (_currentFocusIndex > 0) {
      _currentFocusIndex--;
      FocusScope.of(context).requestFocus(_focusNodes[_currentFocusIndex]);
      setState(() {});
    }
  }

  List<int> _padRight(List<int> data, int length) {
    if (data.length >= length) return data.sublist(0, length);
    return data + List<int>.filled(length - data.length, 0x00);
  }

  List<int> _parseHex(String hex) {
    hex = hex.replaceAll(" ", "").replaceAll("0x", "");
    if (hex.length % 2 != 0) hex = "0" + hex;
    List<int> bytes = [];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.tryParse(hex.substring(i, i + 2), radix: 16) ?? 0);
    }
    return bytes;
  }

  Future<void> _sendData() async {
    if (_sendChar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('전송 가능한 특성(0xFF31)을 찾을 수 없습니다. (웹 환경의 경우 스캔 권한 문제일 수 있습니다)')));
      return;
    }

    List<int> payload = [];

    // 1. DID: 1 byte hexcode ('1' -> 0x01, '32' -> 0x32)
    if (_didCtrl.text.isNotEmpty) {
      try {
        int val = int.parse(_didCtrl.text.trim(), radix: 16);
        payload.add(val & 0xFF);
      } catch (e) {
        payload.add(0x00);
      }
    }

    // 2. 장치 ID: 10 byte hexcode
    if (_devIdCtrl.text.isNotEmpty) {
      List<int> devBytes = _parseHex(_devIdCtrl.text);
      payload.addAll(_padRight(devBytes, 10));
    }

    // 3. 유저 ID: 20 byte ASCII (null 채움)
    if (_userIdCtrl.text.isNotEmpty) {
      payload.addAll(_padRight(utf8.encode(_userIdCtrl.text), 20));
    }

    // 4. WIFI SSID: 32 byte ASCII (null 채움)
    if (_ssidCtrl.text.isNotEmpty) {
      payload.addAll(_padRight(utf8.encode(_ssidCtrl.text), 32));
    }

    // 5. WIFI PSWD: 64 byte ASCII (null 채움)
    if (_pswdCtrl.text.isNotEmpty) {
      payload.addAll(_padRight(utf8.encode(_pswdCtrl.text), 64));
    }

    // 6. SERVER_ADDR: 4 byte (IP) -> 192.168.0.32 -> 0xC0 0xA8 0x00 0x20
    if (_ipCtrl.text.isNotEmpty) {
      List<String> parts = _ipCtrl.text.trim().split('.');
      List<int> ipBytes = [];
      for (String p in parts) {
        ipBytes.add(int.tryParse(p) ?? 0);
      }
      payload.addAll(_padRight(ipBytes, 4));
    }

    // 7. SERVER_PORT: 2 byte Little Endian -> 3000 -> 0xB8 0x0B
    if (_portCtrl.text.isNotEmpty) {
      int port = int.tryParse(_portCtrl.text.trim()) ?? 0;
      payload.add(port & 0xFF);         // LSB
      payload.add((port >> 8) & 0xFF);  // MSB
    }

    if (payload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('입력된 데이터가 없습니다.')));
      return;
    }

    try {
      // allowLongWrite: MTU 제한(20바이트)을 넘어갈 경우 자동으로 나누어 전송해주는 옵션
      await _sendChar!.write(payload, allowLongWrite: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('전송 완료 (${payload.length} bytes)'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('전송 실패: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _sendTestData() async {
    print(">>> _sendTestData 함수 진입함!"); // 디버그 콘솔 확인용
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('TEST SEND 시작됨...'), duration: Duration(milliseconds: 500))
      );
    }
    
    if (_sendChar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('전송 가능한 특성을 찾을 수 없습니다.')));
      return;
    }
    if (_testAsciiCtrl.text.isEmpty) {
      return;
    }
    try {
      String text = _testAsciiCtrl.text;
      List<int> payload = utf8.encode(text);
      
      print(">>> 전송 시도할 텍스트: '$text'");
      print(">>> 바이트 변환 결과: $payload");
      
      await _sendChar!.write(payload, allowLongWrite: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('테스트 전송 완료 (${payload.length} bytes)'),
            backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('테스트 전송 실패: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.platformName.isNotEmpty
            ? widget.device.platformName
            : "Device Control"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildConnectionHeader(),
          Expanded(
            child: _isConnecting
                ? const Center(child: CircularProgressIndicator())
                : (_connectionState == BluetoothConnectionState.connected
                    ? _buildInputForm()
                    : const Center(child: Text("Pick a device to connect"))),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionHeader() {
    return Container(
      color: Colors.blue.shade50,
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                      _connectionState == BluetoothConnectionState.connected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      color: _connectionState == BluetoothConnectionState.connected
                          ? Colors.green
                          : Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    "Status: ${_connectionState.toString().split('.').last.toUpperCase()}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: _connectionState == BluetoothConnectionState.connected
                    ? _disconnect
                    : _connect,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _connectionState == BluetoothConnectionState.connected
                          ? Colors.red.shade100
                          : Colors.green.shade100,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(_connectionState == BluetoothConnectionState.connected
                    ? "Disconnect"
                    : "Connect"),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("송신(Write): ${_sendChar != null ? '준비완료(FF31)' : '찾는중...'}", 
                    style: TextStyle(fontSize: 11, color: _sendChar != null ? Colors.blue : Colors.red, fontWeight: FontWeight.bold)),
                  Text("수신(Notify): ${_recvChars.isNotEmpty ? '준비완료(${_recvChars.length}개)' : '찾는중...'}", 
                    style: TextStyle(fontSize: 11, color: _recvChars.isNotEmpty ? Colors.blue : Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _discoverSpecificServices,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text("서비스 재검색"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade100,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 이전/다음 버튼 제어부
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                onPressed: _currentFocusIndex > 0 ? _focusPrev : null,
                icon: const Icon(Icons.arrow_back),
                label: const Text("이전"),
              ),
              ElevatedButton.icon(
                onPressed: _currentFocusIndex < _focusNodes.length - 1 ? _focusNext : null,
                icon: const Icon(Icons.arrow_forward),
                label: const Text("다음"),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 입력 폼
          Expanded(
            child: ListView(
              children: [
                _buildTextField("DID (Hex 1byte, ex: 32)", _didCtrl, _didFocus),
                _buildTextField("장치 ID (Hex 10byte)", _devIdCtrl, _devIdFocus),
                _buildTextField("유저 ID (ASCII 20byte)", _userIdCtrl, _userIdFocus),
                _buildTextField("WIFI SSID (ASCII 32byte)", _ssidCtrl, _ssidFocus),
                _buildTextField("WIFI PASSWORD (ASCII 64byte)", _pswdCtrl, _pswdFocus),
                _buildTextField("SERVER ADDR (ex: 192.168.0.32)", _ipCtrl, _ipFocus),
                _buildTextField("SERVER PORT (ex: 3000)", _portCtrl, _portFocus),
                const SizedBox(height: 20),
                
                // 수신 모니터 (수신창)
                _buildReceiveMonitor(),
                
                const SizedBox(height: 20),
                // 디버깅: 발견된 모든 서비스/특성 UUID 표시
                if (_debugUUIDs.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text("발견된 서비스 목록 (디버그용):\n$_debugUUIDs", 
                      style: TextStyle(fontSize: 12, color: Colors.red.shade900)),
                  ),

                // Send 버튼 (DID 입력창에 값이 있을 때만 무조건 활성화)
                ElevatedButton(
                  onPressed: _didCtrl.text.isNotEmpty ? _sendData : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _didCtrl.text.isNotEmpty ? Colors.indigo : Colors.grey,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text("SEND",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                
                const Divider(height: 40, thickness: 2),
                const Text("디버깅용 테스트 전송 (단순 ASCII)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField("테스트 입력 (ex: Hello)", _testAsciiCtrl, _testAsciiFocus),
                    ),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: ElevatedButton(
                        onPressed: () {
                          print("!!! UI 레이어: TEST SEND 버튼 클릭 감지됨 !!!");
                          _sendTestData();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange, // 항상 주황색으로 표시
                          foregroundColor: Colors.white,
                          minimumSize: const Size(100, 58),
                        ),
                        child: const Text("TEST SEND"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiveMonitor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("수신 모니터 (Multi-UUID)",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo)),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _recvLogs.clear();
                    });
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text("Clear"),
                ),
                IconButton(
                  onPressed: _recvChars.isNotEmpty ? () async {
                    try {
                      for (var char in _recvChars) {
                        List<int> val = await char.read();
                        if (val.isNotEmpty) {
                          // 해당 특성이 속한 서비스의 라벨 찾기 (간단한 매칭 로직)
                          String label = "Unknown";
                          String uuidStr = char.serviceUuid.toString().toUpperCase();
                          if (uuidStr.contains("FF20")) label = "Smartphone";
                          else if (uuidStr.contains("FF21")) label = "Sensor";
                          else if (uuidStr.contains("FF22")) label = "Extra";
                          _addLog(val, label);
                        }
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('읽기 실패: $e')));
                    }
                  } : null,
                  icon: const Icon(Icons.refresh),
                  tooltip: "모든 특성 수동 읽기",
                ),
              ],
            ),
          ],
        ),
        Container(
          height: 250,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E), // Dark terminal color
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _recvLogs.isEmpty
              ? const Center(
                  child: Text(
                    "데이터 대기 중...",
                    style: TextStyle(color: Colors.grey, fontFamily: 'monospace'),
                  ),
                )
              : ListView.builder(
                  controller: _logScrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: _recvLogs.length,
                  itemBuilder: (context, index) {
                    final log = _recvLogs[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "[${log['time']}] ",
                                style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontFamily: 'monospace'),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  log['uuid'],
                                  style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  log['hex'],
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 75),
                            child: Text(
                              "ASCII: ${log['ascii']}",
                              style: TextStyle(color: Colors.blue.shade200, fontSize: 11, fontFamily: 'monospace'),
                            ),
                          ),
                          const Divider(color: Colors.white10, height: 8),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, FocusNode fn) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: ctrl,
        focusNode: fn,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onTap: () {
          setState(() {
            _currentFocusIndex = _focusNodes.indexOf(fn);
          });
        },
        onSubmitted: (_) {
          _focusNext();
        },
        onChanged: (text) {
          // 텍스트가 바뀔 때마다 상태를 업데이트하여 버튼 활성화 여부를 즉각 반영
          setState(() {});
        },
      ),
    );
  }
}
