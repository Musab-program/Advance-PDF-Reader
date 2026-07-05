// lib/modules/search/controllers/search_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf_reader/core/services/storage_service.dart';
import 'package:pdf_reader/domain/entities/library_item.dart';
import 'package:pdf_reader/modules/home/controllers/home_controller.dart';

class SearchController extends GetxController {
  final StorageService _storageService = Get.find<StorageService>();
  late final HomeController _homeController;

  final TextEditingController textController = TextEditingController();
  final RxString query = ''.obs;
  final RxString sortOrder = 'date'.obs; // 'date', 'type', 'size'
  
  // Filter variables
  final RxString selectedDateFilter = 'all'.obs;
  final RxString selectedTypeFilter = 'all'.obs;
  final RxString selectedSizeFilter = 'all'.obs;

  final RxList<LibraryItem> results = <LibraryItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    _homeController = Get.find<HomeController>();
    
    _filterAndSort();

    textController.addListener(() {
      query.value = textController.text;
    });

    debounce(query, (_) => _filterAndSort(), time: const Duration(milliseconds: 250));
    ever(sortOrder, (_) => _filterAndSort());
    ever(selectedDateFilter, (_) => _filterAndSort());
    ever(selectedTypeFilter, (_) => _filterAndSort());
    ever(selectedSizeFilter, (_) => _filterAndSort());
  }

  @override
  void onClose() {
    textController.dispose();
    super.onClose();
  }

  void setSortOrder(String order) {
    sortOrder.value = order;
  }

  void setDateFilter(String filter) {
    selectedDateFilter.value = filter;
  }

  void setTypeFilter(String filter) {
    selectedTypeFilter.value = filter;
  }

  void setSizeFilter(String filter) {
    selectedSizeFilter.value = filter;
  }

  void _filterAndSort() {
    final rawFiles = _homeController.deviceFiles;
    final recycledPaths = _storageService.getRecycledItems().map((e) => e.path).toSet();

    // 1. Filter out recycled files
    Iterable<LibraryItem> filtered = rawFiles.where((item) => !recycledPaths.contains(item.path));

    // 2. Filter by search query
    final searchStr = query.value.trim().toLowerCase();
    if (searchStr.isNotEmpty) {
      filtered = filtered.where((item) => item.name.toLowerCase().contains(searchStr));
    }

    // 3. Filter by Date
    if (selectedDateFilter.value != 'all') {
      final now = DateTime.now();
      Duration limit;
      if (selectedDateFilter.value == '1_day') {
        limit = const Duration(days: 1);
      } else if (selectedDateFilter.value == '2_days') {
        limit = const Duration(days: 2);
      } else if (selectedDateFilter.value == '1_week') {
        limit = const Duration(days: 7);
      } else {
        limit = const Duration(days: 14);
      }
      final threshold = now.subtract(limit);
      filtered = filtered.where((item) => item.dateModified.isAfter(threshold));
    }

    // 4. Filter by Type
    if (selectedTypeFilter.value != 'all') {
      filtered = filtered.where((item) {
        final ext = item.extension.toLowerCase();
        switch (selectedTypeFilter.value) {
          case 'pdf':
            return ext == 'pdf';
          case 'word':
            return ext == 'doc' || ext == 'docx';
          case 'excel':
            return ext == 'xls' || ext == 'xlsx';
          case 'ppt':
            return ext == 'ppt' || ext == 'pptx';
          case 'txt':
            return ext == 'txt';
          case 'html':
            return ext == 'html';
          default:
            return true;
        }
      });
    }

    // 5. Filter by Size
    if (selectedSizeFilter.value != 'all') {
      filtered = filtered.where((item) {
        final size = item.size;
        switch (selectedSizeFilter.value) {
          case 'under_1mb':
            return size < 1 * 1024 * 1024;
          case '1to10mb':
            return size >= 1 * 1024 * 1024 && size <= 10 * 1024 * 1024;
          case '10to50mb':
            return size >= 10 * 1024 * 1024 && size <= 50 * 1024 * 1024;
          case 'over_50mb':
            return size > 50 * 1024 * 1024;
          default:
            return true;
        }
      });
    }

    // 6. Sort
    final list = filtered.toList();
    if (sortOrder.value == 'date') {
      list.sort((a, b) => b.dateModified.compareTo(a.dateModified));
    } else if (sortOrder.value == 'type') {
      list.sort((a, b) => a.extension.toLowerCase().compareTo(b.extension.toLowerCase()));
    } else if (sortOrder.value == 'size') {
      list.sort((a, b) => b.size.compareTo(a.size));
    }

    results.assignAll(list);
  }
}
