import 'package:google_maps_flutter/google_maps_flutter.dart';

class Business {
  final String businessId;
  final String businessName;
  final String? district;
  final String? neighborhood;
  final Location? location;
  final List<String> complaintIds;
  final int pendingComplaints;
  final int inReviewComplaints;
  final int positiveComplaints;
  final int negativeComplaints;
  final double score;
  final bool isReadyForInspection;
  final DateTime lastUpdated;
  final List<String>? merged;
  final int? mergedCount;
  final String? originalName;

  Business({
    required this.businessId,
    required this.businessName,
    this.district,
    this.neighborhood,
    this.location,
    required this.complaintIds,
    required this.pendingComplaints,
    required this.inReviewComplaints,
    required this.positiveComplaints,
    required this.negativeComplaints,
    this.score = 0.0,
    required this.isReadyForInspection,
    required this.lastUpdated,
    this.merged,
    this.mergedCount,
    this.originalName,
  });

  factory Business.fromJson(Map<String, dynamic> json) {
    return Business(
      businessId: json['businessId'] ?? '',
      businessName: json['businessName'] ?? '',
      district: json['district'],
      neighborhood: json['neighborhood'],
      location: json['location'] != null ? Location.fromJson(json['location']) : null,
      complaintIds: json['complaintIds'] != null ? List<String>.from(json['complaintIds']) : [],
      pendingComplaints: json['pendingComplaints'] ?? 0,
      inReviewComplaints: json['inReviewComplaints'] ?? 0,
      positiveComplaints: json['positiveComplaints'] ?? 0,
      negativeComplaints: json['negativeComplaints'] ?? 0,
      score: (json['score'] ?? 0).toDouble(),
      isReadyForInspection: json['isReadyForInspection'] ?? false,
      lastUpdated: json['lastUpdated'] != null 
          ? DateTime.parse(json['lastUpdated']) 
          : DateTime.now(),
      merged: json['merged'] != null ? List<String>.from(json['merged']) : null,
      mergedCount: json['mergedCount'],
      originalName: json['originalName'],
    );
  }
}

class Location {
  final double latitude;
  final double longitude;

  Location({
    required this.latitude,
    required this.longitude,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      latitude: json['lat'].toDouble(),
      longitude: json['lng'].toDouble(),
    );
  }
} 