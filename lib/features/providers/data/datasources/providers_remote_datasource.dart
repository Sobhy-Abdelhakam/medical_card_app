import 'package:flutter/foundation.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/repositories/providers_repository.dart';
import '../models/models.dart';

/// Remote data source for providers API
abstract class ProvidersRemoteDataSource {
  /// Fetches top providers from the API
  Future<List<TopProviderModel>> getTopProviders();

  /// Fetches providers with optional filtering and pagination
  Future<({List<ProviderModel> providers, PaginationModel? pagination})>
      getProviders(GetProvidersParams params);

  /// Performs free-form search across all provider fields
  Future<({List<ProviderModel> providers, PaginationModel? pagination})>
      searchProviders(SearchProvidersParams params);
}

/// Implementation of ProvidersRemoteDataSource using ApiClient
class ProvidersRemoteDataSourceImpl implements ProvidersRemoteDataSource {
  final ApiClient _apiClient;

  ProvidersRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<List<TopProviderModel>> getTopProviders() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.topProviders,
    );

    final data = response.data;
    if (data == null) {
      throw const ParseException(message: 'Empty response from server');
    }

    if (data['success'] != true) {
      throw ServerException(
        message: data['message']?.toString() ?? 'Failed to load top providers',
      );
    }

    final dataList = data['data'] as List<dynamic>?;
    if (dataList == null) {
      return [];
    }

    return dataList
        .map((item) => TopProviderModel.fromJson(
              item is Map<String, dynamic>
                  ? item
                  : Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  @override
  Future<({List<ProviderModel> providers, PaginationModel? pagination})>
      getProviders(GetProvidersParams params) async {
    final queryParams = <String, dynamic>{};

    // Add search parameters
    if (params.searchName != null && params.searchName!.isNotEmpty) {
      queryParams[ApiConstants.searchName] = params.searchName;
    }
    if (params.type != null && params.type!.isNotEmpty) {
      queryParams[ApiConstants.type] = params.type;
      // if (params.type == 'معمل تحاليل') {
      //   queryParams[ApiConstants.type] = 'معامل التحاليل';
      // } else {
      //   queryParams[ApiConstants.type] = params.type;
      // }
    }
    if (params.search != null && params.search!.isNotEmpty) {
      queryParams[ApiConstants.search] = params.search;
    }
    if (params.city != null && params.city!.isNotEmpty) {
      queryParams[ApiConstants.city] = params.city;
    }
    if (params.district != null && params.district!.isNotEmpty) {
      queryParams[ApiConstants.district] = params.district;
    }
    if (params.governorate != null && params.governorate!.isNotEmpty) {
      queryParams[ApiConstants.governorate] = params.governorate;
    }

    // Add pagination parameters
    if (params.paginate) {
      queryParams[ApiConstants.paginate] = '1';
      queryParams[ApiConstants.page] = params.page.toString();
      queryParams[ApiConstants.perPage] = params.perPage.toString();
    }

    final response = await _apiClient.get<dynamic>(
      ApiConstants.arabicProviders,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    final data = response.data;
    if (data == null) {
      throw const ParseException(message: 'Empty response from server');
    }

    // Handle different response formats
    List<dynamic> dataList;
    PaginationModel? pagination;

    if (data is Map<String, dynamic>) {
      // Paginated response with wrapper
      if (data['success'] == false) {
        throw ServerException(
          message: data['message']?.toString() ?? 'Failed to load providers',
        );
      }

      dataList = data['data'] as List<dynamic>? ?? [];

      // Parse pagination from either 'pagination' or 'meta' key
      final paginationJson = data['pagination'] as Map<String, dynamic>?;
      final metaJson = data['meta'] as Map<String, dynamic>?;

      if (paginationJson != null) {
        pagination = PaginationModel.fromJson(paginationJson);
      } else if (metaJson != null) {
        pagination = PaginationModel.fromMeta(metaJson);
      }
    } else if (data is List) {
      // Non-paginated response (plain array)
      dataList = data;
      pagination = null;
    } else {
      throw const ParseException(message: 'Unexpected response format');
    }

    // Use isolate for parsing large lists
    final providers = await compute(_parseProviders, dataList);

    return (providers: providers, pagination: pagination);
  }

  // Static function for compute
  static List<ProviderModel> _parseProviders(List<dynamic> dataList) {
    return dataList
        .map((item) => ProviderModel.fromJson(
              item is Map<String, dynamic>
                  ? item
                  : Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  @override
  Future<({List<ProviderModel> providers, PaginationModel? pagination})>
      searchProviders(SearchProvidersParams params) async {
    final queryParams = <String, dynamic>{
      ApiConstants.query: params.query,
      ApiConstants.page: params.page.toString(),
      ApiConstants.perPage: params.perPage.toString(),
    };

    if (params.type != null && params.type!.isNotEmpty) {
      queryParams[ApiConstants.type] = params.type;
    }
    if (params.city != null && params.city!.isNotEmpty) {
      queryParams[ApiConstants.city] = params.city;
    }
    if (params.district != null && params.district!.isNotEmpty) {
      queryParams[ApiConstants.district] = params.district;
    }
    if (params.governorate != null && params.governorate!.isNotEmpty) {
      queryParams[ApiConstants.governorate] = params.governorate;
    }

    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.arabicProvidersSearch,
      queryParameters: queryParams,
    );

    final data = response.data;
    if (data == null) {
      throw const ParseException(message: 'Empty response from server');
    }

    final dataList = data['data'] as List<dynamic>? ?? [];
    final metaJson = data['meta'] as Map<String, dynamic>?;

    // Use isolate for parsing search results
    final providers = await compute(_parseProviders, dataList);

    final pagination =
        metaJson != null ? PaginationModel.fromMeta(metaJson) : null;

    return (providers: providers, pagination: pagination);
  }
}
