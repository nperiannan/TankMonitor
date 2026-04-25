class Schedule {
  final int i;
  final String m; // 'OH' or 'UG'
  final String t; // "HH:MM"
  final int d;    // duration minutes
  final bool on;  // currently running

  const Schedule({
    required this.i,
    required this.m,
    required this.t,
    required this.d,
    required this.on,
  });

  factory Schedule.fromJson(Map<String, dynamic> j) => Schedule(
        i: j['i'] as int,
        m: j['m'] as String,
        t: j['t'] as String,
        d: j['d'] as int,
        on: j['on'] as bool,
      );
}

class Status {
  final String ohState;
  final String ugState;
  final bool ohMotor;
  final bool ugMotor;
  final bool loraOk;
  final int wifiRssi;
  final int uptimeS;
  final String fw;
  final String time;
  final List<Schedule> schedules;
  final bool ohDispOnly;
  final bool ugDispOnly;
  final bool ugIgnore;
  final bool buzzerDelay;
  final int  lcdBlMode;   // 0=auto, 1=always_on, 2=always_off
  final String logLevel;  // 'info' | 'debug'
  final bool buzzerActive;
  final bool ohBuzzer;    // buzzer countdown running for OH motor
  final bool ugBuzzer;    // buzzer countdown running for UG motor
  final String txFw;      // transmitter firmware version

  const Status({
    required this.ohState,
    required this.ugState,
    required this.ohMotor,
    required this.ugMotor,
    required this.loraOk,
    required this.wifiRssi,
    required this.uptimeS,
    required this.fw,
    required this.time,
    required this.schedules,
    required this.ohDispOnly,
    required this.ugDispOnly,
    required this.ugIgnore,
    required this.buzzerDelay,
    required this.lcdBlMode,
    required this.logLevel,
    required this.buzzerActive,
    required this.ohBuzzer,
    required this.ugBuzzer,
    required this.txFw,
  });

  factory Status.fromJson(Map<String, dynamic> j) => Status(
        ohState:    j['oh_state']    as String? ?? '',
        ugState:    j['ug_state']    as String? ?? '',
        ohMotor:    j['oh_motor']    as bool?   ?? false,
        ugMotor:    j['ug_motor']    as bool?   ?? false,
        loraOk:     j['lora_ok']     as bool?   ?? false,
        wifiRssi:   j['wifi_rssi']   as int?    ?? 0,
        uptimeS:    j['uptime_s']    as int?    ?? 0,
        fw:         j['fw']          as String? ?? '',
        time:       j['time']        as String? ?? '',
        schedules:  (j['schedules']  as List<dynamic>? ?? [])
            .map((e) => Schedule.fromJson(e as Map<String, dynamic>))
            .toList(),
        ohDispOnly: j['oh_disp_only'] as bool? ?? false,
        ugDispOnly: j['ug_disp_only'] as bool? ?? false,
        ugIgnore:   j['ug_ignore']    as bool? ?? false,
        buzzerDelay:j['buzzer_delay'] as bool? ?? false,
        lcdBlMode:  j['lcd_bl_mode']  as int?  ?? 0,
        logLevel:   j['log_level']    as String? ?? 'info',
        buzzerActive: j['buzzer_active'] as bool? ?? false,
        ohBuzzer:   j['oh_buzzer']    as bool? ?? false,
        ugBuzzer:   j['ug_buzzer']    as bool? ?? false,
        txFw:       j['tx_fw']        as String? ?? '',
      );
}

class Device {
  final String mac;
  final String typeId;
  final String displayName;
  final String fwVersion;
  final String role;   // 'owner' | 'viewer' | '' (unclaimed, admin-visible only)
  final bool online;

  const Device({
    required this.mac,
    required this.typeId,
    required this.displayName,
    required this.fwVersion,
    required this.role,
    required this.online,
  });

  factory Device.fromJson(Map<String, dynamic> j) => Device(
        mac:         j['mac']          as String? ?? '',
        typeId:      j['type_id']      as String? ?? '',
        displayName: j['display_name'] as String? ?? '',
        fwVersion:   j['fw_version']   as String? ?? '',
        role:        j['role']         as String? ?? '',
        online:      j['online']       as bool?   ?? false,
      );
}
