import 'package:dio/dio.dart';
import 'package:ubci_bank/src/infra/network/base_web_api_provider.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';

abstract class ObdxApiBase extends BaseWebApiProvider {
  ObdxApiBase(this._client);

  final ObdxDioClient _client;

  Dio get dio => _client.dio;
}
