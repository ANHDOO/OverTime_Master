import 'package:flutter/material.dart';
import '../models/citizen_profile.dart';
import '../services/storage_service.dart';
import '../services/citizen_lookup_service.dart';

class CitizenProfileProvider with ChangeNotifier {
  final StorageService _storageService = StorageService();
  List<CitizenProfile> _citizenProfiles = [];
  bool _isLoading = false;

  List<CitizenProfile> get citizenProfiles => _citizenProfiles;
  bool get isLoading => _isLoading;

  Future<void> fetchCitizenProfiles() async {
    _isLoading = true;
    notifyListeners();
    try {
      _citizenProfiles = await _storageService.getAllCitizenProfiles();
    } catch (e) {
      debugPrint('Error fetching citizen profiles: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    
    CitizenLookupService().preloadAll();
  }

  Future<void> addCitizenProfile(CitizenProfile profile) async {
    await _storageService.insertCitizenProfile(profile);
    await fetchCitizenProfiles();
  }

  Future<void> updateCitizenProfile(CitizenProfile profile) async {
    await _storageService.updateCitizenProfile(profile);
    await fetchCitizenProfiles();
  }

  Future<void> deleteCitizenProfile(int id) async {
    await _storageService.deleteCitizenProfile(id);
    await fetchCitizenProfiles();
  }
}
