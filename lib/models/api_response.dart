/// AllDebrid API Response Models
library;

class BaseResponse<T> {
  final String status;
  final T? data;
  final ApiError? error;

  BaseResponse({
    required this.status,
    this.data,
    this.error,
  });

  bool get isSuccess => status == 'success';
  bool get isError => status == 'error';

  factory BaseResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return BaseResponse(
      status: json['status'] ?? 'error',
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : null,
      error: json['error'] != null ? ApiError.fromJson(json['error']) : null,
    );
  }
}

class ApiError {
  final String code;
  final String message;

  ApiError({
    required this.code,
    required this.message,
  });

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      code: json['code'] ?? 'UNKNOWN',
      message: json['message'] ?? 'Unknown error occurred',
    );
  }

  @override
  String toString() => '[$code] $message';
}
