/// Host Models for AllDebrid
class Host {
  final String name;
  final List<String> domains;
  final List<String> regexps;
  final bool status;

  Host({
    required this.name,
    required this.domains,
    required this.regexps,
    required this.status,
  });

  factory Host.fromJson(Map<String, dynamic> json) {
    return Host(
      name: json['name'] ?? '',
      domains: List<String>.from(json['domains'] ?? []),
      regexps: List<String>.from(json['regexps'] ?? []),
      status: json['status'] ?? false,
    );
  }
}

class HostsResponse {
  final Map<String, Host> hosts;
  final Map<String, Host> streams;

  HostsResponse({
    required this.hosts,
    required this.streams,
  });

  factory HostsResponse.fromJson(Map<String, dynamic> json) {
    final hostsMap = <String, Host>{};
    final streamsMap = <String, Host>{};

    if (json['hosts'] != null) {
      (json['hosts'] as Map<String, dynamic>).forEach((key, value) {
        hostsMap[key] = Host.fromJson(value);
      });
    }

    if (json['streams'] != null) {
      (json['streams'] as Map<String, dynamic>).forEach((key, value) {
        streamsMap[key] = Host.fromJson(value);
      });
    }

    return HostsResponse(
      hosts: hostsMap,
      streams: streamsMap,
    );
  }

  List<Host> get activeHosts => hosts.values.where((h) => h.status).toList();
  List<Host> get inactiveHosts => hosts.values.where((h) => !h.status).toList();
}
